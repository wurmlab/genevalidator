require 'net/http'
require 'tempfile'
require 'uri'
require 'yaml'

module GeneValidator
  # This is a class for the storing data on each sequence
  class Sequence
    attr_accessor :type # protein | mRNA
    attr_accessor :definition
    attr_accessor :identifier
    attr_accessor :species
    attr_accessor :accession_no
    attr_accessor :length_protein
    attr_accessor :reading_frame
    attr_accessor :hsp_list # array of Hsp objects

    attr_accessor :raw_sequence
    attr_accessor :protein_translation # used only for nucleotides
    attr_accessor :nucleotide_rf # used only for nucleotides

    def initialize
      @hsp_list            = []
      @raw_sequence        = nil
      @protein_translation = nil
      @nucleotide_rf       = nil
    end

    def protein_translation
      (@type == :protein) ? raw_sequence : @protein_translation
    end

    ##
    # Gets raw sequence by fasta identifier from a fasta index file
    # Params:
    # +raw_seq_file+: name of the fasta file with raw sequences
    # +index_file_name+: name of the fasta index file
    # +identifier+: String
    # +hash+: String - loaded content of the index file
    # Output:
    # String with the nucleotide sequence corresponding to the identifier
    def get_sequence_from_index_file(raw_seq_file, index_file_name, identifier,
                                     hash = nil)
      hash = YAML.load_file(index_file_name) if hash.nil?
      idx           = hash[identifier]
      query         = IO.binread(raw_seq_file, idx[1] - idx[0], idx[0])
      parse_query   = query.scan(/>([^\n]*)\n([A-Za-z\n]*)/)[0]
      @raw_sequence = parse_query[1].gsub("\n", '')
      @raw_sequence = '' if @raw_sequence =~ /Error/ || @raw_sequence.nil?
    end

    ##
    # Gets raw sequence by accession number from a givem database
    # Params:
    # +accno+: accession number as String
    # +db+: database as String
    # Output:
    # String with the nucleotide sequence corresponding to the accno
    def get_sequence_by_accession_no(accno, dbtype, db)
      if db !~ /remote/
        @raw_sequence = raw_seq_from_local_db(accno, dbtype, db)
      else
        @raw_sequence = raw_seq_from_remote_db(accno, dbtype)
      end
      @raw_sequence = '' if @raw_sequence =~ /Error/
      @raw_sequence
    end

    def raw_seq_from_local_db(accno, dbtype, db)
      blast_cmd = "blastdbcmd -entry '#{accno}' -db '#{db}' -outfmt '%s'"
      efile = Tempfile.new('blast_out')
      `#{blast_cmd} &>#{efile.path}`
      seq = efile.read
      (seq !~ /Error/) ? seq : raw_seq_from_remote_db(accno, dbtype)
    ensure
       efile.close
       efile.unlink
    end

    def raw_seq_from_remote_db(accno, dbtype)
      $stderr.puts "Getting sequence for '#{accno}' from NCBI."
      uri     = 'http://www.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?'\
                "db=#{dbtype}&retmax=1&usehistory=y&term=#{accno}/"
      result  = Net::HTTP.get(URI.parse(uri))

      query   = result.match(%r{<\bQueryKey\b>([\w\W\d]+)</\bQueryKey\b>})[1]
      web_env = result.match(%r{<\bWebEnv\b>([\w\W\d]+)</\bWebEnv\b>})[1]

      uri     = 'http://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?'\
                "rettype=fasta&retmode=text&retstart=0&retmax=1&db=#{dbtype}" \
                "&query_key=#{query}&WebEnv=#{web_env}"
      fasta  = Net::HTTP.get(URI.parse(uri))

      # parse FASTA output
      idx = fasta.index("\n")
      seq = fasta[idx + 1..-1]
      seq.gsub!(/\n/, '')
    end

    ##
    # Initializes the corresponding attribute of the sequence
    # with respect to the column name of the tabular blast output
    def init_tabular_attribute(hash)
      @identifier     = hash['sseqid'] if hash['sseqid']
      @accession_no   = hash['sacc'] if hash['sacc']
      @length_protein = hash['slen'].to_i if hash['slen']
    end
  end
end
