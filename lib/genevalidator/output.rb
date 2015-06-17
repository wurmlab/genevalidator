require 'genevalidator/version'
require 'fileutils'
require 'erb'
require 'yaml'
require 'thread'
require 'json'

module GeneValidator
  class Output
    extend Forwardable
    def_delegators GeneValidator, :opt, :config, :mutex, :mutex_html,
                   :mutex_json
    attr_accessor :prediction_def
    attr_accessor :nr_hits

    # list of +ValidationReport+ objects
    attr_accessor :validations

    attr_accessor :filename
    attr_accessor :html_path
    attr_accessor :yaml_path
    attr_accessor :idx

    attr_accessor :overall_score
    attr_accessor :fails
    attr_accessor :successes

    ##
    # Initilizes the object
    # Params:
    # +current_idx+: index of the current query
    def initialize(current_idx, no_of_hits, definition)
      @opt            = opt
      @config         = config
      @config[:run_no] += 1

      @prediction_def = definition
      @nr_hits        = no_of_hits
      @idx            = current_idx

      filename        = @config[:filename]
      @results_html   = create_new_result_file
      @app_html       = File.join(@config[:html_path], 'files/table.html')
    end

    def print_output_console
      mutex.synchronize do
        print_console_header unless @config[:console_header_printed]
        short_def = @prediction_def.scan(/([^ ]+)/)[0][0]
        print format('%3s|%5s|%20s|%7s|', @idx, @overall_score, short_def,
                     @nr_hits)
        puts validations.map(&:print).join('|').gsub('&nbsp;', ' ')
      end
    end

    def print_console_header
      @config[:console_header_printed] = true
      print format('%3s|%5s|%20s|%7s|', 'No', 'Score', 'Identifier', 'No_Hits')
      puts validations.map(&:short_header).join('|')
    end

    def generate_html
      mutex_html.synchronize do
        output_html = output_filename
        query_erb     = File.join(@config[:aux], 'template_query.erb')
        template_file = File.open(query_erb, 'r').read
        erb           = ERB.new(template_file, 0, '>')
        File.open(output_html, 'a') { |f| f.write(erb.result(binding)) }
        File.open(@app_html, 'a') { |f| f.write(erb.result(binding)) }
      end
    end

    def output_filename
      i = (@config[:run_no].to_f / @config[:output_max]).ceil
      output_html = File.join(@config[:html_path], "results#{i}.html")
      write_html_header(output_html)
      output_html
    end

    def write_html_header(output_html)
      head_erb       = File.join(@config[:aux], 'template_header.erb')
      head_table_erb = File.join(@config[:aux], 'app_template_header.erb')
      set_up_html(head_erb, output_html) unless File.exist?(output_html)
      set_up_html(head_table_erb, @app_html) unless File.exist?(@app_html)
    end

    def set_up_html(erb_file, output_file)
      return if File.exist?(output_file)
      template_contents = File.open(erb_file, 'r').read
      erb               = ERB.new(template_contents, 0, '>')
      File.open(output_file, 'w+') { |f| f.write(erb.result(binding)) }
    end

    def generate_json
      mutex_json.synchronize do
        row = { idx: @idx, overall_score: @overall_score,
                definition: @prediction_def, no_hits: @nr_hits }
        row = create_validation_hashes(row)
        write_row_json(row)
        @config[:json_output] << row
      end
    end

    def create_validation_hashes(row)
      row[:validations] = {}
      @validations.each do |item|
        val = { header: item.header, description: item.description,
                status: item.color, print: item.print.gsub('&nbsp;', ' ') }
        if item.color != 'warning'
          explain = { approach: item.approach, explanation: item.explanation,
                      conclusion: item.conclusion }
          val.merge!(explain)
        end
        val[:graphs] = create_graphs_hash(item) unless item.plot_files.nil?
        row[:validations][item.short_header] = val
      end
      row
    end

    def create_graphs_hash(item)
      graphs = []
      item.plot_files.each do |g|
        graphs << { data: g.data, type: g.type, title: g.title,
                    footer: g.footer, xtitle: g.xtitle,
                    ytitle: g.ytitle, aux1: g.aux1, aux2: g.aux2 }
      end
      graphs
    end

    def write_row_json(row)
      row_json = File.join(@config[:plot_dir],
                           "#{@config[:filename]}_#{@idx}.json")
      File.open(row_json, 'w') { |f| f.write(row.to_json) }
    end

    def self.write_json_file(array, json_file)
      File.open(json_file, 'w') { |f| f.write(array.to_json) }
    end

    ##
    # Method that closes the gas in the html file and writes the overall
    # evaluation
    # Param:
    # +all_query_outputs+: array with +ValidationTest+ objects
    # +html_path+: path of the html folder
    # +filemane+: name of the fasta input file
    def self.print_footer(overview, config)
      overall_evaluation = overview(overview)

      create_plot_json(overview[:scores], config[:plot_dir])

      less = overall_evaluation[0].gsub("\n", '<br>').gsub("'", %q(\\\'))

      eval = print_summary_to_console(overall_evaluation, config[:summary])
      evaluation     = eval.gsub("\n", '<br>').gsub("'", %q(\\\'))

      footer_erb     = File.join(config[:aux], 'template_footer.erb')

      no_of_results_files = (config[:run_no].to_f / config[:output_max]).ceil
      template_file       = File.open(footer_erb, 'r').read
      erb                 = ERB.new(template_file, 0, '>')

      output_files = []
      (1..no_of_results_files).each { |i| output_files << "results#{i}.html" }

      (1..no_of_results_files).each do |i|
        results_html = File.join(config[:html_path], "results#{i}.html")
        File.open(results_html, 'a+') { |f| f.write(erb.result(binding)) }
      end

      turn_off_sorting(config[:html_path]) if no_of_results_files > 1

      # write footer for the app
      app_footer_erb = File.join(config[:aux], 'app_template_footer.erb')
      table_html     = File.join(config[:html_path], 'files/table.html')
      table_footer_template = File.open(app_footer_erb, 'r').read
      table_erb             = ERB.new(table_footer_template, 0, '>')
      File.open(table_html, 'a+') { |f| f.write(table_erb.result(binding)) }
    end

    def self.turn_off_sorting(html_path)
      script_file = File.join(html_path, 'files/js/script.js')
      temp_file   = File.join(html_path, 'files/js/script.temp.js')
      File.open(temp_file, 'w') do |out_file|
        out_file.puts File.readlines(script_file)[30..-1].join
      end
      FileUtils.mv(temp_file, script_file)
    end

    def self.print_summary_to_console(overall_evaluation, summary)
      # print to console
      eval = ''
      overall_evaluation.each { |e| eval << "\n#{e}" }
      puts eval if summary
      puts ''
      eval
    end

    # make the historgram with the resulted scores
    def self.create_plot_json(scores, plot_dir)
      plot_file = File.join(plot_dir, 'overview.json')
      data = [scores.group_by { |a| a }.map { |k, vs| { 'key' => k, 'value' => vs.length, 'main' => false } }]
      hash = { data: data, type: :simplebars, title: 'Overall Evaluation',
               footer: '', xtitle: 'Validation Score',
               ytitle: 'Number of Queries', aux1: 10, aux2: '' }
      File.open(plot_file, 'w') { |f| f.write hash.to_json }
    end

    ##
    # Calculates an overall evaluation of the output
    # Params:
    # +all_query_outputs+: Array of +ValidationTest+ objects
    # Output
    # Array of Strigs with the reports
    def self.overview(o)
      eval       = general_overview(o)
      error_eval = errors_overview(o)
      time_eval  = time_overview(o)

      overall_evaluation = [eval, error_eval, time_eval]
      overall_evaluation.select { |e| e != '' }
    end

    def self.general_overview(o)
      good_pred = (o[:good_scores] == 1) ? 'One' : "#{o[:good_scores]} are"
      bad_pred  = (o[:bad_scores] == 1) ? 'One' : "#{o[:bad_scores]} are"

      eval = "Overall Query Score Evaluation:\n" \
             "#{o[:no_queries]} predictions were validated, from which there" \
             " were:\n" \
             "#{good_pred} good prediction(s),\n" \
             "#{bad_pred} possibly weak prediction(s).\n"

      if o[:nee] != 0 # nee = no evidence
        eval << "#{o[:nee]} could not be evaluated due to the lack of" \
                ' evidence.'
      end
      eval
    end

    def self.errors_overview(o)
      # errors per validation
      error_eval = ''
      o[:map_errors].each do |k, v|
        error_eval << "\nWe couldn't run #{k} Validation for #{v} queries"
      end
      if o[:no_mafft] >= (o[:no_queries] - o[:nee])
        error_eval << "\nWe couldn't run MAFFT multiple alignment"
      end
      if o[:no_internet] >= (o[:no_queries] - o[:nee])
        error_eval << "\nWe couldn't make use of your internet connection"
      end
      error_eval
    end

    def self.time_overview(o)
      time_eval = ''
      o[:run_time].each do |key, value|
        average_time = value.x / (value.y).to_f
        time_eval << "\nAverage running time for #{key} Validation:" \
                     " #{average_time.round(3)}s per validation"
      end
      time_eval
    end
  end
end
