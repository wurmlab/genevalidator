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
      header =sprintf("%3s|%20s|%5s", "No", "Description", "No_Hits")
      validations.map do |v| 
        header<<"|#{v.short_header}"
      end
      puts header
    end

    short_def = @prediction_def.scan(/([^ ]+)/)[0][0]
    short_def = short_def[0..[20,short_def.length].min]
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

#    validations.map{|v| puts v.validation_report.errors.to_s}

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

    #@validations.map{|item| puts item.validation_report.plot_files.length}

    template_file = File.open("aux/template_query.htm.erb", 'r').read
    erb = ERB.new(template_file)

    File.open(index_file, 'a') { |file| file.write(erb.result(binding)) }
  end


  def add_html_footer

      template_file = File.open("aux/template_footer.htm.erb", 'r').read
      erb = ERB.new(template_file)
      File.open(index_file, 'w+') { |file| file.write(erb.result(binding)) }

  end

end
