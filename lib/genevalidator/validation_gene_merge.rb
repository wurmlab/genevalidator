require 'genevalidator/validation_output'
require 'json'

##
# Class that stores the validation output information
class GeneMergeValidationOutput < ValidationReport

  attr_reader :slope
  attr_reader :threshold_down
  attr_reader :threshold_up

  def initialize (slope, threshold_down = 0.4, threshold_up = 1.2, expected = :no)
    @slope = slope
    @threshold_down = threshold_down
    @threshold_up = threshold_up
    @result = validation
    @expected = expected
  end

  def print
    "slope=#{@slope.round(2)}"
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

  attr_reader :hits
  attr_reader :prediction
  attr_reader :filename
  attr_reader :plot_files

  ##
  # Initilizes the object
  # Params:
  # +type+: type of the predicted sequence (:nucleotide or :protein)
  # +prediction+: a +Sequence+ object representing the blast query
  # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
  # +plot_filename+: name of the input file, used when generatig the plot files
  def initialize(type, prediction, hits, filename)
    super
    @filename = filename
    @short_header = "Gene_Merge(slope)"
    @header = "Gene Merge"
    @description = "Check whether BLAST hits make evidence about a merge of two genes that match the predicted gene. Meaning of the output displayed: slope of the linear regression of the relationship between the start and stop offsets of the hsps (see the plot). Valid slopes are around 45 degrees."
    @cli_name = "merge"
  end

  ##
  # Validation test for gene merge
  # Output:
  # +GeneMergeValidationOutput+ object
  def run
    begin
      raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence and hits.length >= 5

      lm_slope = slope[1]
      y_intercept = slope[0]

      f = File.open("#{@filename}_match_2d.json" , "w")
      f.write(@hits.map{|hit| {"x"=>hit.hsp_list.map{|hsp| hsp.match_query_from}.min, 
                               "y"=>hit.hsp_list.map{|hsp| hsp.match_query_to}.max}}.to_json)
      f.close
      @plot_files.push(Plot.new("#{@filename}_match_2d.json".scan(/\/([^\/]+)$/)[0][0], 
                                :scatter, 
                                "Start vs end hsp match", 
                                "", 
                                "from", 
                                "to",
                                 y_intercept,
                                 lm_slope))

      colors = ["yellow", "red"]
      f = File.open("#{@filename}_match.json" , "w")
      f.write((@hits.each_with_index.map{|hit, i| {"y"=>i, "start"=>0, "stop"=>@prediction.xml_length, "color"=>"black"}} +
              @hits.each_with_index.map{|hit, i| hit.hsp_list.map{|hsp| {"y"=>i, "start"=>hsp.match_query_from, "stop"=>hsp.match_query_to, "color"=>"#{colors[i%2]}"}}}.flatten).to_json)
      f.close
      @plot_files.push(Plot.new("#{@filename}_match.json".scan(/\/([^\/]+)$/)[0][0], 
                                :lines,  
                                "Prediction vs hit match", 
                                "prediction in black, part of the prediction that matches the hit in red/yellow", 
                                "length", 
                                "idx"))

      @validation_report = GeneMergeValidationOutput.new(lm_slope)
      @validation_report.plot_files = @plot_files

    # Exception is raised when blast founds no hits
    rescue Exception => error
