#!/usr/bin/env ruby

# class that stores the values belonging by one cluster
# used for a clusterization among a vector of values
class Cluster
  #a hash map containing the pair (length, no_occurences)
  attr_accessor :lengths

  def initialize(lengths)
    @lengths = lengths
  end

  # the metohod returns the weighted mean value of the cluster
  def mean
    mean_len = 0;
    weight = 0;

    lengths.each do |length, n|
      mean_len = mean_len + length * n
      weight      = weight + n
    end		

    mean_len /= weight
    
  end

  # the method returns the density of the cluster: how many values it contains
  def density
    d = 0;
    lengths.each do |elem|
      d += elem[1]
    end
    d
  end

  # the methods returns the euclidian distance between the current cluster and another one 
  #input: cluster 2, Cluster object
  #input2: method 
  # method = 0: do not into condseideration duplicate values
  # method = 1: average linkage clustering 
  def distance(cluster, method = 0)

    d = 0;
    norm = 0

    cluster.lengths.each do |elem1|
      lengths.each do |elem2|
        if method == 1
          d += elem1[1] * elem2[1] * (elem1[0] - elem2[0]).abs
          norm += elem1[1] * elem2[1]
#          puts "#{elem1[1]} #{elem2[1]} #{(elem1[0] - elem2[0]).abs} #{d} #{norm}"
        else
          d += (elem1[0] - elem2[0]).abs
          norm = cluster.lengths.length * lengths.length             
        end
      end
    end

    #group average distance
    d /= (norm + 0.0)

  end

  #the method returns between cluster sum of squares
  def wss(lengths = nil)
    if lengths == nil
      lengths = @lengths.map{|x| a = Array.new(x[1],x[0])}.flatten
    end

    cluster_mean = mean()
    ss = 0
    lengths.each do |len|
      ss += (cluster_mean - len) * (cluster_mean - len)
    end

    ss
  end

  #the methods returns the standard deviation of a set of values
  #input (optional): a vector of values
  def standard_deviation(lengths = nil)
    if lengths == nil
      lengths = @lengths.map{|x| a = Array.new(x[1],x[0])}.flatten
    end

    cluster_mean = mean()
    std_deviation = 0
    lengths.each do |len|
      std_deviation += (cluster_mean - len) * (cluster_mean - len)
    end

    std_deviation = Math.sqrt(std_deviation.to_f / (lengths.length - 1))
  end

  #the methods returns the deviation of a value from the values in all clusters
  #input1: a list of Cluster objects
  #innput2: a reference Sequence object
  def deviation(clusters, queryLength)

    hits = clusters.map{|c| c.lengths.map{ |x| a = Array.new(x[1],x[0])}.flatten}.flatten
    raw_hits = clusters.map{|c| c.lengths.map{ |x| a = Array.new(x[1],x[0])}.flatten}.flatten.to_s.gsub('[','').gsub(']','')
    R.eval("sd = sd(c(#{raw_hits}))")
    sd = R.pull("sd")
    sd = standard_deviation(hits)
    
    (queryLength - mean).abs / sd

  end

  #the method returns the p-value of a wilcox test
  #input1: a list of Cluster objects
  #innput2: a reference Sequence object
  def wilcox_test(clusters, queryLength)

    raw_hits = clusters.map{|c| c.lengths.map{ |x| a = Array.new(x[1],x[0])}.flatten}.flatten.to_s.gsub('[','').gsub(']','')

    R.eval("library(preprocessCore)")
    R.eval("x = matrix(c(#{raw_hits}), ncol=1)")
    mean_length = raw_hits.sum / raw_hits.size.to_f
    R.eval("target = rnorm(10000, m=#{mean}, sd=sd(c(#{raw_hits})))")

    R.eval("hits = normalize.quantiles.use.target(x,target,copy=TRUE)")

    #make the wilcox-test and get the p-value
    R.eval("hits = c(#{raw_hits})")
    #R. eval("pval = wilcox.test(hits - #{queryLength})$p.value")
    #pval = R.pull "pval"
    0

  end

  #the method returns the p-value of a t-test
  #input1: a list of Cluster objects
  #innput2: a reference Sequence object
  def t_test(clusters, queryLength)

    #normalize the data so that to fit a bell curve
    #raw_hits = lengths.map{ |x| a = Array.new(x[1],x[0])}.flatten.to_s.gsub('[','').gsub(']','')
    raw_hits = clusters.map{|c| c.lengths.map{ |x| a = Array.new(x[1],x[0])}.flatten}.flatten.to_s.gsub('[','').gsub(']','')

    if raw_hits.length == 1
      R.eval("library(preprocessCore)")
      R.eval("x = matrix(c(#{raw_hits}), ncol=1)")
      mean_length = raw_hits.sum / raw_hits.size.to_f
      R.eval("target = rnorm(10000, m=#{mean}, sd=sd(c(#{raw_hits})))")

      R.eval("hits = normalize.quantiles.use.target(x,target,copy=TRUE)")

      #make the t-test and get the p-value
      R. eval("pval = t.test(hits - #{queryLength})$p.value")
      pval = R.pull "pval"
    end

  end


  # this method merges the current cluster with another one
  # input1: vector of Cluster objects
  def add(cluster)
    cluster.lengths.each do |elem|
      lengths[elem[0]] = elem[1]
    end
  end

  # this method prints the current cluster
  def print
    puts "Cluster: mean = #{mean()}, density = #{density}"
    lengths.sort{|a,b| a<=>b}.each do |elem|
      puts "#{elem[0]}, #{elem[1]}"
    end
    puts "--------------------------"
  end

  #this methos returns the interval limits of the current cluster
  def get_limits
    lengths.map{|elem| elem[0]}.minmax
  end
 
