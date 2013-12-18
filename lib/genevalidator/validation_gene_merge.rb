require 'json'
require 'rinruby'
require 'genevalidator/validation_report'

##
# Class that stores the validation output information
class GeneMergeValidationOutput < ValidationReport

  attr_reader :slope
  attr_reader :threshold_down
  attr_reader :threshold_up

  def initialize (slope, threshold_down = 0.4, threshold_up = 1.2, expected = :no)

    @short_header = "Gene_Merge"
    @header       = "Gene Merge"
    @description = "Check whether BLAST hits make evidence about a merge of two"<<
    " genes that match the predicted gene. Meaning of the output displayed:"<<
    " slope of the linear regression of the relationship between the start and"<<
    " stop offsets of the hsps (see the plot). Invalid slopes are around 45 degrees."

    @slope          = slope
    @threshold_down = threshold_down
    @threshold_up   = threshold_up
    @result         = validation
    @expected       = expected
    @plot_files     = []
  end

  def print
    if @slope.nan?  
      "slope=Inf"
    else
      "slope=#{@slope.round(2)}"
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

module Enumerable

  def sum
    return self.inject(0){|accum, i| accum + i }
  end

  def mean
    return self.sum / self.length.to_f
  end

  def median
    sorted = self.sort
    len = sorted.length
    return (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end

  def mode
    freq = self.inject(Hash.new(0)) { |h,v| h[v] += 1; h }
    self.sort_by { |v| freq[v] }.last
  end

  def sample_variance
    m = self.mean
    sum = self.inject(0){|accum, i| accum + (i - m) ** 2 }
    return sum / (self.length - 1).to_f
  end

  def standard_deviation
    return Math.sqrt(self.sample_variance)
  end

end

##
# This class contains the methods necessary for
# checking whether there is evidence that the
# prediction is a merge of multiple genes
class GeneMergeValidation < ValidationTest

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
  def initialize(type, prediction, hits, filename)
    super
    @filename     = filename
    @short_header = "Gene_Merge"
    @header       = "Gene Merge"
    @description = "Check whether BLAST hits make evidence about a merge of two"<<
    " genes that match the predicted gene. Meaning of the output displayed:"<<
    " slope of the linear regression of the relationship between the start and"<<
    " stop offsets of the hsps (see the plot). Invalid slopes are around 45 degrees."
    @cli_name     = "merge"
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
      xx = pairs.map{|pair| pair.x}
      yy = pairs.map{|pair| pair.y}

      if unimodlity_test(xx, yy)
        lm_slope = 0.0
      else
        lm_slope = slope[1]
      end
        
      y_intercept = slope[0]

      @validation_report = GeneMergeValidationOutput.new(lm_slope)

      plot1 = plot_2d_start_from(lm_slope, y_intercept)
      @validation_report.plot_files.push(plot1)
      plot2 = plot_matched_regions
      @validation_report.plot_files.push(plot2)
      @validation_report.running_time = Time.now - start
      return @validation_report

    # Exception is raised when blast founds no hits
    rescue  NotEnoughHitsError => error
      @validation_report = ValidationReport.new("Not enough evidence", :warning, @short_header, @header, @description)
      return @validation_report
    rescue Exception => error
      puts error.backtrace
      @validation_report.errors.push "Unexpected Error" 
      @validation_report = ValidationReport.new("Unexpected error", :error, @short_header, @header, @description)
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

      colors   = ["orange", "blue"]  ##{colors[i%2]
      f        = File.open(output , "w")
      no_lines = hits.length

      hits_less = hits[0..[no_lines, hits.length-1].min]


      f.write((hits_less.each_with_index.map{|hit, i|{"y"=>i, "start"=>hit.hsp_list.map{|hsp| hsp.match_query_from}.min,
               "stop"=>hit.hsp_list.map{|hsp| hsp.match_query_to}.max, "color"=>"black", "dotted"=>"true"}}.flatten +
               hits_less.each_with_index.map{|hit, i| hit.hsp_list.map{|hsp|
               {"y"=>i, "start"=>hsp.match_query_from, "stop"=>hsp.match_query_to, "color"=>"orange"}}}.flatten).to_json)

=begin
      f.write((
               hits_less.each_with_index.map{|hit, i| hit.hsp_list.map{|hsp|
               {"y"=>i, "start"=>hsp.match_query_from, "stop"=>hsp.match_query_to, "color"=>"orange"}}}.flatten +  # ).to_json)
                  
               hits_less.each_with_index.map{|hit, i| hit.hsp_list[1.. hit.hsp_list.length-1].select.with_index{|hsp,jj|
               hit.hsp_list[jj].match_query_to < hit.hsp_list[jj+1].match_query_from}.each_with_index.map{|hsp, j|
              {"y"=>i, "start"=>hit.hsp_list[j].match_query_to, "stop"=>hit.hsp_list[j+1].match_query_from, "color"=>"black", "dotted"=>"true"}}}.flatten).to_json)
=end
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
  def plot_2d_start_from(slope, y_intercept, output = "#{filename}_match_2d.json", hits = @hits)    

=begin
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
       @validation_report.plot_files.push(plot3)

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
       @validation_report.plot_files.push(plot4)

=begin
    R.eval "jpeg('#{filename}_merge_x.jpg')"
    R.eval "hist(c#{xx.to_s.gsub('[','(').gsub(']',')')},
              breaks = 30,
              main='X projection', xlab='x_projection')" 
    R.eval "par(new=T)" 

    R.eval "jpeg('#{filename}_merge_y.jpg')"
    R.eval "hist(c#{yy.to_s.gsub('[','(').gsub(']',')')},
              breaks = 30,
              main='X projection', xlab='x_projection')"
    R.eval "par(new=T)"

