
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

  attr_accessor :filename
  attr_accessor :image_histo_len
  attr_accessor :image_plot_merge
  attr_accessor :image_histo_merge
  attr_accessor :idx
  attr_accessor :start_idx

  def initialize(filename, idx, start_idx)

    @prediction_len = 0
    @prediction_def = "no_definition"
    @nr_hits = 0

    @filename = filename
    @idx = idx
    @start_idx = start_idx

    @image_histo_len = "#{filename}_#{@idx}_len_clusters.jpg"
    @image_plot_merge = "#{filename}_#{@idx}_match.jpg"
    @image_histo_merge = "#{filename}_#{@idx}_match_2d.jpg"

  end
  
  def print_output_console

    short_def = @prediction_def.scan(/([^ ]+)/)[0][0]

    printf "%3s|%25s|%7s|%15s|%15s|%10s|%15s|%10s|%5s\n",              
              @idx,
              short_def[0..[25,short_def.length].min],
              @nr_hits,
              @length_validation_cluster.print, 
              @length_validation_rank.print,
              @reading_frame_validation.print,
              @gene_merge_validation.print,
              @duplication.print,
              @orf.print

  end

  def print_output_file_yaml
    file_yaml = "#{@filename}.yaml"
    if @idx != @start_idx
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

    # if it's the first time I write in the html file
    if @idx == @start_idx
      header = "<html><head>
                     <title>Gene Validation Result</title>
                     <script language=\"javascript\"> 

                     function showDiv(toggle){
                       var button = document.getElementById(toggle)
                       if(button.style.display == \"block\"){
                          button.style.display = \"none\";
                       }
                       else{
                          button.style.display = \"block\";
                       }
                     }
                  </script>             
                  </head>
                  <body>
                      <table border=\"1\" cellpadding=\"5\" cellspacing=\"0\">
                                <tr bgcolor = #E8E8E8>
                                        <th></th>
                                        <th>No.</th>
                                        <th width=100>Description</th>
                                        <th>No_Hits</th>
                                        <th>Valid_Length(Cluster)</th>
                                        <th>Valid_Length(Rank)</th>
                                        <th>Valid_Reading_Frame</th>
                                        <th>Gene_Merge(slope)</th>
                                        <th>Duplication</th>
                                        <th width = 200 style=\"white-space:nowrap\"> ORFs</th>
                                </tr>"                  
      
      File.open("#{@filename}.html", "w+") do |f|
        f.write(header)
      end

    end

    toggle = "toggle#{@idx}"

    output = "<tr bgcolor=#{color}> 
	      <td><button type=button name=answer onclick=showDiv('#{toggle}')>Show/Hide Plots</button></td> 
	      <td>#{@idx}</td>
	      <td>#{@prediction_def}</td>
	      <td>#{@nr_hits}</td>
	      <td bgcolor=#{@length_validation_cluster.color}>#{@length_validation_cluster.print}</td>
	      <td bgcolor=#{@length_validation_rank.color}>#{@length_validation_rank.print}</td>
	      <td bgcolor=#{@reading_frame_validation.color}>#{@reading_frame_validation.print}</td>
	      <td bgcolor=#{@gene_merge_validation.color}>#{@gene_merge_validation.print}</td>
	      <td bgcolor=#{@duplication.color}>#{@duplication.print}</td>
              <td bgcolor=#{@orf.color} width = 200 style=\"white-space:nowrap\">#{@orf.print}</td>
	      </tr>

	      <tr bgcolor=#{color}>
	      <td  colspan=10>
              <div id=#{toggle} style='display:none'>

              <img src=#{image_histo_len.scan(/\/([^\/]+)$/)[0][0]} height=400>
	      <img src=#{image_plot_merge.scan(/\/([^\/]+)$/)[0][0]} height=400>
              <img src=#{image_histo_merge.scan(/\/([^\/]+)$/)[0][0]} height=400>
              </div>					
	      </td>
	      </tr>"
    File.open("#{@filename}.html", "a") do |f|
      f.write(output)
    end  
  end
end
