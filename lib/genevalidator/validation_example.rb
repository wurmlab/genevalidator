## This is an example on how to add another validation to GV
# 1. Update the TODOs in this file
# 2. Add the NameValidation to GeneValidator::Validate:create_validation_tests
#    (in genevalidator/validation.rb)
# 3. 

require 'forwardable'

require 'genevalidator/exceptions'
require 'genevalidator/validation_report'
require 'genevalidator/validation_test'

module GeneValidator
  ##
  # Class that stores the validation output information
  ## TODO: update the name of the output class - generally the name of these
  #  classes are named as follows: *ValidationOutput
  class NameValidationOutput < ValidationReport
    ## TODO: Add further arguments to the initialize method so that you can
    #  pass the necessary arguments from your validation class to this class.
    def initialize(short_header, header, description,
                   expected = :yes)
      @short_header, @header, @description = short_header, header, description
      @expected     = expected
      @result       = validation
      @approach     = 'TODO: The Approach'
      @explanation  = explain
      @conclusion   = conclude
    end

    def explain
      'TODO: The explanation'
    end

    def conclude
      if @result == :yes
        'TODO: The positive conclusion.'
      else
        'TODO: The negative conclusion.'
      end
    end

    def print
      "TODO: printed result of the validation"
    end

    def validation
      # TODO: Does the validation happend as expected.
      (true == true) ? :yes : :no
    end
  end

  ##
  # This class contains the methods necessary for
  # reading frame validation based on BLAST output
  class NameValidation < ValidationTest
    def initialize(type, prediction, hits = nil)
      super
      @short_header = 'QualityIndex'
      @header       = 'Quality Index'
      @description  = 'MAKER mRNA Quality Index'
      @cli_name     = 'maker_qi'
    end

    ##
    # Check reading frame inconsistency
    # Params:
    # +lst+: vector of +Sequence+ objects
    # Output:
    # +QIValidationOutput+ object
    def run
      fail unless prediction.is_a?(Query)

      start  = Time.now

      number = '\d*\.?\d*'
      match  = @prediction.definition.match(/QI:#{number}\|(#{number})\|
                                             (#{number})\|#{number}\|
                                             #{number}\|#{number}\|#{number}\|
                                             #{number}\|#{number}/x)

      fail NotEnoughEvidence if match.nil?

      # % of splice sites confirmed by EST/mRNA-seq alignment
      splice_sites = (match[1].to_f * 100).round
      # % of exons that match an EST/mRNA-seq alignment
      exons = (match[2].to_f * 100).round

      @validation_report = MakerQIValidationOutput.new(@short_header, @header,
                                                       @description,
                                                       splice_sites, exons)
      @validation_report.run_time = Time.now - start
      @validation_report

    rescue NotEnoughEvidence
      @validation_report =  ValidationReport.new('Not enough evidence',
                                                 :warning, @short_header,
                                                 @header, @description)
    rescue
      @validation_report = ValidationReport.new('Unexpected error', :error,
                                                @short_header, @header,
                                                @description)
      @validation_report.errors.push 'Unexpected Error'
    end
  end
end
