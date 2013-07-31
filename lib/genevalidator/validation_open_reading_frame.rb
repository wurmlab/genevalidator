require 'genevalidator/validation_output'

class ORFValidationOutput < ValidationOutput

  attr_reader :orfs

  def initialize (orfs)
    @orfs = orfs
  end

  def print
    no_orfs = @orfs.map{|elem| elem[1].length}.reduce(:+)
    orf_list = ""
    @orfs.map{|elem| orf_list<<"#{elem[0]}:#{elem[1].to_s},"}

    "#{no_orfs}"
  end

  def validation
    :no
  end
end

##
# 
class OpenReadingFrameValidation

  attr_reader :hits
  attr_reader :prediction

  ##
  #
  def initialize(hits, prediction)
    begin
      raise QueryError unless hits[0].is_a? Sequence and prediction.is_a? Sequence
      @hits = hits
      @prediction = prediction
    end
  end

  ##
  # Find open reading frames in the original sequence - static method
  # Applied only to nucleotide sequences
  # Params:
  # +orf_length+: minimimum ORF length, default 100
  # +prediction+: +Sequence+ object
  # Output:
  # hash of reading frames
  def validation_test(orf_length = 100, prediction = @prediction)

    if prediction.seq_type != "nucleotide"
      "-"
    end
    
    #stop codons
    stop_codons = ["TAG", "TAA", "TGA"]
 
    seq = prediction.raw_sequence
    stops = {}
    result = {}

    stop_codons.each do |codon|
      occurences = (0 .. seq.length - 1).find_all { |i| seq[i,3].downcase == codon.downcase }
      occurences.each do |occ|
        stops[occ + 3] = codon
      end
    end

    #direct strand
    stop_positions = stops.map{|x| x[0]}
    result["+1"] = []
    result["+2"] = []
    result["+3"] = []
    result["-1"] = []
    result["-2"] = []
    result["-3"] = []

    #reading frame 1, direct strand
    m3 = stops.map{|x| x[0]}.select{|y| y % 3 == 0}.sort
    m3 = [1, m3, prediction.raw_sequence.length].flatten
    (1..m3.length-1).each do |i|
      if m3[i] - m3[i-1] > orf_length
         result["+1"].push([m3[i-1], m3[i]])
      end
    end
 
    #reading frame 2, direct strand
    m3_1 = stops.map{|x| x[0]}.select{|y| y % 3 == 1}.sort
    m3_1 = [2, m3_1, prediction.raw_sequence.length].flatten
    (1..m3_1.length-1).each do |i|
      if m3_1[i] - m3_1[i-1] > orf_length
         result["+2"].push([m3_1[i-1], m3_1[i]])
      end
    end

    #reading frame 3, direct strand
    m3_2 = stops.map{|x| x[0]}.select{|y| y % 3 == 2}.sort
    m3_2 = [3, m3_2, prediction.raw_sequence.length].flatten
    (1..m3_2.length-1).each do |i|
      if m3_2[i] - m3_2[i-1] > orf_length
         result["+3"].push([m3_2[i-1], m3_2[i]])
      end
    end

    #reverse strand
    stops_reverse = {}
    seq_reverse = seq.reverse.downcase.gsub('a','T').gsub('t','A').gsub('c','G').gsub('g','C')
    stop_codons.each do |codon|
      occurences = (0 .. seq_reverse.length - 1).find_all { |i| seq_reverse[i,3].downcase == codon.downcase }
      occurences.each do |occ|
        stops_reverse[occ + 3] = codon
      end
    end

    stop_positions_reverse = stops_reverse.map{|x| x[0]}
    m3 = stops_reverse.map{|x| x[0]}.select{|y| y % 3 == 0}.sort
    m3 = [1, m3, prediction.raw_sequence.length].flatten
    (1..m3.length-1).each do |i|
      if m3[i] - m3[i-1] > orf_length
         result["-1"].push([m3[i-1], m3[i]])
      end
    end

    m3_1 = stops_reverse.map{|x| x[0]}.select{|y| y % 3 == 1}.sort
    m3_1 = [2, m3_1, prediction.raw_sequence.length].flatten
    (1..m3_1.length-1).each do |i|
      if m3_1[i] - m3_1[i-1] > orf_length
        result["-2"].push([m3_1[i-1], m3_1[i]])
      end
    end

    m3_2 = stops_reverse.map{|x| x[0]}.select{|y| y % 3 == 2}.sort
    m3_2 = [3, m3_2, prediction.raw_sequence.length].flatten
    (1..m3_2.length-1).each do |i|
      if m3_2[i] - m3_2[i-1] > orf_length
        result["-3"].push([m3_2[i-1], m3_2[i]])
      end
    end

    ORFValidationOutput.new(result)
  end  
end
