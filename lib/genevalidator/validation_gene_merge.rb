require 'json'
require 'genevalidator/validation_report'

##
# Class that stores the validation output information
class GeneMergeValidationOutput < ValidationReport

  attr_reader :slope
  attr_reader :threshold_down
  attr_reader :threshold_up

  def initialize (slope, threshold_down = 0.4, threshold_up = 1.2, expected = :no)

    @short_header = "Gene_Merge(slope)"
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
    @short_header = "Gene_Merge(slope)"
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

      lm_slope = slope[1]
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

      colors   = ["orange", "blue"]
      f        = File.open(output , "w")
      no_lines = 120

      hits_less = hits[0..[no_lines, hits.length-1].min]

      f.write((hits_less.each_with_index.map{|hit, i| hit.hsp_list.map{|hsp| 
              {"y"=>i, "start"=>hsp.match_query_from, "stop"=>hsp.match_query_to, "color"=>"#{colors[i%2]}"}}}.flatten).to_json)
      f.close
      return Plot.new(output.scan(/\/([^\/]+)$/)[0][0], 
                       :lines,  
                       "[Gene Merge] Matched regions in the prediction", 
                       "prediction high-scoring alignmet seq, red; prediction high-scoring alignmet seq, orange", 
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
    f = File.open(output , "w")
    f.write(hits.map{|hit| {"x"=>hit.hsp_list.map{|hsp| hsp.match_query_from}.min, 
                             "y"=>hit.hsp_list.map{|hsp| hsp.match_query_to}.max}}.to_json)
    f.close
    return Plot.new(output.scan(/\/([^\/]+)$/)[0][0],
                                :scatter,
                                "[Gene Merge] Start/end of the high-scoring segments in prediction",
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
  # Code inspired from: http://engineering.sharethrough.com/blog/2012/09/12/simple-linear-regression-using-ruby/
  # Output:
  # The ecuation of the regression line: [y slope]
  def slope(hits = @hits)
    
    pairs = @hits.map {|hit| Pair.new(hit.hsp_list.map{|hsp| hsp.match_query_from}.min, hit.hsp_list.map{|hsp| hsp.match_query_to}.max)}

    xx = pairs.map{|pair| pair.x}
    yy = pairs.map{|pair| pair.y}

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
