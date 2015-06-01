require 'genevalidator/validation_report'
require 'genevalidator/validation_test'
require 'genevalidator/exceptions'
require 'genevalidator/ext/array'
module GeneValidator
  ##
  # Class that stores the validation output information
  class LengthRankValidationOutput < ValidationReport
    attr_reader :msg
    attr_reader :query_length
    attr_reader :no_of_hits
    attr_reader :median
    attr_reader :mean
    attr_reader :smallest_hit
    attr_reader :largest_hit
    attr_reader :extreme_hits
    attr_reader :percentage
    attr_reader :result

    def initialize(short_header, header, description, msg, query_length,
                   no_of_hits, median, mean, smallest_hit, largest_hit,
                   extreme_hits, percentage)
      @short_header, @header, @description = short_header, header, description
      @msg          = msg
      @query_length = query_length
      @no_of_hits   = no_of_hits
      @median       = median
      @mean         = mean
      @smallest_hit = smallest_hit
      @largest_hit  = largest_hit
      @extreme_hits = extreme_hits
      @percentage   = percentage

      @result       = validation
      @expected     = :yes
      @approach     = 'If the query sequence is well conserved and similar' \
                      ' sequences (BLAST hits) are correct, we can expect' \
                      ' query and hit sequences to have similar lengths.'
      @explanation  = explain
      @conclusion   = conclude
    end

    def explain
      diff = (@query_length < @median) ? 'longer' : 'shorter'
      exp1 = "The query sequence is  #{@query_length} amino-acids long. BLAST" \
             " identified #{@no_of_hits} hit sequences with lengths from" \
             " #{@smallest_hit} to #{@largest_hit} amino-acids (median:" \
             " #{@median}; mean: #{@mean})."
      if @extreme_hits != 0
        exp2 = " #{@extreme_hits} of these hit sequences (i.e." \
               " #{@percentage}%) are #{diff} than the query sequence."
      else
        exp2 = " All hit sequences are #{diff} than the query sequence."
      end
      exp1 + exp2
    end

    def conclude
      if @result == :yes
        'There is no reason to believe there is any problem with the length' \
        ' of the query sequence.'
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
    THRESHOLD = 20
    ##
    # Initializes the object
    # Params:
    # +prediction+: a +Sequence+ object representing the blast query
    # +hits+: a vector of +Sequence+ objects (representing blast hits)
    def initialize(prediction, hits)
      super
      @short_header = 'LengthRank'
      @header       = 'Length Rank'
      @description  = 'Check whether the rank of the prediction length lies' \
                      ' among 80% of all the BLAST hit lengths.'
      @cli_name     = 'lenr'
    end

    ##
    # Calculates a percentage based on the rank of the prediction among the
    # hit lengths
    # Params:
    # +hits+ (optional): a vector of +Sequence+ objects
    # +prediction+ (optional): a +Sequence+ object
    # Output:
    # +LengthRankValidationOutput+ object
    def run(hits = @hits, prediction = @prediction)
      fail NotEnoughHitsError unless hits.length >= 5
      fail Exception unless prediction.is_a?(Sequence) && hits[0].is_a?(Sequence)

      start = Time.now

      hits_lengths = hits.map { |x| x.length_protein.to_i }.sort { |a, b| a <=> b }

      no_of_hits   = hits_lengths.length
      median       = hits_lengths.median.round
      query_length = prediction.length_protein
      mean         = hits_lengths.mean.round

      smallest_hit = hits_lengths[0]
      largest_hit  = hits_lengths[-1]

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

      @validation_report = LengthRankValidationOutput.new(@short_header,
                                                          @header, @description,
                                                          msg, query_length,
                                                          no_of_hits, median,
                                                          mean, smallest_hit,
                                                          largest_hit,
                                                          extreme_hits,
                                                          percentage)
      @validation_report.run_time = Time.now - start
      @validation_report

    rescue NotEnoughHitsError
      @validation_report = ValidationReport.new('Not enough evidence', :warning,
                                                @short_header, @header,
                                                @description)
    rescue Exception
      @validation_report = ValidationReport.new('Unexpected error', :error,
                                                @short_header, @header,
                                                @description)
      @validation_report.errors.push 'Unexpected Error'
    end
  end
end
