require 'genevalidator/validation_length_cluster'
require 'genevalidator/validation_length_rank'
require 'genevalidator/validation_blast_reading_frame'
require 'genevalidator/validation_gene_merge'
require 'genevalidator/validation_duplication'
require 'genevalidator/validation_open_reading_frame'
require 'genevalidator/validation_alignment'
require 'genevalidator/exceptions'

##
# This is a facade class for gene validation

class Validation

  attr_reader :filename
  attr_reader :html_path
  attr_reader :yaml_path
  attr_reader :idx
  attr_reader :start_idx

  attr_reader :hits
  attr_reader :prediction
  attr_reader :type
  attr_reader :vlist

  ##
  # Initilizes the object
  # Params:
  # +prediction+: a +Sequence+ object representing the blast query
  # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
  # +vlist+: list of vlidations
  # +type+: type of the predicted sequence (:nucleotide or :protein)
  # +filename+: name of the input file, used when generatig the plot files
  # +idx+: index of the query currently processed (used to generate unique plot images)
  # +start_idx+: index of the first processed query (may differ from idx if the first queries are skiped)
  def initialize(prediction, hits, vlist, type, filename, html_path, yaml_path, idx, start_idx)

    @prediction = prediction
    @hits = hits
    @filename = filename
    @html_path = html_path
    @yaml_path = yaml_path
    @idx = idx
    @start_idx = start_idx
    @type = type
    @vlist = vlist

  end

  ##
  # Runs all validations 
  # Params:
  # Output:
  # +Output+ object
  def validate_all
    begin

      query_output = Output.new(@filename, @html_path, @yaml_path, @idx, @start_idx)
      query_output.prediction_len = prediction.xml_length
      query_output.prediction_def = prediction.definition
      query_output.nr_hits = hits.length
      
      plot_path = "#{html_path}/#{filename}_#{@idx}"

      validations = []
      validations.push LengthClusterValidation.new(@type, prediction, hits, plot_path)
      validations.push LengthRankValidation.new(@type, prediction, hits)
      validations.push BlastReadingFrameValidation.new(@type, prediction, hits)
      validations.push GeneMergeValidation.new(@type, prediction, hits, plot_path)
      validations.push DuplicationValidation.new(@type, prediction, hits)
      validations.push OpenReadingFrameValidation.new(@type, prediction, hits, plot_path, ["ATG"])
      validations.push AlignmentValidation.new(@type, prediction, hits, plot_path)

      # check the class type of the elements in the list
      validations.map do |v|
        raise ValidationClassError unless v.is_a? ValidationTest 
      end

      if vlist.map{|v| v.strip.downcase}.include? "all"
        validations.map{|v| v.run}
        # check the class type of the validation reports
        validations.each do |v|
          raise ReportClassError unless v.validation_report.is_a? ValidationReport
        end
        query_output.validations = validations
      else
        desired_validations = validations.select {|v| vlist.map{|vv| vv.strip.downcase}.include? v.cli_name.downcase }
        desired_validations.each do |v| 
            v.run
            raise ReportClassError unless v.validation_report.is_a? ValidationReport
        end
        query_output.validations = desired_validations
      end

      return query_output

    rescue ValidationClassError => error
      $stderr.print "Class Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: type of one of the validations is not ValidationTest"
      exit
    rescue ReportClassError => error
        $stderr.print "Class Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: type of one of the validation reports returned by the 'run' method is not ValidationReport"
      exit

    end
  end
end
