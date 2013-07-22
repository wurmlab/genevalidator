require './sequences'
require './blastQuery'
require 'rinruby.rb'

class QueryError < Exception
end

##
# This class stores all the data obtained from the blast query

class BlastQuery

  attr_reader :filename
  attr_reader :query_index
  attr_reader :hits
  attr_reader :prediction
  attr_reader :clusters
  attr_reader :max_density_cluster
  attr_reader :mean
  attr_reader :reading_frame

##
# Initilizes the object
# Params:
# +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
# +prediction+: a +Sequence+ object representing the blast query
# +filename+: name of the input file, used when generatig the plot files
# query_index: the number of the query in the blast output

  def initialize(hits, prediction, filename, query_index)
    begin
      raise QueryError unless hits[0].is_a? Sequence and prediction.is_a? Sequence and filename.is_a? String and query_index.is_a? Fixnum
      @hits = hits
      @prediction = prediction
      @filename = filename
      @query_index = query_index
      @reading_frame = {}
    end
  end

##
# Calculates a precentage based on the rank of the predicion among the hit lengths
# Params:
# +threshold+: limit above which we consider the validation passed
# +hits+ (optional): a vector of +Sequence+ objects
# +prediction+ (optional): a +Sequence+ object
  def length_rank(threshold = 0.2,  hits = @hits, prediction = @prediction)
    begin
      raise TypeError unless hits[0].is_a? Sequence and prediction.is_a? Sequence

      lengths = hits.map{ |x| x.xml_length.to_i }.sort{|a,b| a<=>b}
      len = lengths.length
      median = len % 2 == 1 ? lengths[len/2] : (lengths[len/2 - 1] + lengths[len/2]).to_f / 2

      predicted_len = prediction.xml_length.to_i
      if predicted_len < median
        rank = lengths.find_all{|x| x < predicted_len}.length
        percentage = rank / (len + 0.0)
        msg = "TOO_SHORT"
      else
        rank = lengths.find_all{|x| x > predicted_len}.length
        percentage = rank / (len + 0.0)
        msg = "TOO_LONG"
      end

      if percentage >= threshold
        msg = "YES"
      end
      [percentage.round(2), msg]

    rescue TypeError => error
      $stderr.print "Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: one of the arguments of 'length_rank' method has not the proper type.\n"
      exit
    end
  end

  ## 
  # Validates the length of the predicted gene by comparing the length of the prediction to the most dense cluster
  # The most dense cluster is obtained by hierarchical clusterization
  # Output:
  # array of 2 elements containing the limits of the most dense cluster i.e [limit_left; limit_right]
  def length_validation

      ret = clusterization_by_length  #returns [clusters, max_density_cluster_idx]

      @clusters = ret[0]
      @max_density_cluster = ret[1]
      @mean = @clusters[@max_density_cluster].mean      
      predicted_len = @prediction.xml_length

      plot_histo_clusters(@filename)
      plot_length(@filename)
      limits = @clusters[@max_density_cluster].get_limits

      if predicted_len <= limits[1] and predicted_len >= limits[0]
        status = "YES"
      else
        status = "NO"
      end

      return [limits[0], limits[1]]
  end

  ## 
  # Check reading frame inconsistency
  # Params:
  # +lst+: vector of +Sequence+ objects
  # Output:
  # output1: yes/no answer
  # output2: additional information (what reading frames were used)
  def reading_frame_validation(lst = @hits)

    rfs =  lst.map{ |x| x.hsp_list.map{ |y| y.query_reading_frame}}.flatten
    frames_histo = Hash[rfs.group_by { |x| x }.map { |k, vs| [k, vs.length] }]
    #rez = ""
    rez={}
    frames_histo.each do |x, y|
      #rez << "#{x} #{y}; "
      rez[x]=y
    end

    # if there are different reading frames of the same sign
    # count for positive reading frames
    count_p = 0
    count_n = 0
    frames_histo.each do |x, y|
      if x > 0
        count_p = count_p + 1
      else 
        if x < 0
          count_n = count_n + 1
        end
      end
    end

    if count_p > 1 or count_n > 1
      answ = "INVALID"
    else
      answ = "VALID"
    end

    @reading_frame = rez    
    return [answ, rez]
  end

  ##
  # Validation test for gene merge
  # Output:
  # the slope of the line obtained by linear regression
  def gene_merge_validation

    plot_matched_regions(@filename)
    slope = plot_2d_start_from(@filename)

  end

  ##
  # Check duplication in the first n hits
  # Returns yes/no answer
  def check_duplication (n=10)

    # get the first n hits
    less_hits = @hits[0..[n-1,@hits.length].min]
    averages = []

    less_hits.each do |hit|
      # indexing in blast starts from 1
      start_match_interval =  hit.hsp_list.each.map{|x| x.hit_from}.min - 1
      end_match_interval = hit.hsp_list.map{|x| x.hit_to}.max - 1
   
      #puts "#{hit.xml_length} #{start_match_interval} #{end_match_interval}" 

      coverage = Array.new(hit.xml_length,0)
      hit.hsp_list.each do |hsp|
        aux = []
        # for each hsp
        # iterate through the alignment and count the matching residues
        [*(0 .. hsp.align_len-1)].each do |i|
          residue_hit = hsp.hit_alignment[i]
          residue_query = hsp.query_alignment[i]
          if residue_hit != ' ' and residue_hit != '+' and residue_hit != '-'
            if residue_hit == residue_query             
              idx = i + (hsp.hit_from-1) - hsp.hit_alignment[0..i].scan(/-/).length 
              aux.push(idx)
              #puts "#{idx} #{i} #{hsp.hit_alignment[0..i].scan(/-/).length}"
              # indexing in blast starts from 1
              coverage[idx] += 1
            end
          end
        end
      end
      overlap = coverage.reject{|x| x==0}
      averages.push(overlap.inject(:+)/(overlap.length + 0.0))
    end
  
    # if all hsps match only one time
    if averages.reject{|x| x==1} == []
      return ["NO",1]
    end

    R.eval("library(preprocessCore)")

    #make the wilcox-test and get the p-value
    R.eval("coverageDistrib = c#{averages.to_s.gsub('[','(').gsub(']',')')}")
    R. eval("pval = wilcox.test(coverageDistrib - 1)$p.value")
    pval = R.pull "pval"

    if pval < 0.01
      status = "YES"
    else
      status = "NO"
    end
     return [status, pval]
  end

  ##
  # Find open reading frames in the original sequence
  # Applied only to nucleotide sequences
  # Params:
  # +prediction+: +Sequence+ object
  # Output:
  # hash of reading frames
  def orf_find(prediction = @prediction)

    if prediction.seq_type != "nucleotide"
      "-"
    end
    
    #stop codons
    stop_codons = ["TAG", "TAA", "TGA"]
    #minimimum ORF length
    orf_length = 100
 
    seq = prediction.raw_sequence
    stops = {}
    result = {}

    stop_codons.each do |codon|
      occurences = (0 .. seq.length - 1).find_all { |i| seq[i,3].downcase == codon.downcase }
      occurences.each do |occ|
        stops[occ + 3] = codon
      end
    end


    #direct strand
    stop_positions = stops.map{|x| x[0]}
    result["+1"] = []
    result["+2"] = []
    result["+3"] = []
    result["-1"] = []
    result["-2"] = []
    result["-3"] = []

    #reading frame 1, direct strand
    m3 = stops.map{|x| x[0]}.select{|y| y % 3 == 0}.sort
    m3 = [1, m3, prediction.raw_sequence.length].flatten
    #puts "multiple of 3: #{m3.to_s}"
    (1..m3.length-1).each do |i|
      if m3[i] - m3[i-1] > orf_length
