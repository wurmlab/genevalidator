# Top level module / namespace.
module GeneValidator
  Pair = Struct.new(:x, :y) do
    include Comparable

    ##
    # Overload '-' operator
    # Returns the euclidian distane between two pairs
    def -(other)
      xx = other.x
      yy = other.y
      Math.sqrt((x - xx) * (x - xx) + (y - yy) * (y - yy))
    end

    def print
      puts "Cluster: #{x} #{y}"
    end

    ##
    # Overload '+' operator
    # This will modify the current object
    def +(other)
      self.x += other.x
      self.y += other.y
    end

    ##
    # Overload '*' operator
    # This will modify the current object
    def *(other)
      self.x *= other
      self.y *= other
    end

    ##
    # Overload '/' operator
    # This will modify the current object
    def /(other)
      self.x /= other.to_i
      self.y /= other.to_i
    end

    ##
    # Overload quality operator
    # Returns true if the pairs are equal, false otherwise
    def ==(other)
      (other.x == x && other.y == y) ? true : false
    end

    def eql?(other)
      self == other
    end

    def hash
      [self.x, self.y].hash
    end
  end

  class PairCluster
    # a hash map containing the pair (object, no_occurences)
    attr_accessor :objects

    def initialize(objects)
      @objects = objects
    end

    def print
      objects.each do |elem|
        puts "(#{elem[0].x},#{elem[0].y}): #{elem[1]}"
      end
    end

    ##
    # Returns the weighted mean value of the cluster
    def mean
      mean = Pair.new(0, 0)
      weight = 0

      objects.each do |object, n|
        (1..n).each do |_i|
          mean + object
          weight += 1
        end
      end
      mean / weight
      mean
    end

    ##
    # Returns the density of the cluster: how many values it contains
    def density
      d = 0
      objects.each do |elem|
        d += elem[1]
      end
      d
    end

    # Returns the euclidian distance between the current cluster and the one
    # given as parameter
    # Params:
    # +cluster+: Cluster object
    # +method+: 0 or 1
    # method = 0: do not into condseideration duplicate values
    # method = 1: average linkage clusterization
    def distance(cluster, method = 0)
      d = 0
      norm = 0

      cluster.objects.each do |elem1|
        objects.each do |elem2|
          if method == 1
            d += elem1[1] * elem2[1] * (elem1[0] - elem2[0]).abs
            norm += elem1[1] * elem2[1]
          else
            d += (elem1[0] - elem2[0]).abs
            norm = cluster.objects.length * objects.length
          end
        end
      end

      # group average distance
      d /= (norm + 0.0)
    end

    ##
    # Returns within cluster sum of squares
    def wss(objects = nil)
      if objects.nil?
        objects = @objects.map { |x| Array.new(x[1], x[0]) }.flatten
      end

      cluster_mean = mean
      ss = 0
      objects.each do |object|
        ss += (cluster_mean - object) * (cluster_mean - object)
      end
      ss
    end

    ##
    # Merges the current cluster with the one given as parameter
    # +clusters+ vector of Cluster objects
    def add(cluster)
      cluster.objects.each do |elem|
        objects[elem[0]] = elem[1]
      end
    end
  end

  ##
  # Stores the values belonging to one cluster
  # Used for clusterization among a vector of values
  class Cluster
    # a hash map containing the pair (length, no_occurences)
    attr_accessor :lengths

    def initialize(lengths)
      @lengths = lengths
    end

    ##
    # Returns the weighted mean value of the cluster
    def mean
      mean_len = 0
      weight = 0

      lengths.each do |length, n|
        mean_len += length * n
        weight += n
      end
      mean_len /= weight
    end

    ##
    # Returns the density of the cluster: how many values it contains
    def density
      d = 0
      lengths.each do |elem|
        d += elem[1]
      end
      d
    end

    # Returns the euclidian distance between the current cluster and the one
    # given as parameter
    # Params:
    # +cluster+: Cluster object
    # +method+: 0 or 1
    # method = 0: do not into condseideration duplicate values
    # method = 1: average linkage clusterization
    def distance(cluster, method = 0)
      d = 0
      norm = 0

      cluster.lengths.each do |elem1|
        lengths.each do |elem2|
          if method == 1
            d += elem1[1] * elem2[1] * (elem1[0] - elem2[0]).abs
            norm += elem1[1] * elem2[1]
          else
            d += (elem1[0] - elem2[0]).abs
            norm = cluster.lengths.length * lengths.length
          end
        end
      end

      # group average distance
      d /= (norm + 0.0)
      d.round(4)
    end

    ##
    # Returns within cluster sum of squares
    def wss(lengths = nil)
      if lengths.nil?
        lengths = @lengths.map { |x| Array.new(x[1], x[0]) }.flatten
      end

      cluster_mean = mean
      ss = 0
      lengths.each do |len|
        ss += (cluster_mean - len) * (cluster_mean - len)
      end
      ss
    end

    ##
    # Returns the standard deviation of a set of values
    # Params:
    # +lengths+: a vector of values (optional, by default it takes the values in
    # the cluster)
    # Output:
    # Real number
    def standard_deviation(lengths = nil)
      if lengths.nil?
        lengths = @lengths.map { |x| Array.new(x[1], x[0]) }.flatten
      end

      cluster_mean = mean
      std_deviation = 0
      lengths.each do |len|
        std_deviation += (cluster_mean - len) * (cluster_mean - len)
      end
      std_deviation = Math.sqrt(std_deviation.to_f / (lengths.length - 1))
    end

    ##
    # Returns the deviation of a value from the values in all clusters
    # Params:
    # +clusters+: a list of Cluster objects
    # +queryLength+: a reference Sequence object
    # Output:
    # Real number
    def deviation(clusters, queryLength)
      hits = clusters.map { |c| c.lengths.map { |x| Array.new(x[1], x[0]) }.flatten }.flatten
      raw_hits = clusters.map { |c| c.lengths.map { |x| Array.new(x[1], x[0]) }.flatten }.flatten.to_s.gsub('[', '').gsub(']', '')
      R.eval("sd = sd(c(#{raw_hits}))")
      sd = R.pull('sd')
      sd = standard_deviation(hits)
      (queryLength - mean).abs / sd
    end

    ##
    # Merges the current cluster with the one given as parameter
    # +clusters+ vector of Cluster objects
    def add(cluster)
      cluster.lengths.each do |elem|
        lengths[elem[0]] = elem[1]
      end
    end

    ##
    # Prints the current cluster
    def print
      puts "Cluster: mean = #{mean}, density = #{density}"
      lengths.sort { |a, b| a <=> b }.each do |elem|
        puts "#{elem[0]}, #{elem[1]}"
      end
      puts '--------------------------'
    end

    ##
    # Returns the interval limits of the current cluster
    def get_limits
      lengths.map { |elem| elem[0] }.minmax
    end

    ##
    # Returns whether the value is inside the cluster
    # Params:
    # +value+: value to compare
    # Output:
    # :ok or :shorter or :longer
    def inside_cluster(value)
      limits = get_limits
      left = limits[0]
      right = limits[1]

      :ok if left <= value && right >= value
      :shorter if left >= value
      :longer if right <= value
    end
  end

  class HierarchicalClusterization
    attr_accessor :values
    attr_accessor :clusters

    ##
    # Object initialization
    # Params:
    # +values+ :vector of values
    def initialize(values)
      @values = values
      @clusters = []
    end

    def hierarchical_clusterization_2d(no_clusters = 0, distance_method = 0,
                                       vec = @values, debug = false)
      clusters = []

      if vec.length == 1
        hash = { vec[0] => 1 }
        cluster = PairCluster.new(hash)
        clusters.push(cluster)
        clusters
      end

      # Thresholds
      # threshold_distance = (0.25 * (vec.max-vec.min))
      threshold_density = (0.5 * vec.length).to_i

      # make a histogram from the input vector
      histogram = Hash[vec.group_by { |a| a }.map { |k, vs| [k, vs.length] }]

      # clusters = array of clusters
      # initially each length belongs to a different cluster
      histogram.each do |elem|
        if debug
          puts "pair (#{elem[0].x} #{elem[0].y}) appears #{elem[1]} times"
        end
        hash = { elem[0] => elem[1] }
        cluster = PairCluster.new(hash)
        clusters.push(cluster)
      end

      clusters.each(&:print) if debug

      return clusters if clusters.length == 1

      # each iteration merge the closest two adiacent cluster
      # the loop stops according to the stop conditions
      iteration = 0
      loop do
        # stop condition 1
        break if no_clusters != 0 && clusters.length == no_clusters

        iteration += 1
        puts "\nIteration #{iteration}" if debug

        min_distance = 100_000_000
        cluster1     = 0
        cluster2     = 0
        density      = 0

        [*(0..(clusters.length - 2))].each do |i|
          [*((i + 1)..(clusters.length - 1))].each do |j|
            dist = clusters[i].distance(clusters[j], distance_method)
            puts "distance between clusters #{i} and #{j} is #{dist}" if debug
            current_density = clusters[i].density + clusters[j].density
            if dist < min_distance
              min_distance = dist
              cluster1 = i
              cluster2 = j
              density = current_density
            elsif dist == min_distance && density < current_density
              cluster1 = i
              cluster2 = j
              density = current_density
            end
          end
        end

        # merge clusters 'cluster1' and 'cluster2'
        puts "clusters to merge #{cluster1} and #{cluster2}" if debug

        clusters[cluster1].add(clusters[cluster2])
        clusters.delete_at(cluster2)

        if debug
          clusters.each_with_index do |elem, i|
            puts "cluster #{i}"
            elem.print
          end
        end

        # stop condition 3
        # the density of the biggest clusters exceeds the threshold
        if no_clusters == 0 && clusters[cluster].density > threshold_density
          break
        end
      end

      @clusters = clusters
    end

    ##
    # Makes an hierarchical clusterization until the most dense cluster is
    # obtained
    # or the distance between clusters is sufficintly big
    # or the desired number of clusters is obtained
    # Params:
    # +no_clusters+: stop test (number of clusters)
    # +distance_method+: distance method (method 0 or method 1)
    # +vec+: a vector of values (by default the values from initialization)
    # +debug+: display debug information
    # Output:
    # vector of +Cluster+ objects
    def hierarchical_clusterization(no_clusters = 0, distance_method = 0,
                                    vec = @values, debug = false)
      clusters = []
      vec = vec.sort

      if vec.length == 1
        hash = { vec[0] => 1 }
        cluster = Cluster.new(hash)
        clusters.push(cluster)
        clusters
      end

      # Thresholds
      threshold_distance = (0.25 * (vec.max - vec.min))
      threshold_density = (0.5 * vec.length).to_i

      # make a histogram from the input vector
      histogram = Hash[vec.group_by { |x| x }.map { |k, vs| [k, vs.length] }]

      # clusters = array of clusters
      # initially each length belongs to a different cluster
      histogram.sort { |a, b| a[0] <=> b[0] }.each do |elem|
        puts "len #{elem[0]} appears #{elem[1]} times" if debug
        hash = { elem[0] => elem[1] }
        cluster = Cluster.new(hash)
        clusters.push(cluster)
      end

      clusters.each(&:print) if debug

      return clusters if clusters.length == 1

      # each iteration merge the closest two adiacent cluster
      # the loop stops according to the stop conditions
      iteration = 0
      loop do
        # stop condition 1
        break if no_clusters != 0 && clusters.length == no_clusters

        iteration += 1
        puts "\nIteration #{iteration}" if debug

        min_distance = 100_000_000
        cluster      = 0
        density      = 0

        clusters[0..clusters.length - 2].each_with_index do |_item, i|
          dist = clusters[i].distance(clusters[i + 1], distance_method)
          puts "distance between clusters #{i} and #{i + 1} is #{dist}" if debug
          current_density = clusters[i].density + clusters[i + 1].density
          if dist < min_distance
            min_distance = dist
            cluster = i
            density = current_density
          elsif dist == min_distance && density < current_density
            cluster = i
            density = current_density
          end
        end

        # stop condition 2
        # the distance between the closest clusters exceeds the threshold
        if no_clusters == 0 && (clusters[cluster].mean - clusters[cluster + 1].mean).abs > threshold_distance
          break
        end

        # merge clusters 'cluster' and 'cluster'+1
        puts "clusters to merge #{cluster} and #{cluster + 1}" if debug

        clusters[cluster].add(clusters[cluster + 1])
        clusters.delete_at(cluster + 1)

        if debug
          clusters.each_with_index do |elem, i|
            puts "cluster #{i}"
            elem.print
          end
        end

        # stop condition 3
        # the density of the biggest clusters exceeds the threshold
        if no_clusters == 0 && clusters[cluster].density > threshold_density
          break
        end
      end

      @clusters = clusters
    end

    ##
    # Returns the cluster with the maimum density
    # Params:
    # +clusters+: list of +Clususter+ objects
    def most_dense_cluster(clusters = @clusters)
      max_density = 0
      max_density_cluster = 0

      nil if clusters.nil?

      clusters.each_with_index do |item, i|
        if item.density > max_density
          max_density = item.density
          max_density_cluster = i
        end
      end
      clusters[max_density_cluster]
    end
  end
end
