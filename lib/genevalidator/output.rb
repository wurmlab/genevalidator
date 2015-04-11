require 'genevalidator/version'
require 'fileutils'
require 'erb'
require 'yaml'
require 'thread'
module GeneValidator
  class Output
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

    attr_accessor :mutex
    attr_accessor :mutex_yaml
    attr_accessor :mutex_html

    ##
    # Initilizes the object
    # Params:
    # +mutex+: +Mutex+ for exclusive access to the console
    # +mutex_yaml+: +Mutex+ for exclusive access to the YAML file
    # +mutex_html+: +Mutex+ for exclusive access to the HTML file
    # +filename+: name of the fasta input file
    # +html_path+: path of the html folder
    # +yaml_path+: path where the yaml output wil be saved
    # +idx+: idnex of the current query
    # +start_idx+: number of the sequence from the file to start with
    def initialize(mutex, mutex_yaml, mutex_html, filename, html_path,
                   yaml_path, idx = 0, start_idx = 0)
      @prediction_len = 0
      @prediction_def = 'no_definition'
      @nr_hits        = 0

      @filename       = filename
      @html_path      = html_path
      @yaml_path      = yaml_path
      @idx            = idx
      @start_idx      = start_idx

      @mutex          = mutex
      @mutex_yaml     = mutex_yaml
      @mutex_html     = mutex_html
    end

    def print_output_console
      if @idx == @start_idx
        header = sprintf('%3s|%s|%20s|%5s', 'No', 'Score', 'Identifier',
                         'No_Hits')
        validations.map do |v|
          header << "|#{v.short_header}"
        end
        puts header
      end

      short_def          = @prediction_def.scan(/([^ ]+)/)[0][0]
      validation_outputs = validations.map(&:print)

      output             = sprintf('%3s|%d|%20s|%5s|', @idx, @overall_score,
                                   short_def, @nr_hits)
      validation_outputs.each do |item|
        output << item
        output << '|'
      end

      @mutex.synchronize do
        puts output.gsub('&nbsp;', ' ')
      end
    end

    def print_output_file_yaml
      file_yaml = "#{@yaml_path}/#{@filename}.yaml"
      report = validations
      if @idx == @start_idx
        @mutex_yaml.synchronize do
          File.open(file_yaml, 'w') do |f|
            YAML.dump({ @prediction_def.scan(/([^ ]+)/)[0][0] => report }, f)
          end
        end
      else
        @mutex_yaml.synchronize do
          hash = {} # YAML.load_file(file_yaml)
          hash[@prediction_def.scan(/([^ ]+)/)[0][0]] = report
          File.open(file_yaml, 'a') do |f|
            new_report =  hash.to_yaml
            f.write(new_report[4..new_report.length - 1])
          end
        end
      end
    end

    def generate_html
      if @fails == 0
        bg_icon = 'success'
      else
        bg_icon = 'danger'
      end

      index_file = "#{@html_path}/results.html"
      table_file = "#{@html_path}/files/table.html"

      aux_dir = File.join(File.dirname(File.expand_path(__FILE__)), '../../aux')

      # if it's the first time I write in the html file
      if @idx == @start_idx
        @mutex_html.synchronize do
          template_header     = File.join(aux_dir, 'template_header.erb')
          template_file       = File.open(template_header, 'r').read
          erb                 = ERB.new(template_file, 0, '>')

          #  Creating a Separate output file for the web app
          app_template_header = File.join(aux_dir, 'app_template_header.erb')
          table_template_file = File.open(app_template_header, 'r').read
          erb_table           = ERB.new(table_template_file, 0, '>')

          File.open(index_file, 'w+') do |file|
            file.write(erb.result(binding))
          end

          File.open(table_file, 'w+') do |file|
            file.write(erb_table.result(binding))
          end
        end
      end

      toggle = "toggle#{@idx}"

      @mutex_yaml.synchronize do
        template_query = File.join(aux_dir, 'template_query.erb')
        template_file = File.open(template_query, 'r').read
        erb = ERB.new(template_file, 0, '>')

        File.open(index_file, 'a') do |file|
          file.write(erb.result(binding))
        end

        File.open(table_file, 'a') do |file|
          file.write(erb.result(binding))
        end
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
      # compute the statistics
      # overall_evaluation = overall_evaluation(all_query_outputs, filename)
      overall_evaluation = overall_evaluation(no_queries, good_predictions,
                                              bad_predictions, nee, no_mafft,
                                              no_internet, map_errors,
                                              running_times, filename)

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

      index_file = "#{html_path}/results.html"
      table_file = "#{html_path}/files/table.html"
      aux_dir = File.join(File.dirname(File.expand_path(__FILE__)), '../../aux')

      template_footer     = File.join(aux_dir, 'template_footer.erb')
      app_template_footer = File.join(aux_dir, 'app_template_footer.erb')

      template_file = File.open(template_footer, 'r').read
      erb = ERB.new(template_file, 0, '>')
      File.open(index_file, 'a+') do |file|
        file.write(erb.result(binding))
      end

      table_footer_template = File.open(app_template_footer, 'r').read
      table_erb = ERB.new(table_footer_template, 0, '>')
      File.open(table_file, 'a+') do |file|
        file.write(table_erb.result(binding))
      end
    end

    ##
    # Calculates an overall evaluation of the output
    # Params:
    # +all_query_outputs+: Array of +ValidationTest+ objects
    # +filemane+: name of the fasta input file
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
