require 'forwardable'

require 'genevalidator/clusterization'
require 'genevalidator/exceptions'
require 'genevalidator/validation_report'
require 'genevalidator/validation_test'

module GeneValidator
  ##
  # Class that stores the validation output information
  class LengthClusterValidationOutput < ValidationReport
    attr_reader :query_length
    attr_reader :limits
    attr_reader :result

    def initialize(short_header, header, description, query_length, limits,
                   expected = :yes)
      @short_header, @header, @description = short_header, header, description
      @limits       = limits
      @query_length = query_length
      @expected     = expected
      @result       = validation
      @plot_files   = []
      @approach     = 'If the query sequence is well conserved and similar' \
                      ' sequences (BLAST hits) are correct, we can expect' \
                      ' query and hit sequences to have similar lengths.' \
                      ' Here, we cluster the lengths of hit sequences and' \
                      ' compare the length of our query sequence to the most' \
                      ' dense cluster of hit lengths. '
      @explanation  = explain
      @conclusion   = conclude
    end

    def explain
      diff = (@result == :yes) ? 'inside' : 'outside'
      'The most dense length-cluster of BLAST hits includes' \
      " sequences that are from #{@limits[0]} to #{@limits[1]} amino-acids" \
      " long. The query sequence is #{@query_length} amino-acids long and" \
      " is thus #{diff} the most dense length-cluster of BLAST hits."
    end

    def conclude
      if @result == :yes # i.e. if inside the main cluster
        'There is no reason to believe there is any problem with the length' \
        ' of the query sequence.'
      else
        size_diff  = (@query_length > @limits[1]) ? 'long' : 'short'
        "This suggests that the query sequence may be too #{size_diff}."
      end
    end

    def print
      "#{@query_length}&nbsp;#{@limits.to_s.gsub(' ', '&nbsp;')}"
    end

    def validation
      return if @limits.nil?
      if @query_length >= @limits[0] && @query_length <= @limits[1]
        :yes
      else
        :no
      end
    end
  end

  ##
  # This class contains the methods necessary for
  # length validation by hit length clusterization
  class LengthClusterValidation < ValidationTest
    attr_reader :clusters
    attr_reader :max_density_cluster

    ##
    # Initilizes the object
    # Params:
    # +type+: type of the predicted sequence (:nucleotide or :protein)
    # +prediction+: a +Sequence+ object representing the blast query
    # +hits+: a vector of +Sequence+ objects (representing blast hits)
    # +dilename+: +String+ with the name of the fasta file
    def initialize(prediction, hits)
      super
      @short_header = 'LengthCluster'
      @header       = 'Length Cluster'
      @description  = 'Check whether the prediction length fits most of the' \
                      ' BLAST hit lengths, by 1D hierarchical clusterization.' \
                      ' Meaning of the output displayed: Query_length' \
                      ' [Main Cluster Length Interval]'
      @cli_name     = 'lenc'
    end

    ##
    # Validates the length of the predicted gene by comparing the length
    # of the prediction to the most dense cluster
    # The most dense cluster is obtained by hierarchical clusterization
    # Plots are generated if required (see +plot+ variable)
    # Output:
    # +LengthClusterValidationOutput+ object
    def run
      fail NotEnoughHitsError unless hits.length >= 5
      fail Exception unless prediction.is_a?(Query) && hits[0].is_a?(Query)

      start = Time.now
      # get [clusters, max_density_cluster_idx]
      clusterization = clusterization_by_length

      @clusters = clusterization[0]
      @max_density_cluster = clusterization[1]
      limits = @clusters[@max_density_cluster].get_limits
      query_length = @prediction.length_protein

      @validation_report = LengthClusterValidationOutput.new(@short_header,
                                                             @header,
                                                             @description,
                                                             query_length,
                                                             limits)
      plot1 = plot_histo_clusters
      @validation_report.plot_files.push(plot1)

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
    # Clusterization by length from a list of sequences
    # Params:
    # +debug+ (optional):: true to display debug information, false by default
    # +lst+:: array of +Query+ objects
    # +predicted_seq+:: +Query+ objetc
    # Output
    # output 1:: array of Cluster objects
    # output 2:: the index of the most dense cluster
    def clusterization_by_length(_debug = false,
                                 lst = @hits,
                                 predicted_seq = @prediction)
      fail TypeError unless lst[0].is_a?(Query) && predicted_seq.is_a?(Query)

      contents = lst.map { |x| x.length_protein.to_i }.sort { |a, b| a <=> b }

      hc = HierarchicalClusterization.new(contents)
      clusters = hc.hierarchical_clusterization

      max_density             = 0
      max_density_cluster_idx = 0
      clusters.each_with_index do |item, i|
        next unless item.density > max_density
        max_density             = item.density
        max_density_cluster_idx = i
      end

      [clusters, max_density_cluster_idx]

    rescue TypeError => error
      error_location = error.backtrace[0].scan(%r{([^/]+:\d+):.*})[0][0]
      $stderr.puts "Type error at #{error_location}."
      $stderr.puts ' Possible cause: one of the arguments of the' \
                   ' "clusterization_by_length" method has not the proper type.'
      exit 1
    end

    ##
    # Generates a json file containing data used for plotting the histogram
    # of the length distribution given a lust of Cluster objects
    # +output+: plot_path where to save the graph
    # +clusters+: array of +Cluster+ objects
    # +max_density_cluster+: index of the most dense cluster
    # +prediction+: +Sequence+ object
    # Output:
    # +Plot+ object
    def plot_histo_clusters(output = "#{@plot_path}_len_clusters.json",
                          clusters = @clusters,
                          max_density_cluster = @max_density_cluster,
                          prediction = @prediction)

      data = clusters.each_with_index.map { |cluster, i|
        cluster.lengths.collect { |k, v|
          { 'key' => k, 'value' => v, 'main' => (i == max_density_cluster) }
        }
      }

      Plot.new(data,
               :bars,
               'Length Cluster Validation: Distribution of BLAST hit lengths',
               'Query Sequence, black;Most Dense Cluster,red;Other Hits, blue',
               'Sequence Length',
               'Number of Sequences',
               prediction.length_protein)
    end
  end
end
