require 'csv'
require 'erb'
require 'fileutils'
require 'forwardable'
require 'json'

require 'genevalidator/version'

module GeneValidator
  class Output
    extend Forwardable
    def_delegators GeneValidator, :opt, :config, :dirs, :mutex, :mutex_html,
                   :mutex_json, :mutex_csv
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
      @js_plots_dir    = File.join(output_dir, 'html_files/json')

      @prediction_def = definition
      @nr_hits        = no_of_hits
      @idx            = current_idx
    end

    def print_output_console
      return unless @opt[:output_formats].include? 'stdout'
      c_fmt = "%3s\t%5s\t%20s\t%7s\t"
      mutex.synchronize do
        print_console_header(c_fmt) unless @config[:console_header_printed]
        short_def = @prediction_def.scan(/([^ ]+)/)[0][0]
        print format(c_fmt, @idx, @overall_score, short_def, @nr_hits)
        puts validations.map(&:print).join("\t").gsub('&nbsp;', ' ')
      end
    end

    def generate_json
      mutex_json.synchronize do
        row_data = { idx: @idx, overall_score: @overall_score,
                     definition: @prediction_def, no_hits: @nr_hits }
        row = create_validation_hash(row_data)
        write_row_json(row)
        @config[:json_output] << row
      end
    end

    def generate_html
      return unless @opt[:output_formats].include? 'html'
      mutex_html.synchronize do
        html_output_file = html_output_filename
        query_erb     = File.join(@dirs[:aux_dir], 'template_query.erb')
        template_file = File.open(query_erb, 'r').read
        erb           = ERB.new(template_file, 0, '>')
        File.open(html_output_file, 'a') { |f| f.write(erb.result(binding)) }
      end
    end

    def generate_csv
      return unless @opt[:output_formats].include? 'csv'
      mutex_csv.synchronize do
        short_def = @prediction_def.scan(/([^ ]+)/)[0][0]
        line = [@idx, @overall_score, short_def, @nr_hits]
        line += validations.map(&:print).each { |e| e.gsub!('&nbsp;', ' ') }
        line.map { |e| e.gsub!(',', ' -') if e.is_a? String }
        write_csv_header unless File.exist?(@dirs[:csv_file])
        File.open(@dirs[:csv_file], 'a') { |f| f.puts line.join(',') }
      end
    end

    private

    def print_console_header(c_fmt)
      @config[:console_header_printed] = true
      warn '==> Validating input sequences'
      warn '' # blank line
      print format(c_fmt, 'No', 'Score', 'Identifier', 'No_Hits')
      puts validations.map(&:short_header).join("\t")
    end

    def write_row_json(row)
      row_json = File.join(@js_plots_dir, "#{@dirs[:filename]}_#{@idx}.json")
      File.open(row_json, 'w') { |f| f.write(row.to_json) }
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
        print: item.print.gsub('&nbsp;', ' ') }
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

    ### HTML Output

    def html_output_filename
      return unless @opt[:output_formats].include? 'html'
      result_part = (@idx.to_f / @config[:output_max]).ceil
      result_part = result_part == 1 ? '' : "_#{result_part}"
      html_output_file = @output_filename + result_part + '.html'
      write_html_header(html_output_file) unless File.exist?(html_output_file)
      html_output_file
    end

    def write_html_header(html_output_file)
      return unless @opt[:output_formats].include? 'html'
      head_erb          = File.join(@dirs[:aux_dir], 'template_header.erb')
      template_contents = File.open(head_erb, 'r').read
      erb               = ERB.new(template_contents, 0, '>')
      File.open(html_output_file, 'w+') { |f| f.write(erb.result(binding)) }
    end

    def write_csv_header
      header = %w[AnalysisNumber GVScore Identifier NumberOfHits]
      header += validations.map(&:short_header)
      File.open(@dirs[:csv_file], 'a') { |f| f.puts header.join(',') }
    end

    class <<self
      def print_console_footer(overall_evaluation, opt)
        return unless (opt[:output_formats].include? 'stdout') ||
                      opt[:hide_summary]
        warn ''
        warn "==> #{overall_evaluation.join("\n")}"
        warn ''
      end

      def write_json_file(array, json_file, opt)
        return unless opt[:output_formats].include? 'json'
        File.open(json_file, 'w') { |f| f.write(array.to_json) }
      end

      def write_best_fasta(data, fasta_file, input_file, query_idx, opt)
        return unless opt[:select_single_best]
        top_data = data.max_by { |e| [e[:overall_score], e[:no_hits]] }
        start_offset = query_idx[top_data[:idx] + 1] - query_idx[top_data[:idx]]
        end_offset   = query_idx[top_data[:idx]]
        query        = IO.binread(input_file, start_offset, end_offset)
        File.open(fasta_file, 'w') { |f| f.write(query) }
        puts query
      end

      ##
      # Method that closes the gas in the html file and writes the overall
      # evaluation
      # Param:
      # +all_query_outputs+: array with +ValidationTest+ objects
      # +html_path+: path of the html folder
      # +filemane+: name of the fasta input file
      def print_html_footer(opt, config, dirs)
        return unless opt[:output_formats].include? 'html'

        footer_erb    = File.join(dirs[:aux_dir], 'template_footer.erb')
        template_file = File.open(footer_erb, 'r').read
        erb           = ERB.new(template_file, 0, '>')

        all_html_files = all_html_output_files(config, dirs)
        all_html_files.each do |fname|
          output = File.join(dirs[:output_dir], fname)
          File.open(output, 'a+') { |f| f.write(erb.result(binding)) }
        end

        turn_off_sorting(dirs[:output_dir]) if all_html_files.length > 1
      end

      def create_overview_json_for_html(overview, scores, opt, dirs)
        return unless opt[:output_formats].include? 'html'
        evaluation = overview.flatten.join('<br>').gsub("'", %q(\\\'))
        less = overview[0].join('<br>')
        json = File.join(dirs[:output_dir], 'html_files/json/overview.json')

        hash = overview_html_hash(scores, less, evaluation)
        File.open(json, 'w') { |f| f.write hash.to_json }
      end

      ##
      # Calculates an overall evaluation of the output
      # Params:
      # +all_query_outputs+: Array of +ValidationTest+ objects
      # Output
      # Array of Strigs with the reports
      def calculate_overview(overview)
        eval       = general_overview(overview)
        error_eval = errors_overview(overview)
        time_eval  = time_overview(overview)

        [eval, error_eval, time_eval].reject(&:empty?)
      end

      def write_summary_file(overview, summary_file, opt)
        return unless opt[:output_formats].include? 'summary'
        data = generate_summary_data(overview)
        File.open(summary_file, 'w') { |f| f.write data.map(&:to_csv).join }
      end

      def generate_summary_data(overview)
        [
          ['num_predictions', overview[:no_queries]],
          ['num_good_predictions', overview[:good_scores]],
          ['num_bad_predictions', overview[:bad_scores]],
          ['num_predictions_with_insufficient_blast_hits', overview[:insufficient_BLAST_hits]],
          ['first_quartile_of_scores', overview[:first_quartile_of_scores]],
          ['second_quartile_of_scores', overview[:second_quartile_of_scores]],
          ['third_quartile_of_scores', overview[:third_quartile_of_scores]]
        ]
      end

      private

      def all_html_output_files(config, dirs)
        fname = "#{dirs[:filename]}_results"
        total_files = (config[:run_no].to_f / config[:output_max]).ceil
        return [fname + '.html'] if total_files == 1
        (1..total_files).map { |i| "#{fname}#{i == 1 ? '' : "_#{i}"}.html" }
      end

      def turn_off_sorting(output_dir)
        script_file = File.join(output_dir, 'html_files/js/gv.compiled.min.js')
        content     = File.read(script_file).gsub(',initTableSorter(),', ',')
        File.open("#{script_file}.tmp", 'w') { |f| f.puts content }
        FileUtils.mv("#{script_file}.tmp", script_file)
      end

      # make the historgram with the resulted scores
      def overview_html_hash(scores, less, evaluation)
        data = [scores.group_by { |a| a }.map do |k, vs|
          { 'key': k, 'value': vs.length, 'main': false }
        end]
        { data: data, type: :simplebars, aux1: 10, aux2: '',
          title: 'Overall GeneValidator Score Evaluation', footer: '',
          xtitle: 'Validation Score', ytitle: 'Number of Queries',
          less: less, evaluation: evaluation }
      end

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
