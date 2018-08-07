module GeneValidator
  # This is a class for the storing data on each sequence
  class Query
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
      @type == :protein ? raw_sequence : @protein_translation
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
