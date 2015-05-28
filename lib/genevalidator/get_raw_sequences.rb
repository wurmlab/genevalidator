require 'genevalidator/sequences'
require 'genevalidator/exceptions'
require 'bio-blastxmlparser'
require 'net/http'
require 'open-uri'
require 'uri'
require 'io/console'
require 'yaml'
module GeneValidator
  # Gets the raw sequences for each hit in a BLAST output file
  class GetRawSequences
    class <<self
      extend Forwardable
      def_delegators GeneValidator, :opt, :config

      ##
      # Obtains raw_sequences from BLAST output file...
      def run
        @opt = opt
        @config = config
        
        puts 'Extracting sequences within the BLAST output file from the' \
             ' BLAST database'

        if @opt[:blast_xml_file]
          @blast_file  = @opt[:blast_xml_file]
        else
          @blast_file = @opt[:blast_tabular_file]
        end

        @opt[:raw_sequences] = @blast_file + '.raw_seq'
        index_file   = @blast_file + '.index'

        if opt[:db] =~ /remote/
          write_a_raw_seq_file(@opt[:raw_sequences], 'remote')
        else
          write_an_index_file(index_file, 'local')
          obtain_raw_seqs_from_local_db(index_file, @opt[:raw_sequences])
        end
        index_raw_seq_file
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
            if db_type == 'remote'
              file.puts obtain_raw_seqs_from_remote_db(hit.accession)
            else
              file.puts hit.hit_id
            end
          end
        end
      rescue
        puts '*** Error: There was an error in analysing the BLAST XML file.'
        puts '    Please ensure that BLAST XML file is in the correct format'
        puts '    and then try again. If you are using a remote database,'
        puts '    please ensure that you have internet access.'
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
          if db_type == 'remote'
            file.puts obtain_raw_seqs_from_remote_db(row['sacc'])
          else
            file.puts row['sseqid']
          end
        end
      rescue
        puts '*** Error: There was an error in analysing the BLAST tabular'
        puts '    file. Please ensure that BLAST tabular file is in the correct'
        puts '    format and then try again. If you are using a remote'
        puts '    database, please ensure that you have internet access.'
        exit 1
      end

      def obtain_raw_seqs_from_local_db(index_file, raw_seq_file)
        cmd = "blastdbcmd -entry_batch #{index_file} -db #{@opt[:db]} -outfmt" \
              " '%f' -out #{raw_seq_file}"
        `#{cmd}`
      end

      def obtain_raw_seqs_from_remote_db(accession)
        uri      = 'http://www.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?' \
                   "db=protein&retmax=1&usehistory=y&term=#{accession}/"
        result   = Net::HTTP.get(URI.parse(uri))
        query    = result.scan(%r{<\bQueryKey\b>([\w\W\d]+)</\bQueryKey\b>})[0][0]
        web_env  = result.scan(%r{<\bWebEnv\b>([\w\W\d]+)</\bWebEnv\b>})[0][0]

        uri      = 'http://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?' \
                   'rettype=fasta&retmode=text&retstart=0&retmax=1&' \
                   "db=protein&query_key=#{query}&WebEnv=#{web_env}"
        result   = Net::HTTP.get(URI.parse(uri))
        raw_seqs = result[0..result.length - 2]
        unless raw_seqs.downcase.index(/error/).nil?
          puts '*** Error: There was an error in obtaining the raw sequence' \
               ' of a BLAST hit. Please ensure that you have internet access.'
          exit 1
        end
        raw_seqs
      end

      def assert_table_has_correct_no_of_collumns(rows, table_headers)
        rows.each do |row|
          unless row.length == table_headers.length
            puts '*** Error: The BLAST tabular file cannot be parsed. This is' \
                 ' could possibly be due to an incorrect BLAST tabular' \
                 ' options ("-o", "--blast_tabular_options") being supplied.' \
                 ' Please correct this and try again.'
            exit 1
          end
          break # break after checking the first column
        end
      end

      ##
      # Index the raw sequences file...
      def index_raw_seq_file(raw_seq_file = @opt[:raw_sequences])
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
        @config[:raw_seq_file_index] = "#{raw_seq_file}.idx"
        @config[:raw_seq_file_load]  = index_hash

        File.open(@config[:raw_seq_file_index], 'w') do |f|
          YAML.dump(index_hash, f)
        end
        content = nil
      end

    end
  end
end
