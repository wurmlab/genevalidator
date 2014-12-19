require 'genevalidator/version'
require 'fileutils'
require 'erb'
require 'yaml'
require 'thread'

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
  def initialize(mutex, mutex_yaml, mutex_html, filename, html_path, yaml_path, idx = 0, start_idx = 0)
    @prediction_len = 0
    @prediction_def = "no_definition"
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
      header =sprintf("%3s|%s|%20s|%5s", "No", "Score", "Identifier", "No_Hits")
      validations.map do |v|
        header<<"|#{v.short_header}"
      end
      puts header
    end

    short_def          = @prediction_def.scan(/([^ ]+)/)[0][0]
    validation_outputs = validations.map{|v| v.print}

    output             = sprintf("%3s|%d|%20s|%5s|", @idx, @overall_score, short_def, @nr_hits)
    validation_outputs.each do |item|
      item_padd = sprintf("%17s", item);
      output    << item
      output    << "|"
    end

    @mutex.synchronize {
      puts output.gsub('&nbsp;', ' ')
    }

  end


  def print_output_file_yaml

    file_yaml = "#{@yaml_path}/#{@filename}.yaml"
    report = validations
    unless @idx == @start_idx
      @mutex_yaml.synchronize {
        hash = {} #YAML.load_file(file_yaml)
        hash[@prediction_def.scan(/([^ ]+)/)[0][0]] = report
        File.open(file_yaml, "a") do |f|
          new_report =  hash.to_yaml
          f.write(new_report[4..new_report.length-1])
        end
      }
    else
      @mutex_yaml.synchronize {
        File.open(file_yaml, "w") do |f|
          YAML.dump({@prediction_def.scan(/([^ ]+)/)[0][0] => report},f)
        end
      }
    end

  end


  def generate_html
    if @fails == 0
      bg_icon = "success"
    else
      bg_icon = "danger"
    end

    index_file = "#{@html_path}/results.html"

    # if it's the first time I write in the html file
    if @idx == @start_idx
      @mutex_html.synchronize {
        template_file = File.open(File.join(File.dirname(File.expand_path(__FILE__)), "../../aux/template_header.erb"), 'r').read
        erb = ERB.new(template_file, 0, '>')
        File.open(index_file, 'w+') { |file| file.write(erb.result(binding)) }

        #  Creating a Separate output file with just the table in it (for the web app)
        table_template_file = File.open(File.join(File.dirname(File.expand_path(__FILE__)), "../../aux/app_template_header.erb"), 'r').read
        erb_table = ERB.new(table_template_file , 0, '>')
        File.open("#{@html_path}/files/table.html", 'w+') { |file| file.write(erb_table.result(binding)) }
      }
    end

    toggle = "toggle#{@idx}"

    @mutex_yaml.synchronize {
      template_file = File.open(File.join(File.dirname(File.expand_path(__FILE__)), "../../aux/template_query.erb"), 'r').read
      erb = ERB.new(template_file , 0, '>')
      File.open(index_file, 'a') { |file| file.write(erb.result(binding)) }
      File.open("#{@html_path}/files/table.html", 'a') { |file| file.write(erb.result(binding)) }
    }

  end

  ##
  # Class that closes the gas in the html file and writes the overall evaluation
  # Param:
  # +all_query_outputs+: array with +ValidationTest+ objects
  # +html_path+: path of the html folder
  # +filemane+: name of the fasta input file
  #def self.print_footer(all_query_outputs, html_path, filename)
  def self.print_footer(no_queries, scores, good_predictions, bad_predictions, nee, no_mafft, no_internet, map_errors, running_times, html_path, filename)
    # compute the statistics
    #overall_evaluation = overall_evaluation(all_query_outputs, filename)
    overall_evaluation = overall_evaluation(no_queries, good_predictions, bad_predictions, nee, no_mafft, no_internet, map_errors, running_times, filename)

    less = overall_evaluation[0]
    less = less.gsub("\n","<br>").gsub("'",%q(\\\'))

    # print to console
    evaluation = ""
    overall_evaluation.each{|e| evaluation << "\n#{e}"}
    puts evaluation
    puts ""

    # print to html
    # make the historgram with the resulted scores
    statistics_filename = "#{html_path}/files/json/#{filename}_statistics.json"
    f = File.open(statistics_filename, "w")

    f.write(
      [scores.group_by{|a| a}.map { |k, vs| {"key"=>k, "value"=>vs.length, "main"=>false}}].to_json)
    f.close

    plot_statistics = Plot.new("files/json/#{filename}_statistics.json",
              :simplebars,
              "Overall evaluation",
              "",
              "validation score",
              "number of queries",
              10)

    evaluation = evaluation.gsub("\n","<br>").gsub("'",%q(\\\'))
    index_file = "#{html_path}/results.html"
    template_file = File.open(File.join(File.dirname(File.expand_path(__FILE__)), "../../aux/template_footer.erb"), 'r').read
    erb = ERB.new(template_file, 0, '>')
    File.open(index_file, 'a+') { |file| file.write(erb.result(binding)) }

    table_file = "#{html_path}/files/table.html"
    table_footer_template = File.open(File.join(File.dirname(File.expand_path(__FILE__)), "../../aux/app_template_footer.erb"), 'r').read
    table_erb = ERB.new(table_footer_template, 0, '>')
    File.open(table_file, 'a+') { |file| file.write(table_erb.result(binding)) }
  end

  ##
  # Calculates an overall evaluation of the output
  # Params:
  # +all_query_outputs+: Array of +ValidationTest+ objects
  # +filemane+: name of the fasta input file
  # Output
  # Array of Strigs with the reports
  #def self.overall_evaluation(all_query_outputs, filename)
  def self.overall_evaluation(no_queries, good_scores, bad_scores, no_evidence, no_mafft, no_internet, map_errors, running_times, filename)
    score_evaluation = ""
    score_evaluation << "Query score evaluation for #{filename}:"

    # count the cases of "not enough evidence"
    #no_evidence = all_query_outputs.count{|report|
    #  report.validations.count{|v| v.result == :unapplicable or v.result == :warning} == report.validations.length
    #}

    # print at the console
    #scores = all_query_outputs.map{|query| query.score}

    # how many genes are good

    score_evaluation << "\nThere were validated #{no_queries} predictions from which:"
    if good_scores == 1
      score_evaluation << "\nOne good prediction"
    else
      score_evaluation << "\n#{good_scores} are good predictions"
    end
    if bad_scores == 1
      score_evaluation << "\nOne possibly weak prediction"
    else
      score_evaluation << "\n#{bad_scores} are possibly weak predictions"
    end

    if no_evidence != 0
      score_evaluation << "\n#{no_evidence} of them couldn't be evaluated because of low evidence"
    end

    # errors per validation
    error_evaluation = ""
    map_errors.each{|k,v| error_evaluation <<  "\nWe couldn't run #{k} Validation for #{v} queries"}

    if no_mafft >=  (no_queries - no_evidence)
      error_evaluation << "\nWe couldn't run MAFFT multiple alignment"
    end
    if no_internet >=  (no_queries - no_evidence)
      error_evaluation << "\nWe couldn't make use of your internet connection"
    end

    time_evaluation = ""
    running_times.each do |key, value|
      average_time = value.x / (value.y + 0.0)
      time_evaluation << "\nAverage running time for #{key} Validation: #{average_time.round(3)}s per validation"
    end

    overall_evaluation = [score_evaluation, error_evaluation, time_evaluation]
    overall_evaluation.select{|e| e!=""}
  end

end
