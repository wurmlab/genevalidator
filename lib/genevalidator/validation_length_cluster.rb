require 'json'
require 'genevalidator/clusterization'
require 'genevalidator/validation_report'
require 'genevalidator/validation_test'
require 'genevalidator/exceptions'

##
# Class that stores the validation output information
class LengthClusterValidationOutput < ValidationReport

  attr_reader :prediction_len
  attr_reader :limits

  def initialize (prediction_len, limits, expected = :yes)

    @short_header = "LengthCluster"
    @header = "Length Cluster"
    @description = "Check whether the prediction length fits most of the BLAST hit lengths,"<<
      " by 1D hierarchical clusterization. Meaning of the output displayed: Prediction_len"<<
      " [Main Cluster Length Interval]"

    @limits = limits
    @prediction_len = prediction_len
    @expected = expected
    @result = validation
    @plot_files = []
  end

  def print
    "#{@prediction_len} #{@limits.to_s}"
  end

  def validation
    if @limits != nil
      if @prediction_len >= @limits[0] and @prediction_len <= @limits[1]
        :yes
      else
        :no
      end
    end    
  end
end

##
# This class contains the methods necessary for 
# length validation by hit length clusterization
class LengthClusterValidation < ValidationTest

  attr_reader :filename
  attr_reader :clusters
  attr_reader :max_density_cluster

  ##
  # Initilizes the object
  # Params:
  # +type+: type of the predicted sequence (:nucleotide or :protein)
  # +prediction+: a +Sequence+ object representing the blast query
  # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
  def initialize(type, prediction, hits, filename)
    super
    @filename = filename
    @short_header = "LengthCluster"
    @header = "Length Cluster"
    @description = "Check whether the prediction length fits most of the BLAST hit lengths,"<<
      " by 1D hierarchical clusterization. Meaning of the output displayed: Prediction_len"<<
      " [Main Cluster Length Interval]"
    @cli_name = "lenc" 
  end


  ## 
  # Validates the length of the predicted gene by comparing the length 
  # of the prediction to the most dense cluster
  # The most dense cluster is obtained by hierarchical clusterization
  # Plots are generated if required (see +plot+ variable)
  # Output:
  # +LengthClusterValidationOutput+ object
  def run
    begin
      raise NotEnoughHitsError unless hits.length >= 5
      raise Exception unless prediction.is_a? Sequence and 
                             hits[0].is_a? Sequence 

      start = Time.now
      # get [clusters, max_density_cluster_idx]
      clusterization = clusterization_by_length 

      @clusters = clusterization[0]
      @max_density_cluster = clusterization[1]
      limits = @clusters[@max_density_cluster].get_limits
      prediction_len = @prediction.length_protein

      @validation_report = LengthClusterValidationOutput.new(prediction_len, limits)
      plot1 = plot_histo_clusters
      @validation_report.plot_files.push(plot1)
      plot2 = plot_len_clusters
      @validation_report.plot_files.push(plot2)
      @validation_report.running_time = Time.now - start

      return @validation_report

    # Exception is raised when blast founds no hits
    rescue  NotEnoughHitsError => error
      @validation_report = ValidationReport.new("Not enough evidence", :warning, @short_header, @header, @description)
      return @validation_report
    else 
      @validation_report = ValidationReport.new("Unexpected error", :error, @short_header, @header, @description)
      @validation_report.errors.push OtherError
      return @validation_report
    end       
  end


  ##
  # Clusterization by length from a list of sequences
  # Params:
  # +debug+ (optional):: true to display debug information, false by default (optional argument)
  # +lst+:: array of +Sequence+ objects
  # +predicted_seq+:: +Sequence+ objetc
  # Output
  # output 1:: array of Cluster objects
  # output 2:: the index of the most dense cluster
  def clusterization_by_length(debug = false, 
                               lst = @hits, 
                               predicted_seq = @prediction)
    begin
      raise TypeError unless lst[0].is_a? Sequence and 
                             predicted_seq.is_a? Sequence

      contents = lst.map{ |x| x.length_protein.to_i }.sort{|a,b| a<=>b}

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
      $stderr.print "Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}."<<
       " Possible cause: one of the arguments of 'clusterization_by_length'"<<
       " method has not the proper type.\n"
      exit
    end
  end

  ##
  # Generates a json file containing data used for plotting the histogram
  # of the length distribution given a lust of Cluster objects
  # +output+: filename where to save the graph
  # +clusters+: array of +Cluster+ objects
  # +max_density_cluster+: index of the most dense cluster
  # +prediction+: +Sequence+ object
  # Output:
  # +Plot+ object
  def plot_histo_clusters(output = "#{@filename}_len_clusters.json", 
                        clusters = @clusters, 
                        max_density_cluster = @max_density_cluster,
                        prediction = @prediction)

      f = File.open(output, "w")
      f.write(clusters.each_with_index.map{|cluster, i| 
        cluster.lengths.collect{|k,v| 
          {"key"=>k, "value"=>v, "main"=>(i==max_density_cluster)}
        }}.to_json)
      f.close
      Plot.new(output.scan(/\/([^\/]+)$/)[0][0], 
              :bars,
              "[Length Validation] Distribution of the lengths of the hits",
              "query, black;most dense cluster,red;other hits, blue",
              "sequence length",
              "number of sequences",
              prediction.length_protein)
  end

  ##
  # Generates a json file cotaining data used for plotting
  # lines corresponding to the start and end hit offsets
  # Params:
  # +output+: filename where to save the graph
  # +hits+: array of Sequence objects
  # Output:
  # +Plot+ object
  def plot_len_clusters(output = "#{@filename}_len.json", hits = @hits)

      f = File.open(output , "w")
      lst = @hits.sort{|a,b| a.length_protein<=>b.length_protein}

      no_lines = 100

      lst_less = lst[0..[no_lines, lst.length-1].min]

      f.write((lst_less.each_with_index.map{|hit, i| {"y"=>i, "start"=>0, "stop"=>hit.length_protein, "color"=>"gray"}} +
               lst_less.each_with_index.map{|hit, i| hit.hsp_list.map{|hsp| {"y"=>i, "start"=>hsp.hit_from, "stop"=>hsp.hit_to, "color"=>"red"}}}.flatten).to_json)

      f.close
      Plot.new(output.scan(/\/([^\/]+)$/)[0][0],
               :lines,
               "[Length Validation] Matched regions in hits",
               "hit, gray;high-scoring segment pairs (hsp), red",
               "offset in the hit",
               "number of the hit",
               lst_less.length)
  end
end
