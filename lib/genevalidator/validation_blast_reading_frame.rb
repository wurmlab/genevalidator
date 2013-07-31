require 'genevalidator/validation_output'

class BlastRFValidationOutput < ValidationOutput

  attr_reader :frames_histo
  attr_reader :msg

  def initialize (frames_histo)

    @frames_histo = frames_histo
    @msg = ""

    rez = ""
    frames_histo.each do |x, y|
      @msg << "#{x}:#{y};"      
    end

  end

  def print
    "#{validation.to_s} (#{@msg})"
  end

  def validation

    # if there are different reading frames of the same sign
    # count for positive reading frames
    count_p = 0
    count_n = 0
    frames_histo.each do |x, y|
      if x > 0
        count_p += 1
      else
        if x < 0
          count_n += 1
        end
      end
    end

    if count_p > 1 or count_n > 1
      :no
    else
      :yes
    end

  end

end


##
# This class contains the methods necessary for 
# reading frame validation based on BLAST output
class BlastReadingFrameValidation

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
  # Check reading frame inconsistency
  # Params:
  # +lst+: vector of +Sequence+ objects
  # Output:
  # output1: yes/no answer
  # output2: additional information (what reading frames were used)
  def validation_test(lst = @hits)

    rfs =  lst.map{ |x| x.hsp_list.map{ |y| y.query_reading_frame}}.flatten
    frames_histo = Hash[rfs.group_by { |x| x }.map { |k, vs| [k, vs.length] }]

    answ = BlastRFValidationOutput.new(frames_histo)

  end

end
