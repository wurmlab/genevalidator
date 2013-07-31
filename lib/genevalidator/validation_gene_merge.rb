require 'genevalidator/validation_output'

class GeneMergeValidationOutput < ValidationOutput

  attr_reader :slope
  attr_reader :threshold_down
  attr_reader :threshold_up

  def initialize (slope, threshold_down = 0.4, threshold_up = 1.2)
    @slope = slope
    @threshold_down = threshold_down
    @threshold_up = threshold_up
  end

  def print
    "#{validation.to_s} (slope=#{@slope.round(2)})"
  end

  def validation

    # color gene merge validation
    if @slope > threshold_down and @merged_genes_score < threshold_up
      :yes
    else
      :no
    end
  end

  def color
    if validation == :no
      "white"
    else
      "red"
    end
  end

end

##
# 
class GeneMergeValidation

  attr_reader :hits
  attr_reader :prediction
  attr_reader :filename

  ##
  #
  def initialize(hits, prediction, filename)
    begin
      raise QueryError unless hits[0].is_a? Sequence and prediction.is_a? Sequence
      @hits = hits
      @prediction = prediction
      @filename = filename
    end
  end


  ##
  # Validation test for gene merge
  # Output:
  # the slope of the line obtained by linear regression
  def validation_test

    plot_matched_regions(@filename)
    slope = plot_2d_start_from(@filename)
    GeneMergeValidationOutput.new(slope)

  end

  ##
  # Plots the histogram of the distribution of the middles of the hits
  # Params:
  # +output+: filename where to save the graph
  # +clusters+: array of Cluster objects
  # +middles+: array with values with potential multimodal distribution
  def plot_merge_clusters(output, clusters = @clustersi, middles)
    max_freq = clusters.map{ |x| x.lengths.map{|y| y[1]}.max}.max

    R.eval "colors = c('red', 'blue', 'yellow', 'green', 'gray', 'orange')"
    R.eval "jpeg('#{output}_match_distr.jpg')"

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
  def plot_matched_regions(output, lst = @hits, predicted_seq = @prediction)

    max_len = lst.map{|x| x.xml_length.to_i}.max

    max_plots = 120
    skip= lst.length/max_plots
    len = predicted_seq.xml_length

    R.eval "jpeg('#{output}_match.jpg')"
    R.eval "plot(1:#{lst.length-1}, xlim=c(0,#{len}), xlab='Prediction length (black) vs part of the prediction that matches hit x (red/yellow)',ylab='Hit Number', col='white')"
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
  # +hits+: array of Sequence objects
  def plot_2d_start_from(output, hits = @hits)    

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

    R.eval "jpeg('#{output}_match_2d.jpg')"
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

    R.eval "x = c#{xx.to_s.gsub("[","(").gsub("]",")")}"
    R.eval "y = c#{yy.to_s.gsub("[","(").gsub("]",")")}"
    R.eval "abline(lm(y~x, singular.ok=FALSE))"
    R.eval "slope = lm(y~x)$coefficients[2]"
    slope = R.pull "slope"

    R.eval "dev.off()"
    return slope
  end

end
