
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
  attr_accessor :e_value
  attr_accessor :fasta_length
  attr_accessor :xml_length
  attr_accessor :raw_sequence
  attr_accessor :alignment
  attr_accessor :alignment_start_offset
  attr_accessor :hit_from
  attr_accessor :hit_to

  def initialize
  end

  def print
    puts "#{@object_type} sequence: #{@definition} "
    puts "Lengths xml #{@xml_length} fasta #{@fasta_length} hit #{@alignment.hit_seq.length}"
    puts "Accession = #{@accession_no}"
    puts "Species = #{@species}"
    puts "hit from: #{@alignment_start_offset} #{@hit_from} #{@hit_to}"
    puts "Raw_sequence = #{@raw_sequence.insert(@hit_from-1,'#').insert(@hit_to+1,'#')}"
    puts "Hit seq =      #{alignment.hit_seq}"
    puts "Query seq =    #{alignment.query_seq}"
    puts "----------------------"
  end

end
