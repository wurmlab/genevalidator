require 'net/http'
require 'io/console'

class Sequence

  attr_accessor :type #protein | mRNA
  attr_accessor :definition
  attr_accessor :identifier
  attr_accessor :species
  attr_accessor :accession_no
  attr_accessor :length_protein
  attr_accessor :reading_frame
  attr_accessor :hsp_list # array of Hsp objects

  attr_accessor :raw_sequence
  attr_accessor :protein_translation # used only for nucleotides
  attr_accessor :nucleotide_rf #used only for nucleotides

  def initialize
    @hsp_list = []
    @raw_sequence = nil
    @protein_translation = nil
    @nucleotide_rf = nil
  end

  def protein_translation
    if @type == :protein
      return raw_sequence
    else
      return @protein_translation
    end
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
  def get_sequence_from_index_file(raw_seq_file, index_file_name, identifier, hash = nil)
    begin

      if hash == nil
        hash = YAML.load_file(index_file_name)
      end

      idx = hash[identifier]

      query         = IO.binread(raw_seq_file, idx[1] - idx[0], idx[0])
      parse_query   = query.scan(/>([^\n]*)\n([A-Za-z\n]*)/)[0]
      @raw_sequence = parse_query[1].gsub("\n","")

    rescue Exception => error
#      $stderr.print "Unable to retrieve raw sequence for the following id: #{identifier}\n"
    end
  end

  ##
  # Gets raw sequence by accession number from a givem database
  # Params:
  # +accno+: accession number as String
  # +db+: database as String
  # Output:
  # String with the nucleotide sequence corresponding to the accno
  def get_sequence_by_accession_no(accno, dbtype, db)
    begin
      if (db !~ /remote/)
        blast_cmd     = "blastdbcmd -target_only -entry '#{accno}' -db '#{db}' -outfmt '%s'"
        seq           = %x[#{blast_cmd}  2>&1]
        if /Error/ =~ seq 
          raise IOError, 'GeneValidator was unable to obtain the raw sequences for the BLAST hits.'
        end
        @raw_sequence = seq
      else
        #puts "Tries to connect to the internet for #{accno}"
        uri = "http://www.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=#{dbtype}"<<
           "&retmax=1&usehistory=y&term=#{accno}/"
        result = Net::HTTP.get(URI.parse(uri))

        result2  = result
        queryKey = result2.scan(/<\bQueryKey\b>([\w\W\d]+)<\/\bQueryKey\b>/)[0][0]
        webEnv   = result.scan(/<\bWebEnv\b>([\w\W\d]+)<\/\bWebEnv\b>/)[0][0]

        uri = "http://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?rettype=fasta&"<<
           "retmode=text&retstart=0&retmax=1&db=#{dbtype}&query_key=#{queryKey}&WebEnv=#{webEnv}"
        result = Net::HTTP.get(URI.parse(uri))

        #parse FASTA output
        rec           = result
        nl            = rec.index("\n")
        header        = rec[0..nl-1]
        seq           = rec[nl+1..-1]
        @raw_sequence = seq.gsub!(/\n/,'')
        unless @raw_sequence.index(/ERROR/) == nil
          @raw_sequence = ""
        end
      end
      @raw_sequence
    rescue Exception => error
#      @raw_sequence = ""
    end
  end


  ##
  # Initializes the corresponding attribute of the sequence
  # with respect to the column name of the tabular blast output
  def init_tabular_attribute(column, value)
    case column
      when "sseqid"
        #@definition = value
        @identifier = value
      when "qseqid"
        #@definition = value
        @identifier = value
      when "sacc"
        @accession_no = value
      when "slen"
        @length_protein = value.to_i
    end
  end

end
