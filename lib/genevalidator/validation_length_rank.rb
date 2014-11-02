require 'genevalidator/validation_report'
require 'genevalidator/validation_test'
require 'genevalidator/exceptions'
require 'genevalidator/enumerable'
##
# Class that stores the validation output information
class LengthRankValidationOutput < ValidationReport

  attr_reader :percentage
  attr_reader :msg

  def initialize (msg, no_of_hits, median, predicted_len, extreme_hits, 
                  percentage, expected = :yes)       

    @short_header  = 'LengthRank'
    @header        = 'Length Rank'
    @description   = 'Check whether the rank of the prediction length lies ' \
                     ' among 80% of all the BLAST hit lengths.'

    @msg           = msg
    @no_of_hits    = no_of_hits
    @median        = median
    @predicted_len = predicted_len
    @extreme_hits  = extreme_hits
    @percentage    = percentage
    @result        = validation
    @expected      = expected
    @explanation   = "If the query sequence is well conserved and database" \
                     " sequences are correct, we would expect the query and" \
                     " hit sequences to have similar lengths.  Here, BLAST" \
                     " produced "
                     " #{@no_of_hits} #{(@no_of_hits == 1) ? 'hit' : 'hits'}" \
                     " with a median sequence length of #{@median} amino" \
                     " acid residues. The prediction has a length of" \
                     " #{@predicted_len} amino acid residues. There are " \
                     " #{@extreme_hits}" \
                     " #{(@extreme_hits == 1) ? 'hit that is' : 'hits that are'}" \
                     " #{(@predicted_len < @median) ? 'shorter' : 'longer'}" \
                     " than the prediction and thus further away from the median" \
                     " compared to the prediction. This refers to a rank of " \
                     " #{@percentage}%."
  end

  def print
    if msg != ""
      return "#{@percentage}%&nbsp;(#{@msg})"
    else 
      return "#{@percentage}%"
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

  include Enumerable

  attr_reader :threshold

  ##
  # Initializes the object
  # Params:
  # +hits+: a vector of +Sequence+ objects (usually representing the blast hits)
  # +prediction+: a +Sequence+ object representing the blast query
  # +threshold+: threshold below which the prediction length rank is considered to be inadequate 
  def initialize(type, prediction, hits, threshold = 20)
    super
    @threshold    = threshold
    @short_header = 'LengthRank'
    @header       = 'Length Rank'
    @description  = 'Check whether the rank of the prediction length lies ' \
                    ' among 80% of all the BLAST hit lengths.'
    @cli_name     = 'lenr'
  end

  ##
  # Calculates a percentage based on the rank of the prediction among the hit lengths
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

      hits_lengths = hits.map{ |x| x.length_protein.to_i }.sort{|a,b| a<=>b}

      no_of_hits = hits_lengths.length
      median = hits_lengths.median.round
      predicted_len = prediction.length_protein

      if hits.length == 1 || hits_lengths.standard_deviation <= 5
        msg = ""
        percentage = 1
      else
        # extreme_hits are hits that further away from the median than the
        #   predicted...
        if predicted_len < median
          extreme_hits = hits_lengths.find_all{|x| x < predicted_len}.length
          percentage = ((extreme_hits.to_f / no_of_hits)*100).round
          msg = 'too&nbsp;short'
        else
          extreme_hits = hits_lengths.find_all{|x| x > predicted_len}.length
          percentage = ((extreme_hits.to_f / no_of_hits)*100).round
          msg = 'too&nbsp;long'
        end
      end

      if percentage >= threshold
        msg = ""
      end

      @validation_report = LengthRankValidationOutput.new(msg, no_of_hits, median, predicted_len, extreme_hits, percentage)
      @validation_report.running_time = Time.now - start
      return @validation_report

    # Exception is raised when blast founds no hits
     rescue NotEnoughHitsError#Exception
      @validation_report = ValidationReport.new('Not enough evidence', :warning, @short_header, @header, @description, @explanation)
     else
      @validation_report = ValidationReport.new('Unexpected error', :error, @short_header, @header, @description, @explanation)
      @validation_report.errors.push OtherError
    end
  end
end
