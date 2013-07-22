
class Alignment

  attr_accessor :hit_seq
  attr_accessor :query_seq
  attr_accessor :bit_score
  attr_accessor :score

  def initialize
  end
end

class Sequence

  attr_accessor :object_type #predicted | reference
  attr_accessor :seq_type #protein | mRNA
  attr_accessor :database
  attr_accessor :id
  attr_accessor :definition
  attr_accessor :species
  attr_accessor :accession_no
  attr_accessor :fasta_length # not used, not neccesary
  attr_accessor :xml_length
  attr_accessor :raw_sequence
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
