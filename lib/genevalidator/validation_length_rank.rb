require 'genevalidator/validation_report'
require 'genevalidator/validation_test'
require 'genevalidator/exceptions'
require 'genevalidator/enumerable'
##
# Class that stores the validation output information
class LengthRankValidationOutput < ValidationReport

  attr_reader :percentage
  attr_reader :msg

  def initialize(short_header, header, description, msg, no_of_hits, median,
                 extreme_hits, percentage)
    @msg          = msg
    @no_of_hits   = no_of_hits
    @percentage   = percentage

    @short_header, @header, @description = short_header, header, description
    @result       = validation
    @expected     = :yes
    @approach     = 'If the query sequence is well conserved and similar' \
                    ' sequences (BLAST hits) are correct, we can expect' \
                    ' query and hit sequences to have similar lengths. '

    percent_extreme_hits = (100*extreme_hits/ no_of_hits).round(1)
    @explanation  = "The query sequence is  #{@query_length} amino-acids long." \
                    " BLAST identified #{@no_of_hits} hit sequences" \
                    " with lengths from XXX to YYY (median: #{median}; mean: XXXX)." \
                    " #{extreme_hits} of these hit sequences (i.e., #{percentage}%)" \
                    " are LONGER/SHORTER than the query sequence."
    @conclusion   = conclude
  end

  def conclude
    if @result == :yes
      "There is no reason to believe there is any problem with the length of" \
      " the query sequence."
    else
      "The sequence may be #{@msg.gsub('&nbsp;', ' ')}."
    end
  end

  def print
    (@msg.empty?) ? "#{@percentage}%" : "#{@percentage}%&nbsp;(#{@msg})"
  end

  def validation
    (@msg.empty?) ? :yes : :no
  end
end

##
# This class contains the methods necessary for
# length validation by ranking the hit lengths
class LengthRankValidation < ValidationTest
  include Enumerable

  THRESHOLD = 20
  ##
  # Initializes the object
  # Params:
  # +hits+: a vector of +Sequence+ objects (usually representing the blast hits)
  # +prediction+: a +Sequence+ object representing the blast query
  # +threshold+: threshold below which the prediction length rank is considered to be inadequate
  def initialize(type, prediction, hits)
    super
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

    hits_lengths = hits.map { |x| x.length_protein.to_i }.sort { |a, b| a <=> b }

    no_of_hits   = hits_lengths.length
    median       = hits_lengths.median.round
    query_length = prediction.length_protein

    if hits_lengths.standard_deviation <= 5
      msg = ''
      percentage = 100
    else
      if query_length < median
        extreme_hits = hits_lengths.find_all { |x| x < query_length }.length
        percentage   = ((extreme_hits.to_f / no_of_hits) * 100).round
        msg          = 'too&nbsp;short'
      else
        extreme_hits = hits_lengths.find_all { |x| x > query_length }.length
        percentage   = ((extreme_hits.to_f / no_of_hits) * 100).round
        msg          = 'too&nbsp;long'
      end
    end

    msg = '' if percentage >= THRESHOLD

    @validation_report = LengthRankValidationOutput.new(@short_header, @header, @description, msg, no_of_hits, median, extreme_hits, percentage)
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
