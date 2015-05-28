require 'genevalidator/validation_length_cluster'
require 'genevalidator/validation_length_rank'
require 'genevalidator/validation_blast_reading_frame'
require 'genevalidator/validation_gene_merge'
require 'genevalidator/validation_duplication'
require 'genevalidator/validation_open_reading_frame'
require 'genevalidator/validation_alignment'
require 'genevalidator/pool'
require 'genevalidator/output'
require 'genevalidator/exceptions'


# Top level module / namespace.
module GeneValidator
  Pair1 = Struct.new(:x, :y)
  # Main Class that initalises and then runs validations.
  class Validation
    extend Forwardable
    def_delegators GeneValidator, :opt, :config, :query_offset_lst, :mutex_array
    # global variables
    attr_reader :no_queries
    attr_reader :scores
    attr_reader :good_predictions
    attr_reader :bad_predictions
    attr_reader :nee
    attr_reader :no_mafft
    attr_reader :no_internet
    attr_reader :map_errors
    attr_reader :map_running_times

    ##
    # Initilizes the object
    # Params:
    # +opt+: A hash with the following keys: validations:, blast_tabular_file:,
    # blast_tabular_options:, blast_xml_file:, db:, raw_sequences:,
    # num_threads:, fast:}
    # +start_idx+: number of the sequence from the file to start with
    # +overall_evaluation+: boolean variable for printing overall evaluation
    def initialize
      @opt               = opt
      @config            = config
      @query_offset_lst  = query_offset_lst
      @mutex_array       = mutex_array
      # global variables
      @no_queries        = 0
      @scores            = []
      @good_predictions  = 0
      @bad_predictions   = 0
      @nee               = 0
      @no_mafft          = 0
      @no_internet       = 0
      @map_errors        = Hash.new(0)
      @map_running_times = Hash.new(Pair1.new(0, 0))
      @config[:run_no]   = 0 # required in Output.print_output_console
    end

    ##
    #
    def run_validations(iterator)
      p = Pool.new(@opt[:num_threads]) if @opt[:num_threads] > 1

      while @config[:idx] + 1 < @query_offset_lst.length
        prediction = get_info_on_query_sequence
        @config[:idx] += 1

        hits = parse_next_iteration(iterator, prediction)

        if hits.nil?
          @config[:idx] -= 1
          break
        end
        current_idx = @config[:idx]

        if @opt[:num_threads] == 1
          validate(prediction, hits, current_idx)
        else
          p.schedule(prediction, hits, current_idx) do |prediction, hits, idx|
            validate(prediction, hits, idx)
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
      prediction   = Sequence.new
      idx          = @config[:idx]
      start_offset = @query_offset_lst[idx + 1] - @query_offset_lst[idx]
      end_offset   = @query_offset_lst[idx]
      query        = IO.binread(input_file, start_offset, end_offset)
      parse_query  = query.scan(/>([^\n]*)\n([A-Za-z\n]*)/)[0]

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

    ##
    # Validate one query and create validation report
    # Params:
    # +prediction+: Sequence object
    # +hits+: Array of +Sequence+ objects
    # +current_idx+: the index number of the query
    def validate(prediction, hits, current_idx)
      query_output = do_validations(prediction, hits, current_idx)
      query_output.generate_html
      query_output.print_output_file_yaml
      query_output.print_output_console

      validations = query_output.validations

      no_mafft = 0
      no_internet = 0
      errors = []
      validations.each do |v|
        unless v.errors.nil?
          no_mafft += v.errors.select { |e| e == NoMafftInstallationError }.length
          no_internet += v.errors.select { |e| e == NoInternetError }.length
        end
        errors.push(v.short_header) if v.validation == :error
      end

      no_evidence = validations.count { |v| v.result == :unapplicable || v.result == :warning } == validations.length
      nee = (no_evidence) ? 1 : 0

      good_predictions = (query_output.overall_score >= 75) ? 1 : 0
      bad_predictions  = (query_output.overall_score >= 75) ? 0 : 1

      @mutex_array.synchronize do
        @no_queries += 1
        @scores.push(query_output.overall_score)
        @good_predictions += good_predictions
        @bad_predictions += bad_predictions
        @nee += nee
        @no_mafft += no_mafft
        @no_internet += no_internet
        errors.each { |err| @map_errors[err] += 1 }

        validations.each do |v|
          next if v.running_time == 0 || v.running_time.nil?
          next if v.validation == :unapplicable || v.validation == :error
          p = Pair1.new(@map_running_times[v.short_header].x + v.running_time, @map_running_times[v.short_header].y + 1)
          @map_running_times[v.short_header] = p
        end
      end
      query_output
    end

    ##
    # Removes identical hits
    # Params:
    # +prediction+: Sequence object
    # +hits+: Array of +Sequence+ objects
    # Output:
    # new array of hit +Sequence+ objects
    def remove_identical_hits(prediction, hits)
      # remove the identical hits
      # identical hit means 100%coverage and >99% identity
      identical_hits = []
      hits.each do |hit|
        # check if all hsps have identity more than 99%
        low_identity = hit.hsp_list.select { |hsp| hsp.pidentity.nil? || hsp.pidentity < 99 }

        # check the coverage
        coverage = Array.new(prediction.length_protein, 0)
        hit.hsp_list.each do |hsp|
          len = hsp.match_query_to - hsp.match_query_from + 1
          coverage[hsp.match_query_from - 1..hsp.match_query_to - 1] = Array.new(len, 1)
        end

        if low_identity.length == 0 && coverage.uniq.length == 1
          identical_hits.push(hit)
        end
      end

      identical_hits.each { |hit| hits.delete(hit) }
      hits
    end

    ##
    # Runs all the validations and prints the outputs given the current
    # prediction query and the corresponding hits
    # Params:
    # +prediction+: Sequence object
    # +hits+: Array of +Sequence+ objects
    # +idx+: the index number of the query
    # Output:
    # +Output+ object
    def do_validations(prediction, hits, idx)
      begin
        hits = remove_identical_hits(prediction, hits)
        rescue Exception => error # NoPIdentError
      end

      query_output                = Output.new(idx)
      query_output.prediction_len = prediction.length_protein
      query_output.prediction_def = prediction.definition
      query_output.nr_hits        = hits.length

      plot_path                   = File.join(@config[:plot_dir],
                                              "#{@config[:filename]}_#{idx}")

      val = []
      val.push LengthClusterValidation.new(prediction, hits, plot_path)
      val.push LengthRankValidation.new(prediction, hits)
      val.push GeneMergeValidation.new(prediction, hits, plot_path)
      val.push DuplicationValidation.new(prediction, hits)
      val.push BlastReadingFrameValidation.new(prediction, hits)
      val.push OpenReadingFrameValidation.new(prediction, hits, plot_path)
      val.push AlignmentValidation.new(prediction, hits, plot_path)

      val = val.select { |v| @opt[:validations].include? v.cli_name.downcase }
      # check the class type of the elements in the list
      val.each do |v|
        fail ValidationClassError unless v.is_a? ValidationTest
      end

      # check alias duplication
      aliases = val.map(&:cli_name)
      fail AliasDuplicationError unless aliases.length == aliases.uniq.length

      val.each do |v|
        v.run
        fail ReportClassError unless v.validation_report.is_a? ValidationReport
      end
      query_output.validations = val.map(&:validation_report)

      fail NoValidationError if query_output.validations.length == 0

      # compute validation score
      compute_scores(query_output)
      query_output

    rescue ValidationClassError => error
      error_line = error.backtrace[0].scan(%r{/([^/]+:\d+):.*})[0][0]
      $stderr.print "Class Type error at #{error_line}." \
                    ' Possible cause: type of one of the validations is not' \
                    " ValidationTest\n"
      exit 1
    rescue NoValidationError => error
      error_line = error.backtrace[0].scan(%r{/([^/]+:\d+):.*})[0][0]
      $stderr.print "Validation error at #{error_line}." \
                    " Possible cause: your -v arguments are not valid aliases\n"
      exit 1
    rescue ReportClassError => error
      error_line = error.backtrace[0].scan(%r{/([^/]+:\d+):.*})[0][0]
      $stderr.print "Class Type error at #{error_line}."\
                    ' Possible cause: type of one of the validation reports' \
                    " returned by the 'run' method is not ValidationReport\n"
      exit 1
    rescue AliasDuplicationError => error
      error_line = error.backtrace[0].scan(%r{/([^/]+:\d+):.*})[0][0]
      $stderr.print "Alias Duplication error at #{error_line}."\
                    ' Possible cause: At least two validations have the same' \
                    " CLI alias\n"
      exit 1
    end

    def compute_scores(query_output)
      validations = query_output.validations
      successes = validations.map { |v| v.result == v.expected }.count(true)
      fails = validations.map { |v| v.validation != :unapplicable &&
                                    v.validation != :error &&
                                    v.result != v.expected }.count(true)

      lcv = validations.select { |v| v.class == LengthClusterValidationOutput }
      lrv = validations.select { |v| v.class == LengthRankValidationOutput }
      if lcv.length == 1 && lrv.length == 1
        score_lcv = (lcv[0].result == lcv[0].expected)
        score_lrv = (lrv[0].result == lrv[0].expected)
        # if both are true this should be counted as a single success
        if score_lcv == true && score_lrv == true
          successes -= 1
        elsif score_lcv == false && score_lrv == false
          # if both are false this will be a fail
          fails -= 1
        else
          successes -= 0.5
          fails -= 0.5
        end
      end

      query_output.successes     = successes
      query_output.fails         = fails
      total_query                = successes.to_i + fails
      query_output.overall_score = (successes * 100 / (total_query)).round(0)
    end
  end
end
