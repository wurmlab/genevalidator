require 'forwardable'
require 'json'

module GeneValidator
  class Output
    extend Forwardable
    def_delegators GeneValidator, :opt, :config, :dirs, :mutex
    attr_accessor :prediction_def
    attr_accessor :nr_hits

    # list of +ValidationReport+ objects
    attr_accessor :validations

    attr_accessor :idx

    attr_accessor :overall_score
    attr_accessor :fails
    attr_accessor :successes

    ##
    # Initilizes the object
    # Params:
    # +current_idx+: index of the current query
    def initialize(current_idx, no_of_hits, definition)
      @opt             = opt
      @dirs            = dirs
      @config          = config
      @config[:run_no] += 1
      output_dir       = @dirs[:output_dir]
      @output_filename = File.join(output_dir, "#{@dirs[:filename]}_results")

      @prediction_def = definition
      @nr_hits        = no_of_hits
      @idx            = current_idx
    end

    def print_output_console
      return unless @opt[:output_formats].include? 'stdout'
      c_fmt = "%3s\t%5s\t%20s\t%7s\t"
      mutex.synchronize do
        print_console_header(c_fmt)
        short_def = @prediction_def.split(' ')[0]
        print format(c_fmt, @idx, @overall_score, short_def, @nr_hits)
        puts validations.map(&:print).join("\t").gsub('&nbsp;', ' ')
      end
    end

    def generate_json
      fname = File.join(@dirs[:json_dir], "#{@dirs[:filename]}_#{@idx}.json")
      row_data = { idx: @idx, overall_score: @overall_score,
                   definition: @prediction_def, no_hits: @nr_hits }
      row = create_validation_hash(row_data)
      arr_idx = @idx - 1
      @config[:json_output][arr_idx] = row
      File.open(fname, 'w') { |f| f.write(row.to_json) }
    end

    private

    def print_console_header(c_fmt)
      return if @config[:console_header_printed]
      @config[:console_header_printed] = true
      warn '==> Validating input sequences'
      warn '' # blank line
      print format(c_fmt, 'No', 'Score', 'Identifier', 'No_Hits')
      puts validations.map(&:short_header).join("\t")
    end

    def create_validation_hash(row)
      row[:validations] = {}
      @validations.each do |item|
        val     = add_basic_validation_info(item)
        explain = add_explanation_data(item) if item.color != 'warning'
        val.merge!(explain) if explain
        val[:graphs] = create_graphs_hash(item) unless item.plot_files.nil?
        row[:validations][item.short_header] = val
      end
      row
    end

    def add_basic_validation_info(item)
      { header: item.header, description: item.description, status: item.color,
        print: item.print.gsub('&nbsp;', ' '), run_time: item.run_time,
        validation: item.validation }
    end

    def add_explanation_data(item)
      { approach: item.approach, explanation: item.explanation,
        conclusion: item.conclusion }
    end

    def create_graphs_hash(item)
      graphs = []
      item.plot_files.each do |g|
        graphs << { data: g.data, type: g.type, title: g.title,
                    footer: g.footer, xtitle: g.xtitle, ytitle: g.ytitle,
                    aux1: g.aux1, aux2: g.aux2 }
      end
      graphs
    end

    class <<self
      def print_console_footer(overall_evaluation, opt)
        return unless (opt[:output_formats].include? 'stdout') ||
                      opt[:hide_summary]
        warn ''
        warn "==> #{overall_evaluation.join("\n")}"
        warn ''
      end

      def generate_overview(json_data, min_blast_hits)
        scores_from_json = json_data.map { |e| e[:overall_score] }
        quartiles = scores_from_json.all_quartiles
        nee = calculate_no_quries_with_no_evidence(json_data)
        no_mafft = count_mafft_errors(json_data)
        no_internet = count_internet_errors(json_data)
        map_errors = map_errors(json_data)
        run_time = calculate_run_time(json_data)
        min_hits = json_data.count { |e| e[:no_hits] < min_blast_hits }
        overview_hash(scores_from_json, quartiles, nee, no_mafft, no_internet,
                      map_errors, run_time, min_hits)
      end

      def overview_hash(scores_from_json, quartiles, nee, no_mafft, no_internet,
                        map_errors, run_time, insufficient_BLAST_hits)
        {
          scores: scores_from_json,
          no_queries: scores_from_json.length,
          good_scores: scores_from_json.count { |s| s >= 75 },
          bad_scores: scores_from_json.count { |s| s < 75 },
          nee: nee, no_mafft: no_mafft, no_internet: no_internet,
          map_errors: map_errors, run_time: run_time,
          first_quartile_of_scores: quartiles[0],
          second_quartile_of_scores: quartiles[1],
          third_quartile_of_scores: quartiles[2],
          insufficient_BLAST_hits: insufficient_BLAST_hits
        }
      end

      # calculate number of queries that had warnings for all validations.
      def calculate_no_quries_with_no_evidence(json_data)
        all_warnings = 0
        json_data.each do |row|
          status = row[:validations].map { |_, h| h[:status] }
          if status.count { |r| r == 'warning' } == status.length
            all_warnings += 1
          end
        end
        all_warnings
      end

      def count_mafft_errors(json_data)
        json_data.count do |row|
          num = row[:validations].count { |_, h| h[:print] == 'Mafft error' }
          num.zero? ? false : true
        end
      end

      def count_internet_errors(json_data)
        json_data.count do |row|
          num = row[:validations].count { |_, h| h[:print] == 'Internet error' }
          num.zero? ? false : true
        end
      end

      def map_errors(json_data)
        errors = {}
        json_data.map do |row|
          e = row[:validations].map { |s, h| s if h[:validation] == 'error' }
          e.compact.each { |err| errors[err] += 1 }
        end
        errors
      end

      def calculate_run_time(json_data)
        run_time = Hash.new(Pair1.new(0, 0))
        json_data.map do |row|
          row[:validations].each do |short_header, v|
            next if v[:run_time].nil? || v[:run_time].zero?
            next if v[:validation] == 'unapplicable' || v[:validation] == 'error'
            p = Pair1.new(run_time[short_header.to_s].x + v[:run_time],
                          run_time[short_header.to_s].y + 1)
            run_time[short_header.to_s] = p
          end
        end
        run_time
      end

      ##
      # Calculates an overall evaluation of the output
      # Params:
      # +all_query_outputs+: Array of +ValidationTest+ objects
      # Output
      # Array of Strigs with the reports
      def generate_evaluation_text(overview)
        eval       = general_overview(overview)
        error_eval = errors_overview(overview)
        time_eval  = time_overview(overview)

        [eval, error_eval, time_eval].reject(&:empty?)
      end

      private

      def general_overview(o)
        good_pred = o[:good_scores] == 1 ? 'One' : "#{o[:good_scores]} are"
        bad_pred  = o[:bad_scores] == 1 ? 'One' : "#{o[:bad_scores]} are"

        plural = 'prediction was' if o[:insufficient_BLAST_hits] == 1
        plural = 'predictions were' if o[:insufficient_BLAST_hits] >= 2
        b = "#{o[:insufficient_BLAST_hits]} #{plural} not evaluated due to an" \
            ' insufficient number of BLAST hits.'
        blast_hits = o[:insufficient_BLAST_hits].zero? ? '' : b

        ['Overall Query Score Evaluation:',
         "#{o[:no_queries]} predictions were validated, from which there were:",
         "#{good_pred} good prediction(s),",
         "#{bad_pred} possibly weak prediction(s).", blast_hits,
         "The median overall score was #{o[:second_quartile_of_scores]} with" \
         " an upper quartile of #{o[:third_quartile_of_scores]}" \
         " and a lower quartile of #{o[:first_quartile_of_scores]}."]
      end

      # errors per validation
      def errors_overview(o)
        error_eval = o[:map_errors].map do |k, v|
          "We couldn't run #{k} Validation for #{v} queries"
        end
        if o[:no_mafft] >= (o[:no_queries] - o[:nee])
          error_eval << "We couldn't run MAFFT multiple alignment"
        end
        if o[:no_internet] >= (o[:no_queries] - o[:nee])
          error_eval << "\nWe couldn't make use of your internet connection"
        end
        error_eval
      end

      def time_overview(o)
        o[:run_time].map do |key, value|
          mean_time = value.x / value.y.to_f
          "Average running time for #{key} Validation: #{mean_time.round(3)}s" \
          ' per validation'
        end
      end
    end
  end
end
