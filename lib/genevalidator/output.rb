
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
  attr_accessor :image_orfs
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
    @image_orfs = "#{filename}_#{@idx}_orfs.jpg"

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

    if @length_validation_cluster.color == "red" or
       @length_validation_rank.color == "red" or
       @reading_frame_validation.color == "red" or
       @gene_merge_validation.color == "red" or
       @duplication.color == "red" or
       @orf.color == "red"
      icon = "<b>&#33;</b>"
      bg_icon = "red"
    else
      icon = "&#10003;"
      bg_icon = "white"
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
                      <table border=\"1\" cellpadding=\"5\" cellspacing=\"0\" width = 1650>
                                <tr bgcolor = #E8E8E8>
                                        <th></th>
                                        <th></th>
                                        <th>No.</th>
                                        <th width=100 title=\"FASTA Header of the query\">Description</th>
                                        <th title=\"Number of hits found by BLAST.\">No. Hits</th>
                                        <th title=\"Check whether the prediction length fits the most of the BLAST hit lengths, by 1D hierarchical clusterization.\">Valid Length(Cluster)</th>
                                        <th title=\"Check whether the rank of the prediction length lies among 80% of all the BLAST hit lengths.\">Valid Length(Rank)</th>
                                        <th title=\"Check whether the reading frame shifts.\">Valid Reading Frame</th>
                                        <th title=\"Check whether there BLAST hits make evidence about a merge of two genes that cover the predicted gene.\">Gene Merge(slope)</th>
                                        <th title=\"Check whether there is a duplicated subsequence in the predicted gene.\">Duplication</th>
                                        <th title=\"Check whether there is a single main Open Reading Frame in the predicted gene.\" style=\"white-space:nowrap\"> ORF Test</th>
                                        <th title=\"Overall evaluation based on all validation tests\" > Overall Evaluation</th>
                                </tr>"                  
      
      File.open("#{@filename}.html", "w+") do |f|
        f.write(header)
      end

    end

    toggle = "toggle#{@idx}"

    output = "<tr bgcolor=#{'white'}> 
	      <td><button type=button name=answer onclick=showDiv('#{toggle}')>Show/Hide Plots</button></td> 
              <td bgcolor=#{bg_icon}>#{icon}</td>
              <td>#{@idx}</td>
	      <td>#{@prediction_def}</td>
	      <td>#{@nr_hits}</td>
	      <td bgcolor=#{@length_validation_cluster.color}>#{@length_validation_cluster.print}</td>
	      <td bgcolor=#{@length_validation_rank.color}>#{@length_validation_rank.print}</td>
	      <td bgcolor=#{@reading_frame_validation.color}>#{@reading_frame_validation.print}</td>
	      <td bgcolor=#{@gene_merge_validation.color}>#{@gene_merge_validation.print}</td>
	      <td bgcolor=#{@duplication.color}>#{@duplication.print}</td>
              <td bgcolor=#{@orf.color} style=\"white-space:nowrap\">#{@orf.print}</td>
              <td style=\"white-space:nowrap\">...</td>
	      </tr>

	      <tr bgcolor=#{color}>
	      <td  colspan=12>
              <div id=#{toggle} style='display:none'>

              <img src=#{image_histo_len.scan(/\/([^\/]+)$/)[0][0]} height=400>
	      <img src=#{image_plot_merge.scan(/\/([^\/]+)$/)[0][0]} height=400>
              <img src=#{image_histo_merge.scan(/\/([^\/]+)$/)[0][0]} height=400>"
              if @orf.print != "-"
                output += "<img src=#{image_orfs.scan(/\/([^\/]+)$/)[0][0]} height=400>"
              end
              output+="</div></td></tr>"

    File.open("#{@filename}.html", "a") do |f|
      f.write(output)
    end  
  end
end
