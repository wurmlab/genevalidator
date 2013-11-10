require 'genevalidator/validation_report'
require 'genevalidator/validation_test'
require 'genevalidator/exceptions'

##
# Class that stores the validation output information
class LengthRankValidationOutput < ValidationReport

  attr_reader :percentage
  attr_reader :msg

  def initialize (msg, percentage, expected = :yes)       

    @short_header = "LengthRank"
    @header = "Length Rank"
    @description = "Check whether the rank of the prediction length lies among 80% of "<<
        "all the BLAST hit lengths. Meaning of the output displayed: no of extreme length hits / total no of hits"

    @percentage = percentage
    @msg = msg
    @result = validation
    @expected = expected
  end

  def print
    if msg != ""
      return "#{@percentage} (#{msg})"
    else 
      return @percentage.to_s
    end
  end

  def validation
    if msg == ""
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
    @short_header = "LengthRank"
    @header = "Length Rank"
    @description = "Check whether the rank of the prediction length lies among 80% of "<<
        "all the BLAST hit lengths. Meaning of the output displayed: no of extreme length hits / total no of hits"
    @cli_name = "lenr"
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
      raise NotEnoughHitsError unless hits.length >= 5
      raise Exception unless prediction.is_a? Sequence and 
                             hits[0].is_a? Sequence 

      start = Time.now

      lengths = hits.map{ |x| x.length_protein.to_i }.sort{|a,b| a<=>b}
      len = lengths.length
      median = len % 2 == 1 ? 
               lengths[len/2] : 
               (lengths[len/2 - 1] + lengths[len/2]).to_f / 2

      predicted_len = prediction.length_protein

      if hits.length == 1
        msg = ""
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
        msg = ""
      end

      @validation_report = LengthRankValidationOutput.new(msg, percentage.round(2))
      @validation_report.running_time = Time.now - start
      return @validation_report

    # Exception is raised when blast founds no hits
     rescue NotEnoughHitsError#Exception
      @validation_report = ValidationReport.new("Not enough evidence", :warning, @short_header, @header, @description)
     else
      @validation_report = ValidationReport.new("Unexpected error", :error, @short_header, @header, @description)
      @validation_report.errors.push OtherError
    end

  end

end