#        result[[m3[i-1], m3[i]]] = "+1"
         result["+1"].push([m3[i-1], m3[i]])
      end
    end
 
    #reading frame 2, direct strand
    m3_1 = stops.map{|x| x[0]}.select{|y| y % 3 == 1}.sort
    m3_1 = [2, m3_1, prediction.raw_sequence.length].flatten
    #puts "multiple of 3 + 1: #{m3_1.to_s}"
    (1..m3_1.length-1).each do |i|
      if m3_1[i] - m3_1[i-1] > orf_length
#        result[[m3_1[i-1], m3_1[i]]] = "+2"
         result["+2"].push([m3_1[i-1], m3_1[i]])
      end
    end

    #reading frame 3, direct strand
    m3_2 = stops.map{|x| x[0]}.select{|y| y % 3 == 2}.sort
    m3_2 = [3, m3_2, prediction.raw_sequence.length].flatten
    #puts "multiple of 3 + 2: #{m3_2.to_s}"
    (1..m3_2.length-1).each do |i|
      if m3_2[i] - m3_2[i-1] > orf_length
#        result[[m3_2[i-1], m3_2[i]]] = "+3"
         result["+3"].push([m3_2[i-1], m3_2[i]])
      end
    end

    #reverse strand
    stops_reverse = {}
    seq_reverse = seq.reverse.downcase.gsub('a','T').gsub('t','A').gsub('c','G').gsub('g','C')
    stop_codons.each do |codon|
      occurences = (0 .. seq_reverse.length - 1).find_all { |i| seq_reverse[i,3].downcase == codon.downcase }
      #puts "-1 #{codon}: #{occurences.to_s}"
      occurences.each do |occ|
        stops_reverse[occ + 3] = codon
      end
    end

    stop_positions_reverse = stops_reverse.map{|x| x[0]}
    m3 = stops_reverse.map{|x| x[0]}.select{|y| y % 3 == 0}.sort
    m3 = [1, m3, prediction.raw_sequence.length].flatten
    #puts "-1 multiple of 3: #{m3.to_s}"
    (1..m3.length-1).each do |i|
      if m3[i] - m3[i-1] > orf_length
