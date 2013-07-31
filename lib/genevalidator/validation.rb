require 'genevalidator/validation_length_cluster'
require 'genevalidator/validation_length_rank'
require 'genevalidator/validation_blast_reading_frame'
require 'genevalidator/validation_gene_merge'
require 'genevalidator/validation_duplication'
require 'genevalidator/validation_open_reading_frame'

class QueryError < Exception
end

##
# This is a facade class for gene validation

class Validation

  attr_reader :fasta_file
  attr_reader :idx
  attr_reader :start_idx

  attr_reader :hits
  attr_reader :prediction
  attr_reader :type

  def initialize(hits, prediction, type, fasta_file, idx, start_idx)

    @hits = hits
    @prediction = prediction
    @fasta_file = fasta_file
    @idx = idx
    @start_idx = start_idx
    @type = type

  end

  ##
  # Runs all validations 
  # Params:
  # +command+: blast command in String format (e.g 'blastx' or 'blastp')
  # boolean variable that indicates wheter the plots are generated
  # Output:
  # String with the blast xml output
  def validate_all(plots = true)
    begin      
      query_output = Output.new(@fasta_file, @idx, @start_idx)
      query_output.prediction_len = prediction.xml_length
      query_output.prediction_def = prediction.definition

      query_output.nr_hits = hits.length
      filename = "#{@fasta_file}_#{@idx}"

      query_output.length_validation_cluster = ValidationOutput.new("Not enough evidence")
      query_output.length_validation_rank = ValidationOutput.new("Not enough evidence")
      query_output.reading_frame_validation = ValidationOutput.new("Not enough evidence")
      query_output.gene_merge_validation = ValidationOutput.new("Not enough evidence")
      query_output.duplication  = ValidationOutput.new("Not enough evidence")
      query_output.orf = ValidationOutput.new("-")

      query_output.length_validation_cluster = LengthClusterValidation.new(hits, prediction, filename).validation_test
      query_output.length_validation_rank = LengthRankValidation.new(hits, prediction).validation_test
      query_output.reading_frame_validation = BlastReadingFrameValidation.new(hits, prediction).validation_test
      query_output.gene_merge_validation = GeneMergeValidation.new(hits, prediction, filename).validation_test
      query_output.duplication  = DuplicationValidation.new(hits, prediction).validation_test

      if @type == :nucleotide
        query_output.orf = OpenReadingFrameValidation.new(hits, prediction).validation_test
      end

      query_output

    rescue QueryError => error
      if @type == :nucleotide
        query_output.orf = OpenReadingFrameValidation.new(hits, prediction).validation_test
      end
      query_output
    end
  end

end
