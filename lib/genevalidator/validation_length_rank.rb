require 'genevalidator/validation_output'
require 'genevalidator/validation_test'

##
# Class that stores the validation output information
class LengthRankValidationOutput < ValidationReport

  attr_reader :percentage
  attr_reader :msg

  def initialize (msg, percentage)       
    @percentage = percentage
    @msg = msg
  end

  def print
    "#{@percentage} (#{msg})"
  end

  def validation
    if msg == "OK"
      :yes
    else
      :no
    end
  end
end

##
# This class contains the methods necessary for 
# length validation by ranking the hit lengths
class LengthRankValidation < ValidationTest

  attr_reader :threshold

  ##
  # Initilizes the object
  # Params:
  # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
  # +prediction+: a +Sequence+ object representing the blast query
  # +threashold+: threashold below which the prediction length rank is considered to be inadequate 
  def initialize(type, prediction, hits, threshold = 0.2)
    super
    @threshold = threshold
    @short_header = "Valid_Length(Rank)"
    @header = "Valid Length(Rank)"
    @description = "Check whether the rank of the prediction length lies among 80% of all the BLAST hit lengths."
  end

  ##
  # Calculates a precentage based on the rank of the predicion among the hit lengths
  # Params:
  # +hits+ (optional): a vector of +Sequence+ objects
  # +prediction+ (optional): a +Sequence+ object
  # Output:
  # +LengthRankValidationOutput+ object
  def run(hits = @hits, prediction = @prediction)
    begin
      raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence

      lengths = hits.map{ |x| x.xml_length.to_i }.sort{|a,b| a<=>b}
      len = lengths.length
      median = len % 2 == 1 ? lengths[len/2] : (lengths[len/2 - 1] + lengths[len/2]).to_f / 2

      predicted_len = prediction.xml_length

      if hits.length == 1
        msg = "OK"
        percentage = 1
      else
        if predicted_len < median
          rank = lengths.find_all{|x| x < predicted_len}.length
          percentage = rank / (len + 0.0)
          msg = "TOO_SHORT"
        else
          rank = lengths.find_all{|x| x > predicted_len}.length
          percentage = rank / (len + 0.0)
          msg = "TOO_LONG"
        end
      end

      if percentage >= threshold
        msg = "OK"
      end

      @validation_report = LengthRankValidationOutput.new(msg, percentage.round(2))

    # Exception is raised when blast founds no hits
    rescue Exception => error
      ValidationReport.new("Not enough evidence", "Valid_Length(Rank)")
    end
  end

end
