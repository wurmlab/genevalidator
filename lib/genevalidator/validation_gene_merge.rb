require 'forwardable'
require 'statsample'

require 'genevalidator/exceptions'
require 'genevalidator/ext/array'
require 'genevalidator/validation_report'
require 'genevalidator/validation_test'

module GeneValidator
  ##
  # Class that stores the validation output information
  class GeneMergeValidationOutput < ValidationReport
    attr_reader :slope
    attr_reader :threshold_down
    attr_reader :threshold_up
    attr_reader :unimodality
    attr_reader :result

    # These thresholds are emperically chosen.
    UPPER_THRESHOLD = 1.2 # radians
    LOWER_THRESHOLD = 0.4 # radians

    def initialize(short_header, header, description, slope, unimodality,
                   expected = :no)
      @short_header, @header, @description = short_header, header, description
      @slope          = slope.round(1)
      @slope          = @slope.abs if @slope == -0.0
      @unimodality    = unimodality
      @threshold_down = LOWER_THRESHOLD
      @threshold_up   = UPPER_THRESHOLD
      @result         = validation
      @expected       = expected
      @plot_files     = []
      @approach       = 'We expect the query sequence to encode a single' \
                        ' protein-coding gene. Here, we analyse the' \
                        ' High-scoring Segment Pairs (HSPs) identified by' \
                        ' BLAST to determine whether the query includes' \
                        ' sequence from two or more genes.'
      @explanation    = explain
      @conclusion     = conclude
    end

    def explain
      if @unimodality
        'The start coordinates and the end coordinates of HSPs are unimodally' \
        ' distributed.'
      else
        'The distribution of start and/or end-coordinates of HSPs are' \
        ' multi-modal. To detect potential problems we performed a linear'\
        ' regression (with coordinates weighted inversely proportionally to '\
        " hit strength). The resulting slope is #{@slope}."
      end
    end

    def conclude
      if @unimodality
        'This suggest that the query sequence represents a single gene.'
      else
        diff = (@result == :yes) ? ' within' : ' outside'
        t = "This slope is #{diff} our empirically calculated thresholds" \
            ' (0.4 and 1.2).'
        if @result == :yes
          t << ' This suggests the query contains sequence from two or more' \
               ' different genes.'
        else
          t << ' There is no evidence that the query contains sequence from' \
               ' multiple genes.'
        end
        t
      end
    end

    def print
      (@slope.nan?) ? 'Inf' : "#{@slope}"
    end

    def validation
      (@slope > threshold_down && @slope < threshold_up) ? :yes : :no
    end

    def color
      (validation == :no) ? 'success' : 'danger'
    end
  end

  ##
  # This class contains the methods necessary for
  # checking whether there is evidence that the
  # prediction is a merge of multiple genes
  class GeneMergeValidation < ValidationTest
    attr_reader :prediction
    attr_reader :hits

    ##
    # Initilizes the object
    # Params:
    # +prediction+: a +Sequence+ object representing the blast query
    # +hits+: a vector of +Sequence+ objects (representing blast hits)
    # +plot_path+: name of the input file, used when generatig the plot files
    # +boundary+: the offset of the hit from which we start analysing the hit
    def initialize(prediction, hits, boundary = 10)
      super
      @short_header = 'GeneMerge'
      @header       = 'Gene Merge'
      @description  = 'Check whether BLAST hits make evidence about a merge' \
                      ' of two genes that match the predicted gene.'
      @cli_name     = 'merge'
      @boundary     = boundary
    end

    ##
    # Validation test for gene merge
    # Output:
    # +GeneMergeValidationOutput+ object
    def run
      fail NotEnoughHitsError unless hits.length >= 5
      fail Exception unless prediction.is_a?(Sequence) && hits[0].is_a?(Sequence)

      start = Time.now

      pairs = hits.map { |hit| Pair.new(hit.hsp_list.map{ |hsp| hsp.match_query_from }.min,
                                        hit.hsp_list.map{ |hsp| hsp.match_query_to }.max) }
      xx_0 = pairs.map(&:x)
      yy_0 = pairs.map(&:y)

      # minimum start shoud be at 'boundary' residues
      xx = xx_0.map { |x| (x < @boundary) ? @boundary : x }

      # maximum end should be at length - 'boundary' residues
      yy = yy_0.map do |y|
        if y > @prediction.raw_sequence.length - @boundary
          @prediction.raw_sequence.length - @boundary
        else
          y
        end
      end

      line_slope = slope(xx, yy, (1..hits.length).map{ |x| 1 / (x + 0.0) })
      ## YW - what is this weighting?

      unimodality = false
      if unimodality_test(xx, yy)
        unimodality = true
        lm_slope = 0.0
      else
        lm_slope = line_slope[1]
      end

      y_intercept = line_slope[0]

      @validation_report = GeneMergeValidationOutput.new(@short_header, @header,
                                                         @description, lm_slope,
                                                         unimodality)
      if unimodality
        plot1 = plot_2d_start_from
      else
        plot1 = plot_2d_start_from(lm_slope, y_intercept)
      end

      @validation_report.plot_files.push(plot1)
      plot2 = plot_matched_regions
      @validation_report.plot_files.push(plot2)
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

    ##
    # Generates a json file containing data used for
    # plotting the matched region of the prediction for each hit
    # Param
    # +output+: location where the plot will be saved in jped file format
    # +hits+: array of Sequence objects
    # +prediction+: Sequence objects
    def plot_matched_regions(hits = @hits)
      no_lines = hits.length

      hits_less = hits[0..[no_lines, hits.length - 1].min]

      data = hits_less.each_with_index.map { |hit, i|
        { 'y' => i,
          'start' => hit.hsp_list.map(&:match_query_from).min,
          'stop' => hit.hsp_list.map(&:match_query_to).max,
          'color' =>'black',
          'dotted' =>'true'}}.flatten +
        hits_less.each_with_index.map { |hit, i|
          hit.hsp_list.map { |hsp|
            { 'y' => i,
              'start' => hsp.match_query_from,
              'stop' => hsp.match_query_to,
              'color' => 'orange'} } }.flatten

      Plot.new(data,
               :lines,
               'Gene Merge Validation: Query coord covered by blast hit (1 line/hit)',
               '',
               'Offset in Prediction',
               'Hit Number',
               hits_less.length)
    end

    ##
    # Generates a json file containing data used for
    # plotting the start/end of the matched region offsets in the prediction
    # Param
    # +slope+: slope of the linear regression line
    # +y_intercept+: the ecuation of the line is y= slope*x + y_intercept
    # +output+: location where the plot will be saved in jped file format
    # +hits+: array of Sequence objects
    def plot_2d_start_from(slope = nil, y_intercept = nil, hits = @hits)
      pairs = hits.map do |hit|
        Pair.new(hit.hsp_list.map(&:match_query_from).min,
                 hit.hsp_list.map(&:match_query_to).max)
      end

      data = hits.map { |hit| { 'x' => hit.hsp_list.map(&:match_query_from).min,
                                'y' => hit.hsp_list.map(&:match_query_to).max,
                                'color' => 'red'}}

      Plot.new(data,
               :scatter,
               'Gene Merge Validation: Start/end of matching hit coord. on query (1 point/hit)',
               '',
               'Start Offset (most left hsp)',
               'End Offset (most right hsp)',
               y_intercept.to_s,
               slope.to_s)
    end

    ##
    # Caclulates the slope of the regression line
    # give a set of 2d coordonates of the start/stop offests of the hits
    # Param
    # xx: +Array+ of integers
    # yy : +Array+ of integers
    # weights: +Array+ of integers
    # Output:
    # The ecuation of the regression line: [y slope]
    def slope(xx, yy, weights = nil)
      weights = Array.new(hits.length, 1) if weights.nil?

      # calculate the slope
      xx_weighted = xx.each_with_index.map { |x, i| x * weights[i] }
      yy_weighted = yy.each_with_index.map { |y, i| y * weights[i] }

      denominator = weights.reduce(0) { |a, e| a + e }

      x_mean = xx_weighted.reduce(0) { |a, e| a + e } / (denominator + 0.0)
      y_mean = yy_weighted.reduce(0) { |a, e| a + e } / (denominator + 0.0)

      numerator = (0...xx.length).reduce(0) do |a, e|
        a + (weights[e] * (xx[e] - x_mean) * (yy[e] - y_mean))
      end

      denominator = (0...xx.length).reduce(0) do |a, e|
        a + (weights[e] * ((xx[e] - x_mean)**2))
      end

      slope = numerator / (denominator + 0.0)
      y_intercept = y_mean - (slope * x_mean)

      [y_intercept, slope]
    end

    ##
    # Caclulates the slope of the regression line
    # give a set of 2d coordonates of the start/stop offests of the hits
    # Param
    # xx : +Array+ of integers
    # yy : +Array+ of integers
    # Output:
    # The ecuation of the regression line: [y slope]
    def slope_statsample(xx, yy)
      sr = Statsample::Regression.simple(xx.to_scale, yy.to_scale)
      [sr.a, sr.b]
    end

    ##
    # xx and yy are the projections of the 2-d data on the two axes
    def unimodality_test(xx, yy)
      mean_x = xx.mean
      median_x = xx.median
      mode_x = xx.mode
      sd_x = xx.standard_deviation

      if sd_x == 0
        cond1_x = true
        cond2_x = true
        cond3_x = true
      else
        cond1_x = ((mean_x - median_x).abs / (sd_x + 0.0)) < Math.sqrt(0.6)
        cond2_x = ((mean_x - mode_x).abs / (sd_x + 0.0)) < Math.sqrt(0.3)
        cond3_x = ((median_x - mode_x).abs / (sd_x + 0.0)) < Math.sqrt(0.3)
      end

      mean_y = yy.mean
      median_y = yy.median
      mode_y = yy.mode
      sd_y = yy.standard_deviation

      if sd_y == 0
        cond1_y = true
        cond2_y = true
        cond3_y = true
      else
        cond1_y = ((mean_y - median_y).abs / (sd_y + 0.0)) < Math.sqrt(0.6)
        cond2_y = ((mean_y - mode_y).abs / (sd_y + 0.0)) < Math.sqrt(0.3)
        cond3_y = ((median_y - mode_y).abs / (sd_y + 0.0)) < Math.sqrt(0.3)
      end

      if cond1_x && cond2_x && cond3_x && cond1_y && cond2_y && cond3_y
        true
      else
        false
      end
    end
  end
end
