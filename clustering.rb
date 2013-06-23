#!/usr/bin/env ruby

# class that stores the sequence lengths for each cluster
# used for a clusterization among a vector of lengths
class Cluster
  #a hash map containing the pair (length, no_occurences)
  attr_accessor :lengths

  def initialize(lengths)
    @lengths = lengths
  end

  # the weighted mean length of the cluster
  def mean
    mean_len = 0;
    weight = 0;

    lengths.each do |length, n|
      mean_len = mean_len + length * n
      weight      = weight + n
    end		

    mean_len = mean_len/weight
    mean_len
  end

  # the density of the cluster: how many sequence lengths it contains
  def density
    d = 0;
    lengths.each do |elem|
      d = d + elem[1]
    end
    d
  end

  # distance between two adiacent clusters (euclidian)
  def distance(cluster)
    d = 0;
    this_cluster_norm = 0
    cluster_norm = 0

    cluster.lengths.each do |elem1|
      lengths.each do |elem2|
        d = d + (elem1[0] - elem2[0]).abs
        #d = d + (elem1[0]* elem1[1] - elem2[0]* elem2[1]).abs
        #d = d + elem1[1] * elem2[1]*(elem1[0] - elem2[0]).abs
        cluster_norm = cluster_norm + elem1[1]
        this_cluster_norm = this_cluster_norm + elem2[1]
      end
    end
    #group average distance
    d = d/(cluster.lengths.length * lengths.length)
    #d = d/(cluster_norm * this_cluster_norm)
    d
  end

  # merge two clusters
  def add(cluster)
    cluster.lengths.each do |elem|
      lengths[elem[0]] = elem[1]
    end
  end

  #print the current cluster
  def print
    puts "Cluster: mean = #{mean()}, density = #{density}"
    lengths.sort{|a,b| a<=>b}.each do |elem|
      puts "#{elem[0]}, #{elem[1]}"
    end
    puts "--------------------------"
  end

  def get_limits
    min = 100000
    max = 0
    lengths.each do |elem|
      if min > elem[0]
        min = elem[0]
      end
      if max < elem[0]
        max = elem[0]
      end
    end
    [min,max]
  end
 
end

# takes a vector of lengths and makes hiararchical clustering
# outputs the most dense cluster
def hierarchical_clustering (vec, debug = false)

  # Thresholds
  threshold_distance = (0.25 * (vec.max-vec.min))
  threshold_density = (0.5 * vec.length).to_i

  # make a histogram from the input vector
  histogram = Hash[vec.group_by { |x| x }.map { |k, vs| [k, vs.length] }]

  # clusters = array of clusters
  #initially each length belongs to a different cluster
  clusters = Array.new 
  histogram.sort {|a,b| a[0]<=>b[0]}.each do |elem|
    if debug
      puts "len #{elem[0]} appears #{elem[1]} times"
    end
    hash = Hash.new
    hash[elem[0]] = elem[1]
    cluster = Cluster.new(hash)
    clusters.push(cluster)
  end

  puts ""

  if debug
    clusters.each do |elem|
      elem.print
    end	
  end

  # each iteration merge the closest two adiacent cluster
  # the loop stops according to the stop conditions
  iteration = 0
  while 1
    iteration = iteration + 1
    if debug
      puts "\nIteration #{iteration}"
    end

    min_distance = 100000000
    cluster = 0
    density = 0

    clusters.each_with_index do |item, i|
      if i < clusters.length-1
        dist = clusters[i].distance(clusters[i+1])
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
    if (clusters[cluster].mean - clusters[cluster+1].mean).abs > threshold_distance
      puts "Clusterization stoped because clusters #{cluster} and #{cluster+1} that should be merged are too far one from the other."
      clusters
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
    if clusters[cluster].density > threshold_density
      puts "Clusterization stoped because cluster's #{cluster} no of elements exceeded half of the total no of elements."
      clusters
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

