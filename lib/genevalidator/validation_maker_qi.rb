require 'forwardable'

require 'genevalidator/exceptions'
require 'genevalidator/validation_report'
require 'genevalidator/validation_test'

module GeneValidator
  ##
  # Class that stores the validation output information
  class MakerQIValidationOutput < ValidationReport
    def initialize(short_header, header, description, splice_sites, exons,
                   expected = :yes)
      @short_header, @header, @description = short_header, header, description
      @splice_sites = splice_sites
      @exons        = exons
      @expected     = expected
      @result       = validation
      @approach     = 'We obtain the fraction of splice sites and exons' \
                      ' confirmed by EST/RNASeq alignment from the FASTA' \
                      ' defline for MAKER predicted gene models. RNASeq is' \
                      ' often best evidence to ascertain the quality of gene' \
                      ' models'
      @explanation  = explain
      @conclusion   = conclude
    end

    def explain
      "#{@exons}% of exons match an EST/mRNA-seq alignment and" \
      " #{@splice_sites}% of splice sites are confirmed by EST/mRNA-seq" \
      " alignment."
    end

    def conclude
      if @result == :yes
        'More than 80% of this gene is confirmed by RNASeq evidence.' \
        'Thus, the MAKER Quality Index suggests that the query sequence is of' \
        ' a good quality.'
      else
        'Less than 80% of this gene is confirmed by RNASeq evidence.' \
        'Thus, the MAKER Quality Index suggests that there may be some issues'\
        ' with the query seqeunce.'
      end
    end

    def print
      "Exons:&nbsp;#{@exons}%;" \
      " Splice&nbsp;Sites:&nbsp;#{@splice_sites}%"
    end

    def validation
      (@splice_sites > 80 && @exons > 80) ? :yes : :no
    end
  end

  ##
  # This class contains the methods necessary for
  # reading frame validation based on BLAST output
  class MakerQIValidation < ValidationTest
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

    rescue NotEnoughHitsError
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
