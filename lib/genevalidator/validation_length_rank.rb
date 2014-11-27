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
    @approach      = "If the query sequence is well conserved and similar" \
                     " sequences (BLAST hits) are correct, we can expect" \
                     " query sequence to be of a similiar length to the " \
                     " majority of hit sequences lengths. That is to say," \
                     " if ranked by length, we would expect the query" \
                     " sequence to be ranked within 80% of all hit sequence" \
                     " lengths. Here, the query length is analysed to see if" \
                     " it falls in the extreme 20% of hit sequence lengths."
    @explanation   = explain
    @conclusion    = conclude
  end

  # A method that simply puts the three parts of the explanation together...
  def explain
    "Here, BLAST produced #{@no_of_hits} hit sequences with a median" \
    " sequence length of #{@median} amino-acid residues. After ranking" \
    " by length, there are #{@extreme_hits} extreme hits (BLAST hits" \
    " that are further away from the median than the query sequence)"
  end

  def conclude
    hits.length == 1 || hits_lengths.standard_deviation <= 5
    ""
  end

  def print
    (msg.empty?) ? "#{@percentage}%" : "#{@percentage}%&nbsp;(#{@msg})"
  end

  def validation
    (msg.empty?) ? :yes : :no
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
    @description  = 'Check whether the rank of the prediction length lies' \
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
    raise NotEnoughHitsError unless hits.length >= 5
    raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence

    start = Time.now

    hits_lengths = hits.map{ |x| x.length_protein.to_i }.sort{ |a, b| a <=> b }

    no_of_hits    = hits_lengths.length
    median        = hits_lengths.median.round
    predicted_len = prediction.length_protein

    if hits.length == 1 || hits_lengths.standard_deviation <= 5
      msg = ''
      percentage = 100
    else
      # extreme_hits are hits that further away from the median than the
      #   predicted...
      if predicted_len < median
        extreme_hits = hits_lengths.find_all{ |x| x < predicted_len }.length
        percentage   = ((extreme_hits.to_f / no_of_hits) * 100).round
        msg          = 'too&nbsp;short'
      else
        extreme_hits = hits_lengths.find_all{ |x| x > predicted_len }.length
        percentage   = ((extreme_hits.to_f / no_of_hits) * 100).round
        msg          = 'too&nbsp;long'
      end
    end

    if percentage >= threshold
      msg = ''
    end

    @validation_report = LengthRankValidationOutput.new(msg, no_of_hits, median, predicted_len, extreme_hits, percentage)
    @validation_report.running_time = Time.now - start
    return @validation_report

  # Exception is raised when blast founds no hits
  rescue NotEnoughHitsError
    @validation_report = ValidationReport.new('Not enough evidence', :warning, @short_header, @header, @description, @approach, @explanation, @conclusion)
  else
    @validation_report = ValidationReport.new('Unexpected error', :error, @short_header, @header, @description, @approach, @explanation, @conclusion)
    @validation_report.errors.push OtherError
  end
end