#        result[[m3[i-1], m3[i]]] = "-1"
         result["-1"].push([m3[i-1], m3[i]])
      end
    end

    m3_1 = stops_reverse.map{|x| x[0]}.select{|y| y % 3 == 1}.sort
    m3_1 = [2, m3_1, prediction.raw_sequence.length].flatten
    #puts "-1 multiple of 3 + 1: #{m3_1.to_s}"
    (1..m3_1.length-1).each do |i|
      if m3_1[i] - m3_1[i-1] > orf_length
        result["-2"].push([m3_1[i-1], m3_1[i]])
      end
    end

    m3_2 = stops_reverse.map{|x| x[0]}.select{|y| y % 3 == 2}.sort
    m3_2 = [3, m3_2, prediction.raw_sequence.length].flatten
    #puts "-1 multiple of 3 + 2: #{m3_2.to_s}"
    (1..m3_2.length-1).each do |i|
      if m3_2[i] - m3_2[i-1] > orf_length
        result["-3"].push([m3_2[i-1], m3_2[i]])
#        result[[m3_2[i-1], m3_2[i]]] = "-3"
      end
    end

    result
  end  

  ##
  # Clusterization by length from a list of sequences
  # Params:
  # +lst+:: array of +Sequence+ objects
  # +predicted_seq+:: +Sequence+ objetc
  # +debug+ (optional):: true to display debug information, false by default (optional argument)
  # Output
  # output 1:: array of Cluster objects
  # output 2:: the index of the most dense cluster
  def clusterization_by_length(debug = false, lst = @hits, predicted_seq = @prediction)
    begin
      raise TypeError unless lst[0].is_a? Sequence and predicted_seq.is_a? Sequence

      contents = lst.map{ |x| x.xml_length.to_i }.sort{|a,b| a<=>b}

      hc = HierarchicalClusterization.new(contents)
      clusters = hc.hierarchical_clusterization

      max_density = 0;
      max_density_cluster_idx = 0;
      clusters.each_with_index do |item, i|
        if item.density > max_density
          max_density = item.density
          max_density_cluster_idx = i;
        end
      end

      return [clusters, max_density_cluster_idx]

    rescue TypeError => error
      $stderr.print "Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: one of the arguments of 'clusterization_by_length' method has not the proper type.\n"
      exit
    end
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
  # Plots lines corresponding to each length
  # Highlights the start and end hit offsets
  # +output+: filename where to save the graph
  # +lst+: array of Sequence objects
  # +predicted_seq+: Sequence object
  def plot_length(output, lst = @hits, predicted_seq = @prediction)
    max_len = lst.map{|x| x.xml_length.to_i}.max
    lst = lst.sort{|a,b| a.xml_length<=>b.xml_length}

    max_plots = 120
    skip= lst.length/max_plots

    R.eval "jpeg('#{output}_len.jpg')"
    R.eval "plot(1:#{[lst.length-1,max_plots].min}, xlim=c(0,#{max_len}), xlab='Hit Length (black) vs part of the hit that matches the query (red)',ylab='Hit Number', col='white')"
    height = -1;
    lst.each_with_index do |seq,i|
      if skip == 0 or i%skip == 0
        height += 1
        R.eval "lines(c(1,#{seq.xml_length}), c(#{height}, #{height}), lwd=10)"
        seq.hsp_list.each do |hsp|
          R.eval "lines(c(#{hsp.hit_from},#{hsp.hit_to}), c(#{height}, #{height}), lwd=6, col='red')"
        end
      end
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


  ##
  # Plots a histogram of the length distribution given a list of Cluster objects
  # Params:
  # +output+: filename where to save the graph
  # +clusters+: array of Cluster objects
  # +predicted_length+: length of the rpedicted sequence
  # +most_dense_cluster_idx+index from the clusters array of the most_dense_cluster_idx
  def plot_histo_clusters(output, clusters = @clusters, predicted_length = @prediction.xml_length, 
                          most_dense_cluster_idx = @max_dense_cluster)
    begin
      raise TypeError unless clusters[0].is_a? Cluster and predicted_length.is_a? Fixnum

      lengths = clusters.map{ |c| c.lengths.sort{|a,b| a[0]<=>b[0]}.map{ |x| a = Array.new(x[1],x[0])}.flatten}.flatten
      lengths.push(predicted_length)

      max_freq = clusters.map{ |x| x.lengths.map{|y| y[1]}.max}.max
      #make the plot in a new process
        R.eval "colors = c('orange', 'blue', 'yellow', 'green', 'gray')"

        unless output == nil
          #puts "---- #{output}"
          #R.eval "dev.copy(png,'#{output}.png')"
          R.eval "jpeg('#{output}_len_clusters.jpg')"
        end

        clusters.each_with_index do |cluster, i|
          cluster_lengths = cluster.lengths.sort{|a,b| a[0]<=>b[0]}.map{ |x| a = Array.new(x[1],x[0])}.flatten

          if i == @max_density_cluster
            color = "'red'"
          else
            color = "colors[#{i%5+1}]"
          end

          R.eval "hist(c#{cluster_lengths.to_s.gsub('[','(').gsub(']',')')},
                     breaks = seq(#{lengths.min-10}, #{lengths.max+10}, 0.1),
                     xlim=c(#{lengths.min-10},#{lengths.max+10}),
                     ylim=c(0,#{max_freq}),
                     col=#{color},
                     border=#{color},
                     main='Histogram for length distribution', xlab='length\nblack = predicted sequence, red = most dense cluster')"
          R.eval "par(new=T)"
        end

        R.eval "abline(v=#{predicted_length})"

        unless output == nil
          R.eval "dev.off()"
        end

    rescue TypeError => error
      $stderr.print "Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: one of the arguments of 'plot_histo_clusters' method has not the proper type.\n"
      exit
    end
  end


  ##
  # Calculates the silhouette score of the sequence
  # Params:
  # +seq+: Sequence object
  # +idx+: index of the cluster with the maximul internisty
  # +clusters+:array of +Cluster+ objects
  # Output
  # the silhouette of the sequence
  def sequence_silhouette (seq = @prediction, idx = @max_density_cluster, clusters = @clusters)
    seq_len = seq.xml_length

    #the average dissimilarity of the sequence with other elements in idx cluster
    a = 0
    clusters[idx].lengths.each do |len, frecv|
      a = a + (len - seq_len).abs
    end
    a = a.to_f / clusters[idx].lengths.length

    b_vector = Array.new

    clusters.each_with_index do |cluster, i|
      #the average dissimilarity of the sequence with the members of cluster i
      if i != idx
        b = 0
        cluster.lengths.each do |len, frecv|
          b = b + (len - seq_len).abs
        end
        b = b.to_f / cluster.lengths.length
        unless b == 0
          b_vector.push(b)
        end
      end
    end
    b = b_vector.min
    if b == nil
      b=0
    end
    silhouette = (b - a).to_f / [a,b].max
    return silhouette
  end

end


