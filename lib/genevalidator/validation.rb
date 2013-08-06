require 'genevalidator/validation_length_cluster'
require 'genevalidator/validation_length_rank'
require 'genevalidator/validation_blast_reading_frame'
require 'genevalidator/validation_gene_merge'
require 'genevalidator/validation_duplication'
require 'genevalidator/validation_open_reading_frame'
require 'genevalidator/exceptions'

##
# This is a facade class for gene validation

class Validation

  attr_reader :filename
  attr_reader :idx
  attr_reader :start_idx

  attr_reader :hits
  attr_reader :prediction
  attr_reader :type

  ##
  # Initilizes the object
  # Params:
  # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
  # +prediction+: a +Sequence+ object representing the blast query
  # +type+: type of the predicted sequence (:nucleotide or :protein)
  # +filename+: name of the input file, used when generatig the plot files
  # +idx+: index of the query currently processed (used to generate unique plot images)
  # +start_idx+: index of the first processed query (may differ from idx if the first queries are skiped)
  def initialize(hits, prediction, type, filename, idx, start_idx)

    @hits = hits
    @prediction = prediction
    @filename = filename
    @idx = idx
    @start_idx = start_idx
    @type = type

  end

  ##
  # Runs all validations 
  # Params:
  # +plots+: boolean variable, indicated whether plots should be generated or not
  # Output:
  # +Output+ object
  def validate_all(plots = false)
    begin      
      query_output = Output.new(@filename, @idx, @start_idx)
      query_output.prediction_len = prediction.xml_length
      query_output.prediction_def = prediction.definition

      query_output.nr_hits = hits.length
      plot_filename = "#{@filename}_#{@idx}"

      query_output.length_validation_cluster = ValidationReport.new("Not enough evidence")
      query_output.length_validation_rank = ValidationReport.new("Not enough evidence")
      query_output.reading_frame_validation = ValidationReport.new("Not enough evidence")
      query_output.gene_merge_validation = ValidationReport.new("Not enough evidence")
      query_output.duplication  = ValidationReport.new("Not enough evidence")
      query_output.orf = ValidationReport.new("-")
=begin
      validations = []

      validations.push LengthClusterValidation.new(hits, prediction, plot_filename, plots)
      validations.push LengthRankValidation.new(hits, prediction)
      validations.push BlastReadingFrameValidation.new(hits, prediction)
      validations.push GeneMergeValidation.new(hits, prediction, plot_filename, plots)
      validations.push DuplicationValidation.new(hits, prediction)
      if @type == :nucleotide
#        OpenReadingFrameValidation.new(hits, prediction, plot_filename, plots, ["TAG", "TAA", "TGA"]).run
         validations.push OpenReadingFrameValidation.new(prediction, plot_filename, plots, ["ATG"])
      end  
      query_output.validations = validations.map{|v| v.run}
=end

      query_output.length_validation_cluster = LengthClusterValidation.new(hits, prediction, plot_filename, plots).run
      query_output.length_validation_rank = LengthRankValidation.new(hits, prediction).run
      query_output.reading_frame_validation = BlastReadingFrameValidation.new(hits, prediction).run
      query_output.gene_merge_validation = GeneMergeValidation.new(hits, prediction, plot_filename, plots).run
      query_output.duplication  = DuplicationValidation.new(hits, prediction).run

      if @type == :nucleotide
#        OpenReadingFrameValidation.new(hits, prediction, plot_filename, plots, ["TAG", "TAA", "TGA"]).run
         validations.push OpenReadingFrameValidation.new(prediction, plot_filename, plots, ["ATG"])
      end

      query_output

    # Exception is raised when blast founds no hits
    rescue QueryError => error
      if @type == :nucleotide
#        query_output.orf = OpenReadingFrameValidation.new(hits, prediction, plot_filename, plots, ["TAG", "TAA", "TGA"]).validation_test
         query_output.orf = OpenReadingFrameValidation.new(prediction, plot_filename, plots, ["ATG"]).validation_test
      end
      query_output
    end
  end

end
