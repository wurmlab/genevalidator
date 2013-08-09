require 'genevalidator/validation_output'

##
# Class that stores the validation output information
class BlastRFValidationOutput < ValidationReport

  attr_reader :frames_histo
  attr_reader :msg

  def initialize (frames_histo)
    @frames_histo = frames_histo
    @msg = ""
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
class BlastReadingFrameValidation < ValidationTest

  def initialize(type, prediction, hits = nil)
    super
    @short_header = "Valid_RF"
    @header = "Valid Reading Frame"
    @description = "Check whether there are reading frame shifts along the query sequence."
  end

  ## 
  # Check reading frame inconsistency
  # Params:
  # +lst+: vector of +Sequence+ objects
  # Output:
  # +BlastRFValidationOutput+ object
  def run(lst = @hits)
    begin
      raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence

      rfs =  lst.map{ |x| x.hsp_list.map{ |y| y.query_reading_frame}}.flatten
      frames_histo = Hash[rfs.group_by { |x| x }.map { |k, vs| [k, vs.length] }]

      @validation_report = BlastRFValidationOutput.new(frames_histo)

    # Exception is raised when blast founds no hits
    rescue Exception => error
      ValidationReport.new("Not enough evidence")
    end
  end
end