#      puts error.backtrace
      ValidationReport.new("Not enough evidence")
    end
  end

  ##
  # Plots the histogram of the distribution of the middles of the hits
  # Params:
  # +output+: filename where to save the graph
  # +clusters+: array of Cluster objects
  # +middles+: array with values with potential multimodal distribution
  def plot_merge_clusters(output = "#{filename}_match_distr.jpg", clusters = @clusters, middles)
    max_freq = clusters.map{ |x| x.lengths.map{|y| y[1]}.max}.max

    R.eval "colors = c('red', 'blue', 'yellow', 'green', 'gray', 'orange')"
    R.eval "jpeg('#{output}')"

    clusters.each_with_index do |cluster, i|
      cluster_values = cluster.lengths.sort{|a,b| a[0]<=>b[0]}.map{ |x| a = Array.new(x[1],x[0])}.flatten
      color = "colors[#{i%5+1}]"

      R.eval "hist(c#{cluster_values.to_s.gsub('[','(').gsub(']',')')},
                     breaks = 30,
                     xlim=c(#{middles.min-10},#{middles.max+10}),
                     ylim=c(0,#{max_freq}),
                     col=#{color},
                     border=#{color},
                     main='Predction match distribution (middle of the matches)', xlab='position idx', ylab='Frequency')"
      R.eval "par(new=T)"
    end
    R.eval "dev.off()"

  end

  ##  
  # Plots lines corresponding to each hit
  # highlights the matched region of the prediction for each hit
  # Param
  # +output+: location where the plot will be saved in jped file format
  # +lst+: array of Sequence objects
  # +predicted_seq+: Sequence objects
  def plot_matched_regions(output = "#{filename}_match.jpg", lst = @hits, predicted_seq = @prediction)

    max_len = lst.map{|x| x.xml_length.to_i}.max

    max_plots = 120
    skip= lst.length/max_plots
    len = predicted_seq.xml_length

    R.eval "jpeg('#{output}')"
    R.eval "plot(1:#{lst.length-1}, xlim=c(0,#{len}), xlab='Prediction length (black) vs part of the prediction that matches hit x (red/yellow)',ylab='Hit Number', col='white', main='Hit matches in the prediction')"
    R.eval "colors = c('yellow', 'red')"
    R.eval "colors2 = c('black', 'gray')"
    height = -1;
    lst.each_with_index do |seq,i|
      #if skip == 0 or i%skip == 0
      #if i < max_plots
        height += 1
        color = "colors[#{height%2+1}]"
        color2 = "colors2[#{height%2+1}]"
        R.eval "lines(c(1,#{len}), c(#{height}, #{height}), lwd=7)"
        seq.hsp_list.each do |hsp|
          R.eval "lines(c(#{hsp.match_query_from},#{hsp.match_query_to}), c(#{height}, #{height}), lwd=6, col=#{color})"         
        end
      #end
    end
    R.eval "dev.off()"
  end

  ##  
  # Plots 2D graph with the start/end of the matched region offsets in the prediction
  # Param
  # +output+: location where the plot will be saved in jped file format
  # +slope+: slope of the linear regression line
  # +hits+: array of Sequence objects
  def plot_2d_start_from(slope, output = "#{filename}_match_2d.jpg", hits = @hits)    

    pairs = @hits.map {|hit| Pair.new(hit.hsp_list.map{|hsp| hsp.match_query_from}.min, hit.hsp_list.map{|hsp| hsp.match_query_to}.max)}

    xx = pairs.map{|pair| pair.x}
    yy = pairs.map{|pair| pair.y}

    min_start = hits.map{|hit| hit.hsp_list.map{|hsp| hsp.match_query_from}.min}.min
    max_start = hits.map{|hit| hit.hsp_list.map{|hsp| hsp.match_query_from}.max}.max

    min_end = hits.map{|hit| hit.hsp_list.map{|hsp| hsp.match_query_to}.min}.min
    max_end = hits.map{|hit| hit.hsp_list.map{|hsp| hsp.match_query_to}.min}.max

    #calculate the likelyhood to have a binomial distribution
    #split into two clusters

    #hc = HierarchicalClusterization.new(pairs)
    #clusters = hc.hierarchical_clusterization_2d(2, 1)
    R.eval "jpeg('#{output}')"
    R.eval "colors = c('red', 'blue')";

    #clusters.each_with_index do |cluster, i|
    #  x_values = cluster.objects.map{|pair| pair[0].x}
    #  y_values = cluster.objects.map{|pair| pair[0].y}

    x_values = xx
    y_values = yy

      color = "'red'"#"colors[#{i%2+1}]"
      R.eval "plot(c#{x_values.to_s.gsub("[","(").gsub("]",")")},
                   c#{y_values.to_s.gsub("[","(").gsub("]",")")},
                   xlim=c(0,#{max_start+10}), 
                   ylim=c(0,#{max_end+10}), 
                   col=#{color}, 
                   main='Start vs end match 2D plot', xlab='from', ylab='to', 
                   pch=10)"        
      R.eval "par(new=T)"           
    #end
 
    unless slope.nan?
      R.eval "x = c#{xx.to_s.gsub("[","(").gsub("]",")")}"
      R.eval "y = c#{yy.to_s.gsub("[","(").gsub("]",")")}"
      R.eval "abline(lm(y~x, singular.ok=FALSE))"
    end
    R.eval "dev.off()"
  end

  ##  
  # Plots 2D graph with the start/end of the matched region offsets in the prediction
  # Param
  # +hits+: array of Sequence objects
  # Code inspired from: http://engineering.sharethrough.com/blog/2012/09/12/simple-linear-regression-using-ruby/
  # Output:
  # The ecuation of the regression line: [y slope]
  def slope(hits = @hits)
    
    pairs = @hits.map {|hit| Pair.new(hit.hsp_list.map{|hsp| hsp.match_query_from}.min, hit.hsp_list.map{|hsp| hsp.match_query_to}.max)}

    xx = pairs.map{|pair| pair.x}
    yy = pairs.map{|pair| pair.y}

=begin
    R.eval "x = c#{xx.to_s.gsub("[","(").gsub("]",")")}"
    R.eval "y = c#{yy.to_s.gsub("[","(").gsub("]",")")}"
    R.eval "slope = lm(y~x)$coefficients[2]"
    slope = R.pull "slope"
=end 
   
    # calculate the slope
    x_mean = xx.reduce(0) { |sum, x| x + sum } / (xx.length + 0.0)
    y_mean = yy.reduce(0) { |sum, x| x + sum } / (yy.length + 0.0)
 
    numerator = (0...xx.length).reduce(0) do |sum, i|
      sum + ((xx[i] - x_mean) * (yy[i] - y_mean))
    end
 
    denominator = xx.reduce(0) do |sum, x|
      sum + ((x - x_mean) ** 2)
    end
 
    slope = numerator / (denominator + 0.0)
    y_intercept = y_mean - (slope * x_mean)

    return [y_intercept, slope]
    
  end

end
