require 'genevalidator/version'
require 'fileutils'
require 'erb'
require 'yaml'
require 'thread'
require 'json'

module GeneValidator
  class Output
    extend Forwardable
    def_delegators GeneValidator, :opt, :config, :mutex, :mutex_html, :mutex_json
    attr_accessor :prediction_len
    attr_accessor :prediction_def
    attr_accessor :nr_hits

    # list of +ValidationReport+ objects
    attr_accessor :validations

    attr_accessor :filename
    attr_accessor :html_path
    attr_accessor :yaml_path
    attr_accessor :idx
    attr_accessor :start_idx

    attr_accessor :overall_score
    attr_accessor :fails
    attr_accessor :successes

    ##
    # Initilizes the object
    # Params:
    # +current_idx+: index of the current query
    def initialize(current_idx)
      @opt            = opt
      @config         = config
      @mutex          = mutex
      @mutex_html     = mutex_html
      @mutex_json     = mutex_json

      @prediction_len = 0
      @prediction_def = 'no_definition'
      @nr_hits        = 0
      @idx            = current_idx
      @start_idx      = @config[:start_idx]

      @filename       = @config[:filename]
      @html_path      = @config[:html_path]
      @dir            = @config[:dir]
      @aux_dir        = @config[:aux]
      @json_hash      = @config[:json_hash]

      @results_html   = "#{@html_path}/results.html"
      @table_html     = "#{@html_path}/files/table.html"
    end

    def print_output_console
      print_console_header if @config[:run_no] == 0

      short_def          = @prediction_def.scan(/([^ ]+)/)[0][0]
      validation_outputs = validations.map(&:print)

      output             = sprintf('%3s|%5s|%20s|%7s|', @idx, @overall_score,
                                   short_def, @nr_hits)
      validation_outputs.each do |item|
        output << item
        output << '|'
      end

      @mutex.synchronize do
        puts output.gsub('&nbsp;', ' ')
      end
    end

    def print_console_header
      @config[:run_no] += 1
      header = sprintf('%3s|%5s|%20s|%7s', 'No', 'Score', 'Identifier',
                       'No_Hits')
      validations.map do |v|
        header << "|#{v.short_header}"
      end
      puts header
    end

    def set_up_html_file(erb_file, output_file)
      template_file_name = File.join(@aux_dir, erb_file)
      template_contents  = File.open(template_file_name, 'r').read
      erb                = ERB.new(template_contents, 0, '>')
      return if File.exist?(output_file)
      File.open(output_file, 'w+') do |f|
        f.write(erb.result(binding))
      end
    end

    def generate_html
      bg_icon = (@fails == 0) ? 'success' : 'danger'
      unless File.exist?(@results_html)
        set_up_html_file('template_header.erb', @results_html)
        set_up_html_file('app_template_header.erb', @table_html)
      end
      @mutex_html.synchronize do
        template_query = File.join(@aux_dir, 'template_query.erb')
        template_file = File.open(template_query, 'r').read
        erb = ERB.new(template_file, 0, '>')
        File.open(@results_html, 'a') { |f| f.write(erb.result(binding)) }
        File.open(@table_html, 'a') { |f| f.write(erb.result(binding)) }
      end
    end

    def generate_json
      @mutex_json.synchronize do
        row = { overall_score: @overall_score, definition: @prediction_def,
                no_hits: @nr_hits }
        row = create_validation_hashes(row)
        @json_hash[@idx] = row
      end
    end

    def create_validation_hashes(row)
      @validations.each do |item|
        val = { print: item.print, status: item.color }
        if item.color != 'warning'
          val = { print: item.print, status: item.color,
                  approach: item.approach, explanation: item.explanation,
                  conclusion: item.conclusion }
        end
        val[:graphs] = create_graphs_hash(item) unless item.plot_files.nil?
        row[item.header] = val
      end
      row
    end

    def create_graphs_hash(item)
      graphs = []
      item.plot_files.each do |p|
        graph = { filename: p.filename, type: p.type, title: p.title,
                  footer: p.footer, xtitle: p.xtitle, ytitle: p.ytitle,
                  aux1: p.aux1, aux2: p.aux2 }
        graphs << graph
      end
      graphs
    end

    def self.write_json_file(hash, json_file)
      File.open(json_file, 'w') do |f|
        f.write(hash.to_json)
      end
    end

    ##
    # Method that closes the gas in the html file and writes the overall
    # evaluation
    # Param:
    # +all_query_outputs+: array with +ValidationTest+ objects
    # +html_path+: path of the html folder
    # +filemane+: name of the fasta input file
    # def self.print_footer(all_query_outputs, html_path, filename)
    def self.print_footer(no_queries, scores, good_predictions, bad_predictions,
                          nee, no_mafft, no_internet, map_errors, running_times,
                          html_path, filename)

      overall_evaluation = overall_evaluation(no_queries, good_predictions,
                                              bad_predictions, nee, no_mafft,
                                              no_internet, map_errors,
                                              running_times)

      less = overall_evaluation[0]
      less = less.gsub("\n", '<br>').gsub("'", %q(\\\'))

      # print to console
      evaluation = ''
      overall_evaluation.each { |e| evaluation << "\n#{e}" }
      puts evaluation
      puts ''

      # print to html
      # make the historgram with the resulted scores
      statistics_filename = "#{html_path}/files/json/#{filename}_statistics.json"
      f = File.open(statistics_filename, 'w')

      f.write(
        [scores.group_by { |a| a }.map { |k, vs| { 'key' => k,
                                                   'value' => vs.length,
                                                   'main' => false } }].to_json)
      f.close

      plot_statistics = Plot.new("files/json/#{filename}_statistics.json",
                                 :simplebars,
                                 'Overall evaluation',
                                 '',
                                 'validation score',
                                 'number of queries',
                                 10)

      evaluation = evaluation.gsub("\n", '<br>').gsub("'", %q(\\\'))

      template_footer     = File.join(@aux_dir, 'template_footer.erb')
      app_template_footer = File.join(@aux_dir, 'app_template_footer.erb')

      template_file = File.open(template_footer, 'r').read
      erb = ERB.new(template_file, 0, '>')
      File.open(@results_html, 'a+') do |file|
        file.write(erb.result(binding))
      end

      table_footer_template = File.open(app_template_footer, 'r').read
      table_erb = ERB.new(table_footer_template, 0, '>')
      File.open(@table_html, 'a+') do |file|
        file.write(table_erb.result(binding))
      end
    end

    ##
    # Calculates an overall evaluation of the output
    # Params:
    # +all_query_outputs+: Array of +ValidationTest+ objects
    # Output
    # Array of Strigs with the reports
    def self.overall_evaluation(no_queries, good_scores, bad_scores,
                                no_evidence, no_mafft, no_internet, map_errors,
                                running_times)
      good_pred = (good_scores == 1) ? 'One' : "#{good_scores} are"
      bad_pred  = (bad_scores == 1) ? 'One' : "#{bad_scores} are"

      eval = "Overall Query Score Evaluation:\n" \
             "#{no_queries} predictions were validated, from which there" \
             " were:\n" \
             "#{good_pred} good prediction(s),\n" \
             "#{bad_pred} possibly weak prediction(s).\n"

      if no_evidence != 0
        eval << "#{no_evidence} could not be evaluated due to the lack of" \
                ' evidence.'
      end

      # errors per validation
      error_eval = ''
      map_errors.each do |k, v|
        error_eval << "\nWe couldn't run #{k} Validation for #{v} queries"
      end

      if no_mafft >= (no_queries - no_evidence)
        error_eval << "\nWe couldn't run MAFFT multiple alignment"
      end
      if no_internet >= (no_queries - no_evidence)
        error_eval << "\nWe couldn't make use of your internet connection"
      end

      time_eval = ''
      running_times.each do |key, value|
        average_time = value.x / (value.y + 0.0)
        time_eval << "\nAverage running time for #{key} Validation:" \
                     " #{average_time.round(3)}s per validation"
      end

      overall_evaluation = [eval, error_eval, time_eval]
      overall_evaluation.select { |e| e != '' }
    end
  end
end
