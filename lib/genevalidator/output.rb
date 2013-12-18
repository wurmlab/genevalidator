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
  attr_accessor :mutex
  attr_accessor :mutex_yaml
  attr_accessor :mutex_html

  ##
  # Initilizes the object
  # Params:
  # +filename+: name of the fasta input file
  # +html_path+: path of the html folder
  # +yaml_path+: path where the yaml output wil be saved
  # +idx+: idnex of the current query
  # +start_idx+: number of the sequence from the file to start with
  def initialize(mutex, mutex_yaml, mutex_html, filename, html_path, yaml_path, idx = 0, start_idx = 0)

    @prediction_len = 0
    @prediction_def = "no_definition"
    @nr_hits = 0

    @filename = filename
    @html_path = html_path
    @yaml_path = yaml_path
    @idx = idx
    @start_idx = start_idx
   
    @mutex = mutex
    @mutex_yaml = mutex_yaml
    @mutex_html = mutex_html

  end
  
  def print_output_console

    if @idx == @start_idx
      header =sprintf("%3s|%s|%20s|%5s", "No", "Score", "Identifier", "No_Hits")
      validations.map do |v| 
        header<<"|#{v.short_header}"
      end
      puts header      
    end

    short_def = @prediction_def.scan(/([^ ]+)/)[0][0]
    #short_def = short_def[0..[20,short_def.length].min]
    validation_outputs = validations.map{|v| v.print}

    successes = validations.map{|v| v.result ==
      v.expected}.count(true)

    fails = validations.map{|v| v.validation != :unapplicable and
      v.validation != :error and
      v.result != v.expected}.count(true)

    lcv = validations.select{|v| v.class == LengthClusterValidationOutput}
    lrv = validations.select{|v| v.class == LengthRankValidationOutput}
    if lcv.length == 1 and lrv.length == 1
      score_lcv = (lcv[0].result == lcv[0].expected)
      score_lrv = (lrv[0].result == lrv[0].expected)
      # if both are true this should be counted as a single success
      if score_lcv == true and score_lrv == true
        successes = successes - 1
      else
      # if both are false this will be a fail
        if score_lcv == false and score_lrv == false
          fails = fails - 1
        else
          successes = successes - 0.5
          fails = fails - 0.5
        end
      end
    end

    overall_score = (successes*100/(successes + fails + 0.0)).round(0)

    output = sprintf("%3s|%d|%20s|%5s|", @idx, overall_score, short_def, @nr_hits)
    validation_outputs.each do |item|
      item_padd = sprintf("%17s", item);
      output << item
      output << "|"
    end

    @mutex.synchronize {
      puts output
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

    successes = validations.map{|v| v.result == 
      v.expected}.count(true)

    fails = validations.map{|v| v.validation != :unapplicable and
      v.validation != :error and 
      v.result != v.expected}.count(true)

    lcv = validations.select{|v| v.class == LengthClusterValidation}
    lrv = validations.select{|v| v.class == LengthRankValidation}
    if lcv.length == 1 and lrv.length == 1
      score_lcv = (lcv[0].result == lcv[0].expected)
      score_lrv = (lrv[0].result == lrv[0].expected)
      # if both are true this should be counted as a single success
      if score_lcv == true and score_lrv == true
        successes = successes - 1
      else 
      # if both are false this will be a fail
        if score_lcv == false and score_lrv == false
          fails = fails - 1
        else
          successes = successes - 0.5
          fails = fails - 0.5
        end
      end
    end

    overall_score = (successes*100/(successes + fails + 0.0)).round(0)

    if fails == 0
      bg_icon = "success"
    else
      bg_icon = "danger"
    end

    index_file = "#{@html_path}/index.html"

    # if it's the first time I write in the html file
    if @idx == @start_idx
      @mutex_html.synchronize {
        template_file = File.open(File.join(File.dirname(File.expand_path(__FILE__)), "../../aux/template_header.htm.erb"), 'r').read
        erb = ERB.new(template_file)
        File.open(index_file, 'w+') { |file| file.write(erb.result(binding)) }      
      }
    end

    toggle = "toggle#{@idx}"

    @mutex_yaml.synchronize {
      template_file = File.open(File.join(File.dirname(File.expand_path(__FILE__)), "../../aux/template_query.htm.erb"), 'r').read
      erb = ERB.new(template_file)
      File.open(index_file, 'a') { |file| file.write(erb.result(binding)) }
    }

  end

  ##
  # Class that closes the gas in the html file and writes the overall evaluation
  # Param:
  # +all_query_outputs+: array with +ValidationTest+ objects
  # +html_path+: path of the html folder
  def self.print_footer(all_query_outputs, html_path, filename)

    # compute the statistics
    overall_evaluation = overall_evaluation(all_query_outputs, filename)

    less = overall_evaluation[0]
    less = less.gsub("\n","<br>").gsub("'",%q(\\\'))

    scores = overall_evaluation[overall_evaluation.length-1]

    # print to console
    evaluation = ""
    overall_evaluation[0..overall_evaluation.length-2].each{|e| evaluation << "\n#{e}"}
    puts evaluation
    puts ""

    # print to html

    # make the historgram with the resulted scores
    statistics_filename = "#{html_path}/#{filename}_statistics.json"
    f = File.open(statistics_filename, "w")

    f.write(
      [scores.group_by{|a| a}.map { |k, vs| {"key"=>k, "value"=>vs.length, "main"=>false}}].to_json)
    f.close

    plot_statistics = Plot.new("#{filename}_statistics.json",
              :simplebars,
              "Overall evaluation",
              "",
              "validation score",
              "number of queries",
              10)

    evaluation = evaluation.gsub("\n","<br>").gsub("'",%q(\\\'))
    index_file = "#{html_path}/index.html"
    template_file = File.open(File.join(File.dirname(File.expand_path(__FILE__)), "../../aux/template_footer.htm.erb"), 'r').read
    erb = ERB.new(template_file)
    File.open(index_file, 'a+') { |file| file.write(erb.result(binding)) }
  end

  ##
  # Calculates an overall evaluation of the output
  # Params:
  # +all_query_outputs+: Array of +ValidationTest+ objects
  # Output
  # Array of Strigs with the reports
  def self.overall_evaluation(all_query_outputs, filename)
      score_evaluation = ""
      score_evaluation << "Query score evaluation for #{filename}:"
      
      # count the cases of "not enough evidence"
      no_evidence = all_query_outputs.count{|report|
        report.validations.count{|v| v.result == :unapplicable or v.result == :warning} == report.validations.length
      }  

      # print at the console
      scores = []
      no_mafft = 0
      no_internet = 0

      # how many genes are good
      all_query_outputs.each do |report| 
        successes = report.validations.map{|v| v.result == v.expected}.count(true)
        fails = report.validations.map{|v| v.validation != :unapplicable and v.validation != :error and
          v.result != v.expected}.count(true)
        overall_score = (successes*100/(successes + fails + 0.0)).round(0)
        scores.push overall_score

        report.validations.each do |v| 
          if v.errors != nil
            no_mafft += v.errors.select{|e| e == NoMafftInstallationError}.length
          end
        end

        report.validations.each do |v| 
          if v.errors != nil
            no_internet += v.errors.select{|e| e == NoInternetError}.length
          end
        end
      end

      good_scores = scores.count{|v| v > 75}
      bad_scores = scores.length - good_scores 

      score_evaluation << "\nThere were validated #{all_query_outputs.length} predictions from which:"
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

      error_evaluation = ""
      # errors per validation
      validations = all_query_outputs[0].validations
      validations.each_with_index do |v,i|
        no_errors = 0
        all_query_outputs.each do |report|
          if report.validations[i].validation == :error
            no_errors += 1
          end
        end
        if no_errors != 0
          error_evaluation <<  "\nWe couldn't run #{v.short_header} Validation for #{no_errors} queries"
        end
      end

      if no_mafft >=  (all_query_outputs.length - no_evidence) 
        error_evaluation << "\nWe couldn't run MAFFT multiple alignment"
      end
      if no_internet >=  (all_query_outputs.length - no_evidence)
        error_evaluation << "\nWe couldn't make use of your internet connection"
      end

      # Running time statistics
      running_times = {}
      all_query_outputs[0].validations.each do |v|
        running_times[v.short_header] = []
      end

      all_query_outputs.each do |output|
        output.validations.each do |v|
          if v.running_time != 0 and 
             v.running_time != nil and 
             v.validation != :unapplicable and
             v.validation != :error
             running_times[v.short_header].push v.running_time
          end
        end
      end
     
      #puts running_times["Duplication"].to_s

      time_evaluation = ""
      time_evaluation << "\nRunning Time:"
      running_times = running_times.select{|k,v| v.length!=0}
      running_times.each do |key, array|
        average_time = array.inject{ |sum, el| sum + el }.to_f / array.size
        time_evaluation << "\nAverage running time for #{key} Validation: #{average_time.round(3)}s per validation"
      end

      overall_evaluation = [score_evaluation, error_evaluation, time_evaluation, scores]
      overall_evaluation = overall_evaluation.select{|e| e!=""}
      return overall_evaluation
  end

end
