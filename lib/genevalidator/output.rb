require 'fileutils'
require 'yaml'

class Output

  attr_accessor :prediction_len
  attr_accessor :prediction_def
  attr_accessor :nr_hits

  attr_accessor :length_validation_cluster
  attr_accessor :length_validation_rank
  attr_accessor :reading_frame_validation
  attr_accessor :gene_merge_validation
  attr_accessor :duplication
  attr_accessor :orf

  # list of +ValidationReport+ objects
  attr_accessor :validations

  attr_accessor :filename
  attr_accessor :html_path
  attr_accessor :image_histo_len
  attr_accessor :image_plot_merge
  attr_accessor :image_histo_merge
  attr_accessor :image_orfs
  attr_accessor :idx
  attr_accessor :start_idx

  def initialize(filename, html_path, idx, start_idx)

    @prediction_len = 0
    @prediction_def = "no_definition"
    @nr_hits = 0

    @filename = filename
    @html_path = html_path
    @idx = idx
    @start_idx = start_idx

    @image_histo_len = "#{filename}_#{@idx}_len_clusters.jpg"
    @image_plot_merge = "#{filename}_#{@idx}_match.jpg"
    @image_histo_merge = "#{filename}_#{@idx}_match_2d.jpg"
    @image_orfs = "#{filename}_#{@idx}_orfs.jpg"

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
    file_yaml = "#{@filename}.yaml"
    unless @idx == @start_idx
      hsh = YAML.load_file(file_yaml)
      hsh[@prediction_def.scan(/([^ ]+)/)[0][0]] = self
      File.open(file_yaml, "w") do |f|
        YAML.dump(hsh, f)
      end
    else 
      File.open(file_yaml, "w") do |f|
        YAML.dump({@prediction_def.scan(/([^ ]+)/)[0][0] => self},f)
      end
    end
  end

  def generate_html

    gray = "#E8E8E8"
    white = "#FFFFFF"

    if idx%2 == 0
      color = gray
    else 
      color = white 
    end

    if validations.map{|v| v.validation_report.color}.uniq.length == 1 and validations[0].validation_report.color == "white"
      icon = "&#10003;"
      bg_icon = "white"
    else
      icon = "<b>&#33;</b>"
      bg_icon = "red"
    end

    # if it's the first time I write in the html file
    if @idx == @start_idx
      header = "<html><head>
                     <title>Gene Validation Result</title>
                     <script type=\"text/javascript\" src=\"js/jquery-1.10.2.min.js\"></script> 
                     <script type=\"text/javascript\" src=\"js/jquery.tablesorter/jquery.tablesorter.js\"></script> 
                     <script type=\"text/javascript\" src=\"js/jquery.tablesorter.mod.js\"></script>
                     <script type=\"text/javascript\" src=\"js/script.js\"></script>
                  </head>
                  <body>
                      <table border=\"1\" cellpadding=\"5\" cellspacing=\"0\" width = 1650 id=\"myTable\" class=\"tablesorter\">
                                <thead>
                                <tr bgcolor = #E8E8E8>
                                        <th><b>Click to sort!</b></th>
                                        <th></th>
                                        <th>No.</th>
                                        <th width=100 title=\"FASTA Header of the query\">Description</th>
                                        <th title=\"Number of hits found by BLAST.\">No. Hits</th>"
                 validations.map do |v|
                   header<<"<th title=\"#{v.description}\">#{v.header}</th>\n"
                 end
                  
                 header += "       <th title=\"Overall evaluation based on all validation tests.\" > Overall Evaluation</th>
                                </tr></thead>"                  

      index_file = "#{@html_path}/index.html"        
      File.open(index_file, "w+") do |f|
        f.write(header)
      end  

    end

    toggle = "toggle#{@idx}"

    output = "<tr bgcolor=#{'white'}> 
	      <td><button type=button name=answer onclick=showDiv('#{toggle}')>Show/Hide Plots</button></td> 
              <td bgcolor=#{bg_icon}>#{icon}</td>
              <td>#{@idx}</td>
	      <td>#{@prediction_def}</td>
	      <td>#{@nr_hits}</td>"
    validations.each do |item|
      output << "<td bgcolor=#{item.validation_report.color} style=\"white-space:nowrap\">#{item.validation_report.print}</td>\n"
    end
    output += "<td style=\"white-space:nowrap\">...</td>
       	       </tr>

	       <tr bgcolor=#{color} class=\"expand-child\">"
    output += "<td  colspan=#{validations.length + 6}>"
    output += "<div id=#{toggle} style='display:none'>
               <img src=#{image_histo_len} alt=\"No plot\" height=400>
	       <img src=#{image_plot_merge} alt=\"No plot\" height=400>
               <img src=#{image_histo_merge} alt=\"No plot\" height=400>
               <img src=#{image_orfs} alt=\"No plot\" height=400>
               </div></td></tr>"

    File.open("#{html_path}/index.html", "a") do |f|
      f.write(output)
    end  
  end
end