end

# input1: a vector of values
# input2 (optional): stop test (number of clusters)
# input3 (optional): distance method (method 0 or method 1)
# input4 (optional): display debug information
# output: a vector of Cluster objects
def hierarchical_clustering (vec, no_clusters = 0, distance_method = 0, debug = false)

  #puts no_clusters

  clusters = []
  vec = vec.sort

  if vec.length == 1
    hash = {vce[0]=>1}
    cluster = Cluster.new(hash)
    clusters.push(cluster)
    clusters
  end


  # Thresholds
  threshold_distance = (0.25 * (vec.max-vec.min))
  threshold_density = (0.5 * vec.length).to_i

  # make a histogram from the input vector
  histogram = Hash[vec.group_by { |x| x }.map { |k, vs| [k, vs.length] }]

  # clusters = array of clusters
  #initially each length belongs to a different cluster
  histogram.sort {|a,b| a[0]<=>b[0]}.each do |elem|
    if debug
      puts "len #{elem[0]} appears #{elem[1]} times"
    end
    hash = Hash.new
    hash[elem[0]] = elem[1]
    cluster = Cluster.new(hash)
    clusters.push(cluster)
  end

  if debug
    clusters.each do |elem|
      elem.print
    end	
  end

  # each iteration merge the closest two adiacent cluster
  # the loop stops according to the stop conditions
  iteration = 0
  loop do

    if no_clusters != 0 and clusters.length == no_clusters
      break
    end

    iteration = iteration + 1
    if debug
      puts "\nIteration #{iteration}"
    end

    min_distance = 100000000
    cluster = 0
    density = 0

    clusters.each_with_index do |item, i|
      if i < clusters.length-1
        dist = clusters[i].distance(clusters[i+1], distance_method)
        if debug
          puts "distance between clusters #{i} and #{i+1} is #{dist}"	
        end
	current_density = clusters[i].density + clusters[i+1].density
	if dist < min_distance
	  min_distance = dist
	  cluster = i
	  density = current_density
	else 
	  if dist == min_distance and density < current_density
	    cluster = i
	    density = current_density
	  end
	end
      end	
    end	

    #stop condition
    #the distance between the closest clusters exceeds the threshold
    if no_clusters == 0 and (clusters[cluster].mean - clusters[cluster+1].mean).abs > threshold_distance
        #puts "Clusterization stoped because clusters #{cluster} and #{cluster+1} that should be merged are too far one from the other."
        break
    end

    #merge clusters 'cluster' and 'cluster'+1
    if debug
      puts "clusters to merge #{cluster} and #{cluster+1}"	
    end

    clusters[cluster].add(clusters[cluster+1])
    clusters.delete_at(cluster+1)

    if debug
      clusters.each_with_index do |elem, i|
        puts "cluster #{i}"
        elem.print
      end
    end

    #stop condition
    #the density of the biggest clusters exceeds the threshold
    #puts "-- #{clusters[cluster].density} #{threshold_density}"
    #puts "#{no_clusters}"
    if no_clusters == 0 and clusters[cluster].density > threshold_density
        #puts "Clusterization stoped because cluster's #{cluster} no of elements exceeded half of the total no of elements."
        #clusters
        break
    end
  end

  clusters
end

# Main body
#Test hierarchical clustering
=begin
vec = [4,5,8,11,11,14,15,15,15,15,15,16,17,17,20]
clusters = hierarchical_clustering(vec)
max_density = 0;
max_density_cluster = 0;

clusters.each_with_index{|item, i|
	if item.density > max_density
        	max_density = item.density
                max_density_cluster = i;
       	end
}
puts "\nMost dense cluster:"
clusters[max_density_cluster].print
=end

