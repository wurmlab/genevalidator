require 'bio'
require 'forwardable'
require 'statsample'

require 'genevalidator/exceptions'
require 'genevalidator/ext/array'
require 'genevalidator/get_raw_sequences'
require 'genevalidator/validation_report'
require 'genevalidator/validation_test'

module GeneValidator
  ##
  # Class that stores the validation output information
  class DuplicationValidationOutput < ValidationReport
    attr_reader :pvalue
    attr_reader :average
    attr_reader :threshold
    attr_reader :result

    def initialize(short_header, header, description, pvalue, averages,
                   threshold = 0.05, expected = :yes)
      @short_header, @header, @description = short_header, header, description
      @pvalue      = pvalue
      @threshold   = threshold
      @result      = validation
      @expected    = expected
      @average     = averages.mean
      @approach    = 'We expect each BLAST hit to match each region of the' \
                     ' query at most once. Here, we calculate the' \
                     ' distribution of hit coverage against the query' \
                     ' sequence and use the Wilcoxon test to determine if it' \
                     ' is higher than 1.'
      @explanation = explain
      @conclusion  = conclude
    end

    def explain
      "The Wilcoxon test produced a p-value of #{prettify_evalue(@pvalue)}" \
      "#{@result == :no ? " (average = #{@average.round(2)})." : '.'}"
    end

    def conclude
      if @result == :yes
        'This suggests that the query sequence contains no erroneous' \
        ' duplications.'
      else
        'The null hypothesis is rejected - thus a region of the query' \
        ' sequence is likely repeated more than once.'
      end
    end

    def print
      @pvalue.round(2).to_s
    end

    def validation
      @pvalue > @threshold ? :yes : :no
    end

    def color
      validation == :yes ? 'success' : 'danger'
    end

    private

    # Copied from SequenceServer
    # Formats evalue (a float expressed in scientific notation) to "a x b^c".
    def prettify_evalue(evalue)
      evalue.to_s.sub(/(\d*\.\d*)e?([+-]\d*)?/) do
        s = format('%.3f', Regexp.last_match[1])
        s << " x 10<sup>#{Regexp.last_match[2]}</sup>" if Regexp.last_match[2]
        s
      end
    end
  end

  ##
  # This class contains the methods necessary for
  # finding duplicated subsequences in the predicted gene
  class DuplicationValidation < ValidationTest
    extend Forwardable
    def_delegators GeneValidator, :opt, :config

    attr_reader :raw_seq_file
    attr_reader :index_file_name
    attr_reader :raw_seq_file_load

    def initialize(prediction, hits)
      super
      @short_header      = 'Duplication'
      @header            = 'Duplication'
      @description       = 'Check whether there is a duplicated subsequence' \
                           ' in the predicted gene by counting the hsp' \
                           ' residue coverage of the prediction, for each hit.'
      @cli_name          = 'dup'
      @raw_seq_file      = opt[:raw_sequences]
      @index_file_name   = config[:raw_seq_file_index]
      @raw_seq_file_load = config[:raw_seq_file_load]
      @db                = opt[:db]
      @num_threads       = opt[:num_threads]
      @type              = config[:type]
    end

    ##
    # Check duplication in the first n hits
    # Output:
    # +DuplicationValidationOutput+ object
    def run(n = 10)
      raise NotEnoughHitsError if hits.length < opt[:min_blast_hits]
      raise unless prediction.is_a?(Query) && !prediction.raw_sequence.nil? &&
                   hits[0].is_a?(Query)

      start = Time.new
      # get the first n hits
      n_hits = [n - 1, @hits.length].min
      less_hits = @hits[0..n_hits]
      # get raw sequences for less_hits
      less_hits.delete_if do |hit|
        if hit.raw_sequence.nil?
          hit.raw_sequence = FetchRawSequences.run(hit.identifier,
                                                   hit.accession_no)
        end
        hit.raw_sequence.nil? ? true : false
      end

      raise NoInternetError if less_hits.length.zero?

      averages = []

      less_hits.each do |hit|
        coverage = Array.new(hit.length_protein, 0)
        # each residue of the protein should be evluated once only
        ranges_prediction = []

        hit.hsp_list.each do |hsp|
          # align subsequences from the hit and prediction that match
          if !hsp.hit_alignment.nil? && !hsp.query_alignment.nil?
            hit_alignment   = hsp.hit_alignment
            query_alignment = hsp.query_alignment
          else
            align = find_local_alignment(hit, prediction, hsp)
            hit_alignment   = align[0]
            query_alignment = align[1]
          end

          coverage = check_multiple_coverage(hit_alignment, query_alignment,
                                             hsp, coverage, ranges_prediction)

          ranges_prediction << (hsp.match_query_from..hsp.match_query_to)
        end
        overlap = coverage.reject(&:zero?)
        if overlap != []
          averages.push((overlap.inject(:+) / (overlap.length + 0.0)).round(2))
        end
      end

      # if all hsps match only one time
      if averages.reject { |x| x == 1 } == []
        @validation_report = DuplicationValidationOutput.new(@short_header,
                                                             @header,
                                                             @description, 1,
                                                             averages)
        @validation_report.run_time = Time.now - start
        return @validation_report
      end

      pval = wilcox_test(averages)

      @validation_report = DuplicationValidationOutput.new(@short_header,
                                                           @header,
                                                           @description, pval,
                                                           averages)
      @run_time = Time.now - start
      @validation_report

    rescue NotEnoughHitsError
      @validation_report = ValidationReport.new('Not enough evidence', :warning,
                                                @short_header, @header,
                                                @description)
    rescue NoMafftInstallationError
      @validation_report = ValidationReport.new('Mafft error', :error,
                                                @short_header, @header,
                                                @description)
      @validation_report.errors.push NoMafftInstallationError
    rescue NoInternetError
      @validation_report = ValidationReport.new('Internet error', :error,
                                                @short_header, @header,
                                                @description)
      @validation_report.errors.push NoInternetError
    rescue
      @validation_report = ValidationReport.new('Unexpected error', :error,
                                                @short_header, @header,
                                                @description)
      @validation_report.errors.push 'Unexpected Error'
    end

    # Only run if the BLAST output does not contain hit alignmment
    def find_local_alignment(hit, prediction, hsp)
      # indexing in blast starts from 1
      hit_local   = hit.raw_sequence[hsp.hit_from - 1..hsp.hit_to - 1]
      query_local = prediction.raw_sequence[hsp.match_query_from -
                                            1..hsp.match_query_to - 1]

      # in case of nucleotide prediction sequence translate into protein
      # use translate with reading frame 1 because
      # to/from coordinates of the hsp already correspond to the
      # reading frame in which the prediction was read to match this hsp
      if @type == :nucleotide
        s = Bio::Sequence::NA.new(query_local)
        query_local = s.translate
      end

      opt = ['--maxiterate', '1000', '--localpair', '--anysymbol', '--quiet']
      mafft = Bio::MAFFT.new('mafft', opt)

      # local alignment for hit and query
      seqs = [hit_local, query_local]
      report = mafft.query_align(seqs)
      report.alignment.map(&:to_s)
    rescue
      raise NoMafftInstallationError
    end

    def check_multiple_coverage(hit_alignment, query_alignment, hsp, coverage,
                                ranges_prediction)
      # for each hsp of the curent hit
      # iterate through the alignment and count the matching residues
      [*(0..hit_alignment.length - 1)].each do |i|
        residue_hit   = hit_alignment[i]
        residue_query = query_alignment[i]
        next if [' ', '+', '-'].include?(residue_hit)
        next if residue_hit != residue_query
        # indexing in blast starts from 1
        idx_hit   = i + (hsp.hit_from - 1) -
                    hit_alignment[0..i].scan(/-/).length
        idx_query = i + (hsp.match_query_from - 1) -
                    query_alignment[0..i].scan(/-/).length
        coverage[idx_hit] += 1 unless in_range?(ranges_prediction, idx_query)
      end
      coverage
    end

    def in_range?(ranges, idx)
      ranges.each { |range| return true if range.member?(idx) }
      false
    end

    ##
    # wilcox test implementation from statsample ruby gem
    # many thanks to Claudio for helping us with the implementation!
    def wilcox_test(averages)
      wilcox = Statsample::Test.wilcoxon_signed_rank(
        Daru::Vector.new(averages),
        Daru::Vector.new(Array.new(averages.length, 1))
      )

      averages.length < 15 ? wilcox.probability_exact : wilcox.probability_z
    end
  end
end
