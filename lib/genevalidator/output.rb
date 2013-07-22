
require 'yaml'

class Output

  attr_accessor :prediction_len
  attr_accessor :prediction_def
  attr_accessor :nr_hits

  attr_accessor :lv_cluster
  attr_accessor :length_cluster_limits  

  attr_accessor :length_rank_score
  attr_accessor :length_rank_msg

  attr_accessor :reading_frame_validation
  attr_accessor :reading_frame_info

  attr_accessor :merged_genes_score
  attr_accessor :duplication
  attr_accessor :duplication_info

  attr_accessor :orf

  attr_accessor :filename
  attr_accessor :image_histo_len
  attr_accessor :image_plot_merge
  attr_accessor :image_histo_merge
  attr_accessor :idx

  def initialize(filename, idx)

    @prediction_len = 0
    @prediction_def = "no_definition"
    @nr_hits = 0

    @lv_cluster = "No evidence"
    @length_cluster_limits = ""
    
    @length_rank_score = ""
    @length_rank_msg = "No evidence"
    
    @reading_frame_validation = "No evidence"
    @reading_frame_info = ""

    @merged_genes_score = 0

    @duplication = "No evidence"
    @duplication_info = 0

    @orf = {}

    @filename = filename
    @idx = idx

    @image_histo_len = "#{filename}_#{@idx}_len_clusters.jpg"
    @image_plot_merge = "#{filename}_#{@idx}_match.jpg"
    @image_histo_merge = "#{filename}_#{@idx}_match_2d.jpg"

  end
  
  def print_output_console

    if @prediction_len >= @length_cluster_limits[0] and @prediction_len <= @length_cluster_limits[1]
      @lv_cluster = "YES"
    else
      @lv_cluster = "NO"
    end

    

    short_def = @prediction_def.scan(/([^ ]+)/)[0][0]
    printf "%3s|%25s|%7s|%15s|%15s|%15s|%10s|%15s|%10s|%5s\n",              
              @idx,
              short_def[0..[25,short_def.length].min],
              @nr_hits,
              "#{@prediction_len} #{@length_cluster_limits} #{@lv_cluster}", 
              @length_rank_msg, @length_rank_score, 
              @reading_frame_validation,
              @merged_genes_score.round(2), "#{@duplication}(pval=#{@duplication_info.round(2)})",
              @orf.map{|elem| elem[1].length}.reduce(:+)

  end

  def print_output_file_yaml
    file_yaml = "#{@filename}.yaml"
    if @idx != 1
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

    # color length validation cluster
    if @lv_cluster == "NO"
      color_lvc = "red"
    else
      color_lvc = color
    end
 
    # color length validation rank
    if @length_rank_score < 0.2
      color_lvr = "red"
    else
      color_lvr = color
    end

    rf_html = ""
    @reading_frame_info.map{|elem| rf_html<<"#{elem[0]}:#{elem[1].to_s}; "}
    # color reading frame validation
    if @reading_frame_validation != "VALID"
      color_rf = "red"
    else
      color_rf = color
    end

    # color gene merge validation
    if @merged_genes_score > 0.4 and @merged_genes_score < 1.2
      status_merge = "YES"
      color_merge = "red"
    else
      status_merge = "NO"
      color_merge = color
    end

    # color duplication validation
    if @duplication == "YES"
      color_dup = "red"
    else
      color_dup = color
    end

    # color orf
    if @orf.length > 1
      color_orf = "red"
    else
      color_orf = color
    end

    orf_html = ""    
    unless @orf.length == 0
      @orf.map{|elem| orf_html<<"#{elem[0]}:#{elem[1].to_s}<br>"}
    else
      orf_html = "No evidence"
    end

    toggle = "toggle#{@idx}"

    output = "<tr bgcolor=#{color}> 
	      <td><button type=button name=answer onclick=showDiv('#{toggle}')>Show/Hide Plots</button></td> 
	      <td>#{@idx}</td>
	      <td>#{@prediction_def}</td>
	      <td>#{@nr_hits}</td>
	      <td bgcolor=#{color_lvc}>#{@prediction_len} #{@length_cluster_limits} #{@lv_cluster}</td>
	      <td bgcolor=#{color_lvr}>#{@length_rank_score}(#{@length_rank_msg})</td>
	      <td bgcolor=#{color_rf}>#{@reading_frame_validation}(#{rf_html})</td>
	      <td bgcolor=#{color_merge}>#{status_merge}(slope=#{@merged_genes_score.round(2)})</td>
	      <td bgcolor=#{color_dup}>#{@duplication}(pval=#{@duplication_info.round(4)})</td>
              <td width = 200 style=\"white-space:nowrap\" bgcolor=#{color_orf}>#{orf_html}</td>
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
