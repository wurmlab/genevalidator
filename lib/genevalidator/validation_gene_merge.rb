require 'json'
require 'genevalidator/validation_report'
require 'genevalidator/enumerable'
module GeneValidator
  ##
  # Class that stores the validation output information
  class GeneMergeValidationOutput < ValidationReport

    attr_reader :slope
    attr_reader :threshold_down
    attr_reader :threshold_up
    attr_reader :unimodality
    attr_reader :result

    def initialize(short_header, header, description, slope, unimodality,
                   threshold_down = 0.4, threshold_up = 1.2, expected = :no)
      @short_header, @header, @description = short_header, header, description
      @slope          = slope
      @unimodality    = unimodality
      @threshold_down = threshold_down
      @threshold_up   = threshold_up
      @result         = validation
      @expected       = expected
      @plot_files     = []
      @approach       = 'We expect the query sequence to encode a single' +
                        ' protein-coding gene. Here, we analyse the' +
                        ' High-scoring Segment Pairs (HSPs) identified by BLAST' +
                        ' to determine whether the query includes sequence from' +
                        ' two or more genes.'
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
        " hit strength). The resulting slope is #{@slope.round(2)}."
      end
    end

    def conclude
      if @unimodality
        'This suggest that the query sequence represents a single gene.'
      else
        diff = (@result == :yes) ? ' within' : ' outside' 
        output_text = "This slope is #{diff} our empirically calculated" +
                      " thresholds (0.4 and 1.2)."
        if @result == :yes
          output_text << ' This suggests the query contains sequence from two' +
                         ' or more different genes.'
        else
          output_text << ' There is no evidence that the query contains sequence' +
                         ' from multiple genes.'
        end 
        output_text
      end
    end

    def print
      (@slope.nan?) ? "Inf" : "#{@slope.round(2)}"
    end

    def validation
      (@slope > threshold_down and @slope < threshold_up) ? :yes : :no
    end

    def color
      (validation == :no) ? "success" : "danger"
    end
  end

  ##
  # This class contains the methods necessary for
  # checking whether there is evidence that the
  # prediction is a merge of multiple genes
  class GeneMergeValidation < ValidationTest

    include Enumerable

    attr_reader :hits
    attr_reader :prediction
    attr_reader :filename

    ##
    # Initilizes the object
    # Params:
    # +type+: type of the predicted sequence (:nucleotide or :protein)
    # +prediction+: a +Sequence+ object representing the blast query
    # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
    # +filename+: name of the input file, used when generatig the plot files
    # +boundary+: the offset of the hit from which we start analysing the hit
    def initialize(type, prediction, hits, filename, boundary=10)
      super
      @short_header = 'Gene_Merge'
      @header       = 'Gene Merge'
      @description  = 'Check whether BLAST hits make evidence about a merge of' +
                      ' two genes that match the predicted gene.'
      @cli_name     = 'merge'
      @filename     = filename
      @boundary     = boundary
    end

    ##
    # Validation test for gene merge
    # Output:
    # +GeneMergeValidationOutput+ object
    def run
      raise NotEnoughHitsError unless hits.length >= 5
      raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence

      start = Time.now

      pairs = hits.map {|hit| Pair.new(hit.hsp_list.map{|hsp| hsp.match_query_from}.min, hit.hsp_list.map{|hsp| hsp.match_query_to}.max)}
      xx_0 = pairs.map{|pair| pair.x}
      yy_0 = pairs.map{|pair| pair.y}

      # minimum start shoud be at 'boundary' residues
      xx = xx_0.map do |x|
        x = (x < @boundary) ? @boundary : x
      end

      # maximum end should be at length - 'boundary' residues
      yy = yy_0.map do |y|
        if y > @prediction.raw_sequence.length - @boundary
          y = @prediction.raw_sequence.length - @boundary
        else
          y = y
        end
      end

      line_slope = slope(xx, yy, (1..hits.length).map{|x| 1 / (x + 0.0)})
      ## YW - what is this weighting?

      unimodality = false
      if unimodality_test(xx, yy)
        unimodality = true
        lm_slope = 0.0
      else
        lm_slope = line_slope[1]
      end

      y_intercept = line_slope[0]

      @validation_report = GeneMergeValidationOutput.new(@short_header, @header, @description, lm_slope, unimodality)

      unless unimodality
        plot1 = plot_2d_start_from(lm_slope, y_intercept)
      else
        plot1 = plot_2d_start_from
      end

      @validation_report.plot_files.push(plot1)
      plot2 = plot_matched_regions
      @validation_report.plot_files.push(plot2)
      @validation_report.running_time = Time.now - start
      return @validation_report

    # Exception is raised when blast founds no hits
    rescue  NotEnoughHitsError => error
      @validation_report = ValidationReport.new('Not enough evidence', :warning, @short_header, @header, @description, @approach, @explanation, @conclusion)
      return @validation_report
    rescue Exception => error
      puts error.backtrace
      @validation_report.errors.push 'Unexpected Error'
      @validation_report = ValidationReport.new('Unexpected error', :error, @short_header, @header, @description, @approach, @explanation, @conclusion)
      return @validation_report
    end

    ##
    # Generates a json file containing data used for
    # plotting the matched region of the prediction for each hit
    # Param
    # +output+: location where the plot will be saved in jped file format
    # +hits+: array of Sequence objects
    # +prediction+: Sequence objects
    def plot_matched_regions(output = "#{filename}_match.json", hits = @hits, prediction = @prediction)

      colors   = ['orange', 'blue']  ##{colors[i%2]
      f        = File.open(output , 'w')
      no_lines = hits.length

      hits_less = hits[0..[no_lines, hits.length-1].min]

      f.write((hits_less.each_with_index.map{|hit, i|{'y'=>i, 'start'=>hit.hsp_list.map{|hsp| hsp.match_query_from}.min,
               'stop'=>hit.hsp_list.map{|hsp| hsp.match_query_to}.max, 'color'=>'black', 'dotted'=>'true'}}.flatten +
               hits_less.each_with_index.map{|hit, i| hit.hsp_list.map{|hsp|
               {'y'=>i, 'start'=>hsp.match_query_from, 'stop'=>hsp.match_query_to, 'color'=>'orange'}}}.flatten).to_json)

      f.close

      return Plot.new(output.scan(/\/([^\/]+)$/)[0][0],
                       :lines,
                       "Gene Merge Validation: Query coord covered by blast hit (1 line/hit)",
                       "",
                       "Offset in Prediction",
                       "Hit Number",
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
    def plot_2d_start_from(slope = nil, y_intercept = nil, output = "#{filename}_match_2d.json", hits = @hits)

        pairs = hits.map {|hit| Pair.new(hit.hsp_list.map{|hsp| hsp.match_query_from}.min, hit.hsp_list.map{|hsp| hsp.match_query_to}.max)}

        xx = pairs.map{|pair| pair.x}
        yy = pairs.map{|pair| pair.y}

        freq_x = xx.inject(Hash.new(0)) { |h,v| h[v] += 1; h }
        filename_x = "#{filename}_merge_x.json"
        f = File.open(filename_x, "w")
        f.write([freq_x.collect{|k,v|
            {"key"=>k, "value"=>v, "main"=>(1==2)}
          }].to_json)
        f.close
        plot3 = Plot.new(filename_x.scan(/\/([^\/]+)$/)[0][0],
                :simplebars,
                "[Gene Merge] X projection",
                "",
                "x projection",
                "number of sequences")
  #       @validation_report.plot_files.push(plot3)

        freq_y = yy.inject(Hash.new(0)) { |h,v| h[v] += 1; h }
        filename_y = "#{filename}_merge_y.json"
        f = File.open(filename_y, "w")
        f.write([freq_y.collect{|k,v|
            {"key"=>k, "value"=>v, "main"=>(1==2)}
          }].to_json)
        f.close
        plot4 = Plot.new(filename_y.scan(/\/([^\/]+)$/)[0][0],
                :simplebars,
                "[Gene Merge] Y projection",
                "",
                "y projection",
                "number of sequences")
  #       @validation_report.plot_files.push(plot4)

      f = File.open(output , "w")
      f.write(hits.map{|hit| {"x"=>hit.hsp_list.map{|hsp| hsp.match_query_from}.min,
                              "y"=>hit.hsp_list.map{|hsp| hsp.match_query_to}.max,
                              "color"=>"red"}}.to_json)
      f.close

      return Plot.new(output.scan(/\/([^\/]+)$/)[0][0],
                                  :scatter,
                                  "Gene Merge Validation: Start/end of matching hit coord. on query (1 point/hit)",
                                  "",
                                  "Start Offset (most left hsp)",
                                  "End Offset (most right hsp)",
                                   y_intercept,
                                   slope)
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
      xx_weighted = xx.each_with_index.map{|x, i| x * weights[i]}
      yy_weighted = yy.each_with_index.map{|y, i| y * weights[i]}

      denominator = weights.reduce(0) { |sum, w| w + sum }

      x_mean = xx_weighted.reduce(0) { |sum, x| x + sum } / (denominator + 0.0)
      y_mean = yy_weighted.reduce(0) { |sum, x| x + sum } / (denominator + 0.0)

      numerator = (0...xx.length).reduce(0) do |sum, i|
        sum + (weights[i] * (xx[i] - x_mean) * (yy[i] - y_mean))
      end

      denominator = (0...xx.length).reduce(0) do |sum, i|
        sum + (weights[i] * ((xx[i] - x_mean) ** 2))
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
      require 'statsample'
      sr=Statsample::Regression.simple(xx.to_scale,yy.to_scale)
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
        cond1_x = ((mean_x - median_x).abs / (sd_x+ 0.0)) < Math.sqrt(0.6)
        cond2_x = ((mean_x - mode_x).abs / (sd_x+ 0.0)) < Math.sqrt(0.3)
        cond3_x = ((median_x - mode_x).abs / (sd_x+ 0.0)) < Math.sqrt(0.3)
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
        cond1_y = ((mean_y - median_y).abs / (sd_y+ 0.0)) < Math.sqrt(0.6)
        cond2_y = ((mean_y - mode_y).abs / (sd_y+ 0.0)) < Math.sqrt(0.3)
        cond3_y = ((median_y - mode_y).abs / (sd_y+ 0.0)) < Math.sqrt(0.3)
      end

      if cond1_x and cond2_x and cond3_x and cond1_y and cond2_y and cond3_y
        return true
      else
        return false
      end
    end
  end
end