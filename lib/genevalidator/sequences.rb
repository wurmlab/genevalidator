require 'net/http'
require 'io/console'
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
    rescue Exception
      #   $stderr.print "Unable to retrieve raw sequence for the following" \
      #                 "id: #{identifier}\n"
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
        blast_cmd     = "blastdbcmd -entry '#{accno}' -db '#{db}' -outfmt '%s'"
        seq           = `#{blast_cmd}  2>&1`
        if /Error/ =~ seq
          fail IOError, 'GeneValidator was unable to obtain the raw sequences' \
                        ' for the BLAST hits.'
        end
        @raw_sequence = seq
      else
        #puts "Getting sequence for '#{accno}' from NCBI - avoid this by
        #puts "running GeneValidator  with '-r' argument."
        uri = 'http://www.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?'\
              "db=#{dbtype}&retmax=1&usehistory=y&term=#{accno}/"
        result = Net::HTTP.get(URI.parse(uri))
 
        query   = result.scan(%r{<\bQueryKey\b>([\w\W\d]+)</\bQueryKey\b>})[0][0]
        web_env = result.scan(%r{<\bWebEnv\b>([\w\W\d]+)</\bWebEnv\b>})[0][0]
        
        uri = 'http://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?'\
              "rettype=fasta&retmode=text&retstart=0&retmax=1&db=#{dbtype}" \
              "&query_key=#{query}&WebEnv=#{web_env}"
        
        result = Net::HTTP.get(URI.parse(uri))
        
        # parse FASTA output
        nl            = result.index("\n")
        seq           = result[nl + 1..-1]
        @raw_sequence = seq.gsub!(/\n/, '')
        @raw_sequence = '' unless @raw_sequence.index(/ERROR/).nil?
      end
      @raw_sequence
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
