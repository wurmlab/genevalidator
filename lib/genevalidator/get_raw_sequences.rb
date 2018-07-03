require 'bio-blastxmlparser'
require 'forwardable'
require 'net/http'
require 'tempfile'
require 'uri'
require 'yaml'

require 'genevalidator/exceptions'
require 'genevalidator/query'

module GeneValidator
  # Gets the raw sequences for each hit in a BLAST output file
  class RawSequences
    class <<self
      extend Forwardable
      def_delegators GeneValidator, :opt, :config, :dirs

      def init
        warn 'Extracting sequences within the BLAST output file from' \
             ' the BLAST database'

        @blast_file = opt[:blast_xml_file] if opt[:blast_xml_file]
        @blast_file = opt[:blast_tabular_file] if opt[:blast_tabular_file]

        fname = File.basename(@blast_file)
        opt[:raw_sequences] = File.join(dirs[:tmp_dir], "#{fname}.raw_seq")
        @index_file         = File.join(dirs[:tmp_dir], "#{fname}.index")
      end

      ##
      # Obtains raw_sequences from BLAST output file...
      def run
        init
        if opt[:db].match?(/remote/)
          write_a_raw_seq_file(opt[:raw_sequences], 'remote')
        else
          write_an_index_file(@index_file, 'local')
          FetchRawSequences.extract_from_local_db(true, nil, @index_file)
        end
        index_raw_seq_file(opt[:raw_sequences])
      end

      ##
      #
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
          endf  = i == values.length - 1 ? content.length - 1 : values[i + 1]
          index_hash[k] = [start, endf]
        end

        # create FASTA index
        fname = File.basename(raw_seq_file)
        config[:raw_seq_file_index] = File.join(dirs[:tmp_dir], "#{fname}.idx")
        config[:raw_seq_file_load]  = index_hash

        File.open(config[:raw_seq_file_index], 'w') do |f|
          YAML.dump(index_hash, f)
        end
        content = nil
      end

      private

      def write_an_index_file(output_file, db_type)
        file = File.open(output_file, 'w+')
        iterate_xml(file, db_type) if opt[:blast_xml_file]
        iterate_tabular(file, db_type) if opt[:blast_tabular_file]
      rescue BLASTDBError
        warn "*** BLAST Database Error: Genevalidator requires BLAST" \
        " databases to be created with the '-parse_seqids argument."
        warn "    See https://github.com/wurmlab/genevalidator" \
        "#setting-up-a-blast-database for more information"
        exit 1
      rescue
        warn '*** Error: There was an error in analysing the BLAST'
        warn '    output file. Please ensure that BLAST output file'
        warn '    is in the correct format and then try again. If you'
        warn '    are using a remote database, please ensure that you'
        warn '    have internet access.'
        exit 1
      ensure
        file.close unless file.nil?
      end

      alias_method :write_a_raw_seq_file, :write_an_index_file

      def iterate_xml(file, db_type)
        n = Bio::BlastXMLParser::XmlIterator.new(opt[:blast_xml_file]).to_enum
        n.each do |iter|
          iter.each do |hit|
            fail BLASTDBError if hit.hit_id =~ /\|BL_ORD_ID\|/
            if db_type == 'remote' || hit.hit_id.nil?
              file.puts FetchRawSequences.extract_from_remote_db(hit.accession)
            else
              file.puts hit.accession
            end
          end
        end
      end

      def iterate_tabular(file, db_type)
        table_headers = opt[:blast_tabular_options].split(/[ ,]/)
        tab_file      = File.read(opt[:blast_tabular_file])
        rows = CSV.parse(tab_file, col_sep: "\t",
                                   skip_lines: /^#/,
                                   headers: table_headers)

        rows.each do |row|
          fail BLASTDBError if row['sseqid'] =~ /\|BL_ORD_ID\|/
          if db_type == 'remote' || row['sseqid'].nil?
            file.puts FetchRawSequences.extract_from_remote_db(row['sacc'])
          else
            file.puts row['sseqid']
          end
        end
      end
    end
  end

  class FetchRawSequences
    class << self
      extend Forwardable
      def_delegators GeneValidator, :opt, :config

      def run(identifier, accession)
        # first try to extract from previously created raw_sequences HASH
        raw_seq = extract_from_index(identifier) if opt[:raw_sequences]
        # then try to just extract that sequence based on accession.
        if opt[:db] !~ /remote/ && (raw_seq.nil? || raw_seq =~ /Error/)
          raw_seq = extract_from_local_db(false, accession)
        end
        # then try to extract from remote database
        if opt[:db] =~ /remote/ && (raw_seq.nil? || raw_seq =~ /Error/)
          raw_seq = extract_from_remote_db(accession)
        end
        # return nil if the raw_sequence still produces an error.
        (raw_seq =~ /Error/) ? nil : raw_seq
      end

      ##
      # Gets raw sequence by fasta identifier from a fasta index file
      # Params:
      # +identifier+: String
      # Output:
      # String with the nucleotide sequence corresponding to the identifier
      def extract_from_index(identifier)
        idx         = config[:raw_seq_file_load][identifier]
        query       = IO.binread(opt[:raw_sequences], idx[1] - idx[0], idx[0])
        parse_query = query.scan(/>([^\n]*)\n([A-Za-z\n]*)/)[0]
        parse_query[1].gsub("\n", '')
      rescue
        'Error' # return error so it can then try alternative fetching method.
      end

      ##
      # Gets raw sequence by accession number from a givem database
      # Params:
      # +accno+: accession number as String
      # +db+: database as String
      # Output:
      # String with the nucleotide sequence corresponding to the accession
      def extract_from_local_db(batch, accno = nil, idx_file = nil)
        cmd = (batch) ? batch_raw_seq_cmd(idx_file) : single_raw_seq_cmd(accno)
        efile = Tempfile.new('blast_out')
        `#{cmd} &>#{efile.path}`
        raw_seqs = efile.read
        failed_raw_sequences(raw_seqs) if batch && raw_seqs =~ /Error/
        raw_seqs # when obtaining a single raw_seq, this contains the sequence
      ensure
        efile.close
        efile.unlink
      end

      def batch_raw_seq_cmd(index_file)
        "blastdbcmd -entry_batch '#{index_file}' -db '#{opt[:db]}'" \
        " -outfmt '%f' -out '#{opt[:raw_sequences]}'"
      end

      def single_raw_seq_cmd(accession)
        "blastdbcmd -entry '#{accession}' -db '#{opt[:db]}' -outfmt '%s'"
      end

      def failed_raw_sequences(blast_output)
        blast_output.each_line do |line|
          acc = line.match(/Error: (\w+): OID not found/)[1]
          warn "\nCould not find sequence '#{acc.chomp}' within the" \
                       ' BLAST database.'
          warn "Attempting to obtain sequence '#{acc.chomp}' from" \
                       ' remote BLAST databases.'
          File.open(opt[:raw_sequences], 'a+') do |f|
            f.puts extract_from_remote_db(acc)
          end
        end
      end

      def extract_from_remote_db(accession, db_seq_type = 'protein')
        uri     = 'https://www.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?' \
                  "db=#{db_seq_type}&retmax=1&usehistory=y&term=#{accession}/"
        result  = Net::HTTP.get(URI.parse(uri))
        query   = result.match(%r{<\bQueryKey\b>([\w\W\d]+)</\bQueryKey\b>})[1]
        web_env = result.match(%r{<\bWebEnv\b>([\w\W\d]+)</\bWebEnv\b>})[1]
        uri     = 'https://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?' \
                  'rettype=fasta&retmode=text&retstart=0&retmax=1&' \
                  "db=#{db_seq_type}&query_key=#{query}&WebEnv=#{web_env}"
        result  = Net::HTTP.get(URI.parse(uri))
        result[0..result.length - 2]
      end
    end
  end
end
