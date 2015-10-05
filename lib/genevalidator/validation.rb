require 'forwardable'

require 'genevalidator/blast'
require 'genevalidator/exceptions'
require 'genevalidator/output'
require 'genevalidator/pool'
require 'genevalidator/query'
require 'genevalidator/validation_length_cluster'
require 'genevalidator/validation_length_rank'
require 'genevalidator/validation_blast_reading_frame'
require 'genevalidator/validation_gene_merge'
require 'genevalidator/validation_duplication'
require 'genevalidator/validation_open_reading_frame'
require 'genevalidator/validation_alignment'

# Top level module / namespace.
module GeneValidator
  Pair1 = Struct.new(:x, :y)

  # Class that initalises a separate Validate.new() instance for each query.
  class Validations
    extend Forwardable
    def_delegators GeneValidator, :opt, :config, :query_idx
    def initialize
      @opt       = opt
      @config    = config
      @query_idx = query_idx
    end

    ##
    #
    def run_validations(iterator)
      p = Pool.new(@opt[:num_threads]) if @opt[:num_threads] > 1

      while @config[:idx] + 1 < @query_idx.length
        prediction = get_info_on_query_sequence
        @config[:idx] += 1

        blast_hits = parse_next_iteration(iterator, prediction)

        if blast_hits.nil?
          @config[:idx] -= 1
          break
        end

        if @opt[:num_threads] == 1
          (Validate.new).validate(prediction, blast_hits, @config[:idx])
        else
          p.schedule(prediction, blast_hits, @config[:idx]) do |pred, hits, idx|
            (Validate.new).validate(pred, hits, idx)
          end
        end
      end
    ensure
      p.shutdown if @opt[:num_threads] > 1
    end

    ##
    # get info about the query
    def get_info_on_query_sequence(input_file = @opt[:input_fasta_file],
                                        seq_type = @config[:type])
      start_offset = @query_idx[@config[:idx] + 1] - @query_idx[@config[:idx]]
      end_offset   = @query_idx[@config[:idx]]
      query        = IO.binread(input_file, start_offset, end_offset)
      parse_query  = query.scan(/>([^\n]*)\n([A-Za-z\n]*)/)[0]

      prediction                = Query.new
      prediction.definition     = parse_query[0].gsub("\n", '')
      prediction.identifier     = prediction.definition.gsub(/ .*/, '')
      prediction.type           = seq_type
      prediction.raw_sequence   = parse_query[1].gsub("\n", '')
      prediction.length_protein = prediction.raw_sequence.length
      prediction.length_protein /= 3 if seq_type == :nucleotide
      prediction
    end

    def parse_next_iteration(iterator, prediction)
      iterator.next if @config[:idx] < @config[:start_idx]
      if @opt[:blast_xml_file]
        BlastUtils.parse_next(iterator)
      elsif @opt[:blast_tabular_file]
        iterator.parse_next(prediction.identifier)
      end
    end
  end

  # Class that runs the validations (Instatiated for each query)
  class Validate
    extend Forwardable
    def_delegators GeneValidator, :opt, :config, :mutex_array, :overview,
                   :query_idx

    ##
    # Initilizes the object
    # Params:
    # +opt+: A hash with the following keys: validations:, blast_tabular_file:,
    # blast_tabular_options:, blast_xml_file:, db:, raw_sequences:,
    # num_threads:, fast:}
    # +start_idx+: number of the sequence from the file to start with
    # +overall_evaluation+: boolean variable for printing overall evaluation
    def initialize
      @opt         = opt
      @config      = config
      @mutex_array = mutex_array
      @run_output  = nil
      @overview    = overview
      @query_idx   = query_idx
    end

    ##
    # Validate one query and create validation report
    # Params:
    # +prediction+: Sequence object
    # +hits+: Array of +Sequence+ objects
    # +current_idx+: the index number of the query
    def validate(prediction, hits, current_idx)
      hits = remove_identical_hits(prediction, hits)
      vals = create_validation_tests(prediction, hits)
      check_validations(vals)
      vals.each(&:run)
      @run_output = Output.new(current_idx, hits.length, prediction.definition)
      @run_output.validations = vals.map(&:validation_report)
      check_validations_output(vals)

      compute_scores
      generate_run_output
    end

    ##
    # Removes identical hits (100% coverage and >99% identity)
    # Params:
    # +prediction+: Sequence object
    # +hits+: Array of +Sequence+ objects
    # Output:
    # new array of hit +Sequence+ objects
    def remove_identical_hits(prediction, hits)
      identical_hits = []
      hits.each do |hit|
        low_identity = hit.hsp_list.select { |hsp| hsp.pidentity < 99 }
        no_data      = hit.hsp_list.select { |hsp| hsp.pidentity.nil? }
        low_identity += no_data
        # check the coverage
        coverage = Array.new(prediction.length_protein, 0)
        hit.hsp_list.each do |hsp|
          match_to   = hsp.match_query_to
          match_from = hsp.match_query_from
          len        = match_to - match_from + 1
          coverage[match_from - 1..match_to - 1] = Array.new(len, 1)
        end

        if low_identity.length == 0 && coverage.uniq.length == 1
          identical_hits.push(hit)
        end
      end

      identical_hits.each { |hit| hits.delete(hit) }
      hits
    end

    def create_validation_tests(prediction, hits)
      val = []
      val.push LengthClusterValidation.new(prediction, hits)
      val.push LengthRankValidation.new(prediction, hits)
      val.push GeneMergeValidation.new(prediction, hits)
      val.push DuplicationValidation.new(prediction, hits)
      init_nucleotide_only_validations(val, prediction, hits)
      val.push AlignmentValidation.new(prediction, hits)
      val.select { |v| @opt[:validations].include? v.cli_name.downcase }
    end

    def init_nucleotide_only_validations(val, prediction, hits)
      return unless @config[:type] == :nucleotide
      val.push BlastReadingFrameValidation.new(prediction, hits)
      val.push OpenReadingFrameValidation.new(prediction, hits)
    end

    def check_validations(vals)
      # check the class type of the elements in the list
      vals.each { |v| fail ValidationClassError unless v.is_a? ValidationTest }
      # check alias duplication
      aliases = vals.map(&:cli_name)
      fail AliasDuplicationError unless aliases.length == aliases.uniq.length
    rescue ValidationClassError => e
      $stderr.puts e
      exit 1
    rescue AliasDuplicationError => e
      $stderr.puts e
      exit 1
    end

    def check_validations_output(vals)
      fail NoValidationError if @run_output.validations.length == 0
      vals.each do |v|
        fail ReportClassError unless v.validation_report.is_a? ValidationReport
      end
    rescue NoValidationError => e
      $stderr.puts e
      exit 1
    rescue ReportClassError => e
      $stderr.puts e
      exit 1
    end

    def compute_scores
      validations        = @run_output.validations
      scores             = {}
      scores[:successes] = validations.count { |v| v.result == v.expected }
      scores[:fails] = validations.count { |v| v.validation != :unapplicable && v.validation != :error && v.result != v.expected }
      scores         = length_validation_scores(validations, scores)

      @run_output.successes     = scores[:successes]
      @run_output.fails         = scores[:fails]
      total_query               = scores[:successes].to_i + scores[:fails]
      if total_query == 0
        @run_output.overall_score = 0
      else
        @run_output.overall_score = (scores[:successes] * 90 / total_query).round
      end
    end

    # Since there are two length validations, it is necessary to adjust the
    #   scores accordingly
    def length_validation_scores(validations, scores)
      lcv = validations.select { |v| v.class == LengthClusterValidationOutput }
      lrv = validations.select { |v| v.class == LengthRankValidationOutput }
      if lcv.length == 1 && lrv.length == 1
        score_lcv = (lcv[0].result == lcv[0].expected)
        score_lrv = (lrv[0].result == lrv[0].expected)
        if score_lcv == true && score_lrv == true
          scores[:successes] -= 1 # if both are true: counted as 1 success
        elsif score_lcv == false && score_lrv == false
          scores[:fails] -= 1 # if both are false: counted as 1 fail
        else
          scores[:successes] -= 0.5
          scores[:fails] -= 0.5
        end
      end
      scores
    end

    def generate_run_output
      @run_output.generate_html
      @run_output.generate_json
      @run_output.print_output_console
      generate_run_overview
    end

    def generate_run_overview
      vals        = @run_output.validations
      no_mafft    = 0
      no_internet = 0
      errors      = []
      vals.each do |v|
        unless v.errors.nil?
          no_mafft += v.errors.count { |e| e == NoMafftInstallationError }
          no_internet += v.errors.count { |e| e == NoInternetError }
        end
        errors.push(v.short_header) if v.validation == :error
      end

      no_evidence = vals.count { |v| v.result == :unapplicable || v.result == :warning } == vals.length
      nee = (no_evidence) ? 1 : 0

      good_scores = (@run_output.overall_score >= 75) ? 1 : 0
      bad_scores  = (@run_output.overall_score >= 75) ? 0 : 1

      @mutex_array.synchronize do
        @overview[:no_queries] += 1
        @overview[:scores].push(@run_output.overall_score)
        @overview[:good_scores] += good_scores
        @overview[:bad_scores] += bad_scores
        @overview[:nee] += nee
        @overview[:no_mafft] += no_mafft
        @overview[:no_internet] += no_internet
        errors.each { |err| @overview[:map_errors][err] += 1 }

        vals.each do |v|
          next if v.run_time == 0 || v.run_time.nil?
          next if v.validation == :unapplicable || v.validation == :error
          p = Pair1.new(@overview[:run_time][v.short_header].x + v.run_time,
                        @overview[:run_time][v.short_header].y + 1)
          @overview[:run_time][v.short_header] = p
        end
      end
    end
  end
end
