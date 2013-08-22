class Sequence

  attr_accessor :seq_type #protein | mRNA
  attr_accessor :database
  attr_accessor :id
  attr_accessor :definition
  attr_accessor :species
  attr_accessor :accession_no
  attr_accessor :xml_length
  attr_accessor :raw_sequence
  attr_accessor :aligned_sequence
  attr_accessor :hsp_list # array of Hsp objects 

  def print
    puts "#{@object_type} sequence: #{@definition} "
    puts "Lengths xml #{@xml_length} fasta #{@fasta_length} hit #{@alignment.hit_seq.length}"
    puts "Accession = #{@accession_no}"
    puts "Species = #{@species}"
    puts "Raw_sequence = #{@raw_sequence.insert(@hit_from-1,'#').insert(@hit_to+1,'#')}"
    puts "Hit seq =      #{alignment.hit_seq}"
    puts "Query seq =    #{alignment.query_seq}"
    puts "----------------------"
  end

  ##
  # Gets gene by accession number from a givem database
  # Params:
  # +accno+: accession number as String
  # +db+: database as String
  # Output:
  # String with the nucleotide sequence corresponding to the accno
  def get_sequence_by_accession_no(accno,db)

    uri = "http://www.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=#{db}&retmax=1&usehistory=y&term=#{accno}/"
    #puts uri
    result = Net::HTTP.get(URI.parse(uri))

    result2 = result
    queryKey = result2.scan(/<\bQueryKey\b>([\w\W\d]+)<\/\bQueryKey\b>/)[0][0]
    webEnv = result.scan(/<\bWebEnv\b>([\w\W\d]+)<\/\bWebEnv\b>/)[0][0]

    uri = "http://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?rettype=fasta&retmode=text&retstart=0&retmax=1&db=#{db}&query_key=#{queryKey}&WebEnv=#{webEnv}"

    result = Net::HTTP.get(URI.parse(uri))

    #parse FASTA output
    rec=result
    nl = rec.index("\n")
    header = rec[0..nl-1]
    seq = rec[nl+1..-1]
    @raw_sequence = seq.gsub!(/\n/,'')
  end

end

class Hsp

  attr_accessor :hit_from #references from the unaligned hit sequence
  attr_accessor :hit_to
  attr_accessor :match_query_from # references from the unaligned query sequence
  attr_accessor :match_query_to
  attr_accessor :query_reading_frame
  attr_accessor :hit_alignment
  attr_accessor :query_alignment
  attr_accessor :middles # conserved residues are with letters, positive (mis)matches with +, mismatches and gaps are with space

  attr_accessor :bit_score
  attr_accessor :hsp_score
  attr_accessor :hsp_evalue
  attr_accessor :identity # number of conserved residues
  attr_accessor :positive # positive score for the (mis)match
  attr_accessor :gaps
  attr_accessor :align_len

end