=begin
    R.echo "enable = nil, stderr = nil" #redirect the cosole messages of R
    R.eval "library(diptest)"
    R.eval "pval_x = dip(c#{xx.to_s.gsub('[','(').gsub(']',')')})"
    pval_x = R.pull("pval_x")

    R.eval "pval_y = dip(c#{yy.to_s.gsub('[','(').gsub(']',')')})"
    pval_y = R.pull("pval_y")

    puts "pval_x = dip(c#{xx.to_s.gsub('[','(').gsub(']',')')})"
    puts "pval_y = dip(c#{yy.to_s.gsub('[','(').gsub(']',')')})"

    puts "pval_x = #{pval_x.round(2)}, pval_y = #{pval_y.round(2)}"
=end

=begin
    pairs = hits.map {|hit| Pair.new(hit.hsp_list.map{|hsp| hsp.match_query_from}.min, hit.hsp_list.map{|hsp| hsp.match_query_to}.max)}
    xx = pairs.map{|pair| pair.x}
    yy = pairs.map{|pair| pair.y}

    hc = HierarchicalClusterization.new(pairs)
    clusters = hc.hierarchical_clusterization_2d(2, 1)

    f = File.open(output , "w")
    f.write((clusters[0].objects.map{|elem|  {"x"=>elem[0].x,
                                              "y"=>elem[0].y,
                                              "color"=>"red"}} +
             clusters[1].objects.map{|elem|  {"x"=>elem[0].x,
                                              "y"=>elem[0].y,
                                              "color"=>"blue"}}).to_json)

    f.close
=end

    f = File.open(output , "w")
    f.write(hits.map{|hit| {"x"=>hit.hsp_list.map{|hsp| hsp.match_query_from}.min,
                             "y"=>hit.hsp_list.map{|hsp| hsp.match_query_to}.max}}.to_json)
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
  # +hits+: array of Sequence objects
  # Output:
  # The ecuation of the regression line: [y slope]
  def slope(hits = @hits)

    require 'statsample'
  
    pairs = hits.map {|hit| Pair.new(hit.hsp_list.map{|hsp| hsp.match_query_from}.min, hit.hsp_list.map{|hsp| hsp.match_query_to}.max)}

    xx = pairs.map{|pair| pair.x}
    yy = pairs.map{|pair| pair.y}

    sr=Statsample::Regression.simple(xx.to_scale,yy.to_scale)

    return [sr.a, sr.b]
    
  end

  ##
  # xx and yy are the projections of the 2-d data on the two axes
  def unimodlity_test(xx, yy)

    mean_x = xx.mean
    median_x = xx.median
    mode_x = xx.mode
    sd_x = xx.standard_deviation

    cond1_x = ((mean_x - median_x).abs / (sd_x+ 0.0)) < Math.sqrt(0.6)
    cond2_x = ((mean_x - mode_x).abs / (sd_x+ 0.0)) < Math.sqrt(0.3)
    cond3_x = ((median_x - mode_x).abs / (sd_x+ 0.0)) < Math.sqrt(0.3)

    mean_y = yy.mean
    median_y = yy.median
    mode_y = yy.mode
    sd_y = yy.standard_deviation

    cond1_y = ((mean_y - median_y).abs / (sd_y+ 0.0)) < Math.sqrt(0.6)
    cond2_y = ((mean_y - mode_y).abs / (sd_y+ 0.0)) < Math.sqrt(0.3)
    cond3_y = ((median_y - mode_y).abs / (sd_y+ 0.0)) < Math.sqrt(0.3)

    if cond1_x and cond2_x and cond3_x and cond1_y and cond2_y and cond3_y
      return true
    else
      return false
    end

  end

  ##
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
