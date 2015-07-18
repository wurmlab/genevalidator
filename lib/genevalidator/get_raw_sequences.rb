require 'bio-blastxmlparser'
require 'forwardable'
require 'net/http'
require 'uri'
require 'yaml'

require 'genevalidator/exceptions'
require 'genevalidator/sequences'

module GeneValidator
  # Gets the raw sequences for each hit in a BLAST output file
  class RawSequences
    class <<self
      extend Forwardable
      def_delegators GeneValidator, :opt, :config

      def init
        @opt    = opt
        @config = config

        $stderr.puts 'Extracting sequences within the BLAST output file from' \
                     ' the BLAST database'

        @blast_file = @opt[:blast_xml_file] if @opt[:blast_xml_file]
        @blast_file = @opt[:blast_tabular_file] if @opt[:blast_tabular_file]

        @opt[:raw_sequences] = @blast_file + '.raw_seq'
        @index_file          = @blast_file + '.index'
      end

      ##
      # Obtains raw_sequences from BLAST output file...
      def run
        init
        if opt[:db] =~ /remote/
          write_a_raw_seq_file(@opt[:raw_sequences], 'remote')
        else
          write_an_index_file(@index_file, 'local')
          obtain_raw_seqs_from_local_db(@index_file, @opt[:raw_sequences])
        end
        index_raw_seq_file(@opt[:raw_sequences])
      end

      ##
      # Index the raw sequences file...
      def index_raw_seq_file(raw_seq_file = opt[:raw_sequences])
        # leave only the identifiers in the fasta description
        content = File.open(raw_seq_file, 'rb').read.gsub(/ .*/, '')
        File.open(raw_seq_file, 'w+') { |f| f.write(content) }

        # index the fasta file
        keys   = content.scan(/>(.*)\n/).flatten
        values = content.enum_for(:scan, /(>[^>]+)/).map { Regexp.last_match.begin(0) }

        # make an index hash
        index_hash = {}
        keys.each_with_index do |k, i|
          start = values[i]
          endf  = (i == values.length - 1) ? content.length - 1 : values[i + 1]
          index_hash[k] = [start, endf]
        end

        # create FASTA index
        config[:raw_seq_file_index] = "#{raw_seq_file}.idx"
        config[:raw_seq_file_load]  = index_hash

        File.open(config[:raw_seq_file_index], 'w') do |f|
          YAML.dump(index_hash, f)
        end
        content = nil
      end

      private

      def write_an_index_file(output_file, db_type)
        file = File.open(output_file, 'w+')
        iterate_xml(file, db_type) if @opt[:blast_xml_file]
        iterate_tabular(file, db_type) if @opt[:blast_tabular_file]
      ensure
        file.close unless file.nil?
      end

      alias_method :write_a_raw_seq_file, :write_an_index_file

      def iterate_xml(file, db_type)
        n = Bio::BlastXMLParser::XmlIterator.new(@opt[:blast_xml_file]).to_enum
        n.each do |iter|
          iter.each do |hit|
            if db_type == 'remote' || hit.hit_id.nil?
              file.puts obtain_raw_seqs_from_remote_db(hit.accession)
            else
              file.puts hit.accession
            end
          end
        end
      rescue
        $stderr.puts '*** Error: There was an error in analysing the BLAST XML'
        $stderr.puts '    file. Please ensure that BLAST XML file is in the'
        $stderr.puts '    correct format and then try again. If you are using'
        $stderr.puts '    a remote database, please ensure that you have'
        $stderr.puts '    internet access.'
        exit 1
      end

      def iterate_tabular(file, db_type)
        table_headers = @opt[:blast_tabular_options].split(/[ ,]/)
        tab_file      = File.read(@opt[:blast_tabular_file])
        rows = CSV.parse(tab_file, col_sep: "\t",
                                   skip_lines: /^#/,
                                   headers: table_headers)
        assert_table_has_correct_no_of_collumns(rows, table_headers)

        rows.each do |row|
          if db_type == 'remote' || row['sseqid'].nil?
            file.puts obtain_raw_seqs_from_remote_db(row['sacc'])
          else
            file.puts row['sseqid']
          end
        end
      rescue
        $stderr.puts '*** Error: There was an error in analysing the BLAST'
        $stderr.puts '    tabular file. Please ensure that BLAST tabular file'
        $stderr.puts '    is in the correct format and then try again. If you'
        $stderr.puts '    are using a remote database, please ensure that you'
        $stderr.puts '    have internet access.'
        exit 1
      end

      def obtain_raw_seqs_from_local_db(index_file, raw_seq_file)
        cmd = "blastdbcmd -entry_batch '#{index_file}' -db '#{@opt[:db]}'" \
              " -outfmt '%f' -out '#{raw_seq_file}'"
        output = `#{cmd} &>/dev/null`
        failed_raw_sequences(output, raw_seq_file) if output =~ /Error/
      end

      def failed_raw_sequences(output, raw_seq_file)
        output.each_line do |line|
          acc = line.match(/Error: (\w+): OID not found/)[1]
          $stderr.puts "\nCould not find sequence '#{acc.chomp}' within the" \
                       ' BLAST database.'
          $stderr.puts "Attempting to obtain sequence '#{acc.chomp}' from" \
                       ' remote BLAST databases.'
          File.open(raw_seq_file, 'a+') do |f|
            f.puts obtain_raw_seqs_from_remote_db(acc)
          end
        end
      end

      def obtain_raw_seqs_from_remote_db(accession)
        uri      = 'http://www.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?' \
                   "db=protein&retmax=1&usehistory=y&term=#{accession}/"
        result   = Net::HTTP.get(URI.parse(uri))
        query    = result.match(%r{<\bQueryKey\b>([\w\W\d]+)</\bQueryKey\b>})[1]
        web_env  = result.match(%r{<\bWebEnv\b>([\w\W\d]+)</\bWebEnv\b>})[1]

        uri      = 'http://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?' \
                   'rettype=fasta&retmode=text&retstart=0&retmax=1&' \
                   "db=protein&query_key=#{query}&WebEnv=#{web_env}"
        result   = Net::HTTP.get(URI.parse(uri))
        raw_seqs = result[0..result.length - 2]
        unless raw_seqs.downcase.index(/error/).nil?
          $stderr.puts '*** Error: There was an error in obtaining the raw' \
                       ' sequence of a BLAST hit. Please ensure that you have' \
                       ' internet access.'
          exit 1
        end
        raw_seqs
      end

      def assert_table_has_correct_no_of_collumns(rows, table_headers)
        rows.each do |row|
          unless row.length == table_headers.length
            $stderr.puts '*** Error: The BLAST tabular file cannot be parsed.'\
                         ' This is could possibly be due to an incorrect' \
                         ' BLAST tabular options ("-o",' \
                         ' "--blast_tabular_options") being supplied.' \
                         ' Please correct this and try again.'
            exit 1
          end
          break # break after checking the first column
        end
      end
    end
  end
end
