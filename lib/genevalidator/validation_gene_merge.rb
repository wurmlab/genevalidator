require 'json'
require 'genevalidator/validation_report'
require 'genevalidator/enumerable'

##
# Class that stores the validation output information
class GeneMergeValidationOutput < ValidationReport

  attr_reader :slope
  attr_reader :threshold_down
  attr_reader :threshold_up

  def initialize (slope, threshold_down = 0.4, threshold_up = 1.2, expected = :no)
    @short_header   = "Gene_Merge"
    @header         = "Gene Merge"
    @description    = "Check whether BLAST hits make evidence about a merge" \
                      " of two genes that match the predicted gene."
    @slope          = slope
    @threshold_down = threshold_down
    @threshold_up   = threshold_up
    @result         = validation
    @expected       = expected
    @plot_files     = []
    @approach       = ''
    @explanation    = put_explanation_together
    @conclusion     = ''
  end
  
  def put_explanation_together
    approach    = "This validation test analyses the relationship between" \
                  " the start and stop offsets of the High-scoring Segment" \
                  " Pairs."
    explanation = "A linear regression analysis produced a result of" \
                  " #{@slope.round(2)}. Please see below for a graphical" \
                  " representation of this."
    conclusion  = ''
    approach + explanation # + conclusion
  end

  def print
    if @slope.nan?  
      "Inf"
    else
      "#{@slope.round(2)}"
    end
  end

  def validation

    # color gene merge validation
    if @slope > threshold_down and @slope < threshold_up
      :yes
    else
      :no
    end
  end

  def color
    if validation == :no
      "success"
    else
      "danger"
    end
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
    @description  = 'Check whether BLAST hits make evidence about a merge of' \
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
    begin
      raise NotEnoughHitsError unless hits.length >= 5
      raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence

      start = Time.now

      pairs = hits.map {|hit| Pair.new(hit.hsp_list.map{|hsp| hsp.match_query_from}.min, hit.hsp_list.map{|hsp| hsp.match_query_to}.max)}
      xx_0 = pairs.map{|pair| pair.x}
      yy_0 = pairs.map{|pair| pair.y}

      # minimum start shoud be at 'boundary' residues
      xx = xx_0.map do |x|
        if x < @boundary
          x = @boundary
        else
          x = x
        end
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

      unimodality = false
      if unimodality_test(xx, yy)
        unimodality = true
        lm_slope = 0.0
      else
        lm_slope = line_slope[1]
      end
        
      y_intercept = line_slope[0]

      @validation_report = GeneMergeValidationOutput.new(lm_slope)

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
                       "[Gene Merge] Query coord covered by blast hit (1 line/hit)", 
                       "", 
                       "offset in the prediction", 
                       "number of the hit",
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
                                "[Gene Merge] Start/end of matching hit coord. on query (1 point/hit)",
                                "",
                                "start offset (most left hsp)",
                                "end offset (most right hsp)",
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

    if weights == nil
      weights = Array.new(hits.length, 1)
    end

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

    return [y_intercept, slope]

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

    return [sr.a, sr.b]
    
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

  ##
  # FUNCTION NOT USED
  # v1 and v2 are two ClusterClass objects
  def modality_test(c1, c2) 

    clusters = [c1, c2]

    no_elem_cluster0 = 0
    clusters[0].objects.each{|elem| no_elem_cluster0 += elem[1]}

    no_elem_cluster1 = 0
    clusters[1].objects.each{|elem| no_elem_cluster1 += elem[1]}
    
    no_points = no_elem_cluster0 + no_elem_cluster1

    # within cluster sum of squares
    wss0 = 0
    mean0 = clusters[0].mean
    clusters[0].objects.each{|elem| wss0 += elem[1] * (elem[0]-mean0) * (elem[0]-mean0) }

    wss1 = 0
    mean1 = clusters[1].mean
    clusters[1].objects.each{|elem| wss1 += elem[1] * (elem[0]-mean1) * (elem[0]-mean1) }

    wss = wss0 + wss1

    # total sum of squares
    sum_all_x = 0
    clusters[0].objects.each{|elem| sum_all_x += elem[1] * elem[0].x}
    clusters[1].objects.each{|elem| sum_all_x += elem[1] * elem[0].x}

    sum_all_y = 0
    clusters[0].objects.each{|elem| sum_all_y += elem[1] * elem[0].y}
    clusters[1].objects.each{|elem| sum_all_y += elem[1] * elem[0].y}

    mean_x = sum_all_x / (no_points + 0.0)
    mean_y = sum_all_y / (no_points + 0.0)

    global_mean = Pair.new(mean_x, mean_y)

    tss = 0
    clusters[0].objects.each{|elem| tss += elem[1] * (elem[0]-global_mean) * (elem[0]-global_mean) }
    clusters[1].objects.each{|elem| tss += elem[1] * (elem[0]-global_mean) * (elem[0]-global_mean) }

    # between clusters sum of squares

    diff0 = mean0 - global_mean
    diff1 = mean1 - global_mean

    bss = no_elem_cluster0 * diff0 * diff0 + no_elem_cluster1 * diff1 * diff1

    puts ""
    puts "#{no_elem_cluster0} #{no_elem_cluster1}"
    puts "bss = #{bss}; wss = #{wss}; tss = #{tss} -- #{bss + wss}"

    # a low ratio indicates a potential bimodal distribution of the clusters
    ratio1 = wss / (tss + 0.0)
    return ratio1
    #ratio2 = bss * (no_points - 2)/(wss + 0.0)
    #puts "#{ratio1} f = #{ratio2}"

  end

end
