require 'fileutils'
require 'erb'
require 'yaml'

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

  ##
  # Initilizes the object
  # Params:
  # +filename+: name of the fasta input file
  # +html_path+: path of the html folder
  # +yaml_path+: path where the yaml output wil be saved
  # +idx+: idnex of the current query
  # +start_idx+: number of the sequence from the file to start with
  def initialize(filename, html_path, yaml_path, idx = 0, start_idx = 0)

    @prediction_len = 0
    @prediction_def = "no_definition"
    @nr_hits = 0

    @filename = filename
    @html_path = html_path
    @yaml_path = yaml_path
    @idx = idx
    @start_idx = start_idx

  end

  
  def print_output_console

    if @idx == @start_idx
      header =sprintf("%3s|%20s|%5s", "No", "Identifier", "No_Hits")
      validations.map do |v| 
        header<<"|#{v.short_header}"
      end
      puts header
    end

    short_def = @prediction_def.scan(/([^ ]+)/)[0][0]
    #short_def = short_def[0..[20,short_def.length].min]
    validation_outputs = validations.map{|v| v.validation_report.print}

    output = sprintf("%3s|%20s|%5s|", @idx, short_def, @nr_hits)
    validation_outputs.each do |item|
      item_padd = sprintf("%17s", item);
      output << item
      output << "|"
    end

    puts output

  end


  def print_output_file_yaml

    file_yaml = "#{@yaml_path}/#{@filename}.yaml"
    report = validations.map{|v| v.validation_report}
    unless @idx == @start_idx
      hsh = YAML.load_file(file_yaml)
      hsh[@prediction_def.scan(/([^ ]+)/)[0][0]] = report
      File.open(file_yaml, "w") do |f|
        YAML.dump(hsh, f)
      end
    else 
      File.open(file_yaml, "w") do |f|
        YAML.dump({@prediction_def.scan(/([^ ]+)/)[0][0] => report},f)
      end
    end

  end


  def generate_html
 
    successes = validations.map{|v| v.validation_report.result == 
      v.validation_report.expected}.count(true)
    fails = validations.map{|v| v.validation_report.validation != :unapplicable and
      v.validation_report.validation != :error and 
      v.validation_report.result != v.validation_report.expected}.count(true)
    unknown = validations.length - successes - fails
    overall_score = (successes*100/(successes + fails + 0.0)).round(0)

    if fails == 0
      bg_icon = "success"
    else
      bg_icon = "danger"
    end

    index_file = "#{@html_path}/index.html"

    # if it's the first time I write in the html file
    if @idx == @start_idx
      template_file = File.open("aux/template_header.htm.erb", 'r').read
      erb = ERB.new(template_file)
      File.open(index_file, 'w+') { |file| file.write(erb.result(binding)) }      
    end

    toggle = "toggle#{@idx}"

    template_file = File.open("aux/template_query.htm.erb", 'r').read
    erb = ERB.new(template_file)

    File.open(index_file, 'a') { |file| file.write(erb.result(binding)) }
 
  end

  ##
  # Class that closes the gas in the html file and writes the overall evaluation
  # Param:
  # +all_query_outputs+: array with +ValidationTest+ objects
  # +html_path+: path of the html folder
  def self.print_footer(all_query_outputs, html_path)
    overall_evaluation = overall_evaluation(all_query_outputs)
    # print to console
    evaluation = ""
    overall_evaluation.each{|e| evaluation << "\n#{e}"}
    puts evaluation
    puts ""
    evaluation = evaluation.gsub("\n","<br>")

    # print to html
    index_file = "#{html_path}/index.html"
    template_file = File.open("aux/template_footer.htm.erb", 'r').read
    erb = ERB.new(template_file)
    File.open(index_file, 'a+') { |file| file.write(erb.result(binding)) }
  end

  ##
  # Calculates an overall evaluation of the output
  # Params:
  # +all_query_outputs+: Array of +ValidationTest+ objects
  # Output
  # Array of Strigs with the reports
  def self.overall_evaluation(all_query_outputs)
      score_evaluation = ""
      score_evaluation << "Query score evaluation:"
      
      # count the cases of "not enough evidence"
      no_evidence = all_query_outputs.count{|report|
        report.validations.count{|v| v.validation_report.result == :unapplicable or v.validation_report.result == :warning} == report.validations.length
      }  

      # print at the console
      scores = []
      no_mafft = 0
      no_internet = 0

      # how many genes are good
      all_query_outputs.each do |report| 
        successes = report.validations.map{|v| v.validation_report.result == v.validation_report.expected}.count(true)
        fails = report.validations.map{|v| v.validation_report.validation != :unapplicable and v.validation_report.validation != :error and
          v.validation_report.result != v.validation_report.expected}.count(true)
        overall_score = (successes*100/(successes + fails + 0.0)).round(0)
        scores.push overall_score

        report.validations.each do |v| 
          if v.validation_report.errors != nil
            no_mafft += v.validation_report.errors.select{|e| e == NoMafftInstallationError}.length
          end
        end

        report.validations.each do |v| 
          if v.validation_report.errors != nil
            no_internet += v.validation_report.errors.select{|e| e == NoInternetError}.length
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
          if report.validations[i].validation_report.validation == :error
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
             v.validation_report.validation != :unapplicable and
             v.validation_report.validation != :error
            running_times[v.short_header].push v.running_time
          end
        end
      end

      time_evaluation = ""
      time_evaluation << "\nRunning Time:"
      running_times = running_times.select{|k,v| v.length!=0}
      running_times.each do |key, array|
        average_time = array.inject{ |sum, el| sum + el }.to_f / array.size
        time_evaluation << "\nAverage running time for #{key} Validation: #{average_time.round(3)}s per validation"
      end

      overall_evaluation = [score_evaluation, error_evaluation, time_evaluation]
      overall_evaluation = overall_evaluation.select{|e| e!=""}
      return overall_evaluation
  end

end
