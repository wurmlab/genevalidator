
TabularEntry = Struct.new(:filename, :type, :title, :footer, :xtitle, :ytitle, :aux1, :aux2)

##
# This class parses the tabular output of BLAST (outfmt 6) 
class TabularParser

  attr_reader :content
  attr_reader :content_iterator
  attr_reader :format
  attr_reader :type
  attr_reader :column_names
  attr_reader :query_id_idx
  attr_reader :hit_id_idx

  ##
  #+content+ : String with the tabular BLAST output
  def initialize (content, format, type)
    @content = content.gsub(/#.*\n/,"")
    @content_iterator = @content
    if format == nil
      format = "qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore"
    else 
      @format = format.gsub(/[-\d]/,"")
    end
    @column_names = format.split(/[ ,]/)
    @type = type
    @query_id_idx = @column_names.index("qseqid")
    @hit_id_idx = @column_names.index("sseqid")

  end 

  def has_next
    return @content_iterator.length > 0
  end
 
  #Returns the next query output
  def next
    unless has_next
      return nil
    end

    # get current query id
    first_row = @content_iterator.scan(/([^\n]*)\n/)
    query_id = first_row.join().split("\t")[query_id_idx]
    hits = @content_iterator.scan(/[^\n]*#{query_id.gsub("|","\|").gsub(".","\.")}[^\n]*/)

    next_query = @content_iterator.index("#{hits[hits.length-1]}") + hits[hits.length-1].length + 1  
    @content_iterator =  @content_iterator[next_query..@content_iterator.length-1]

    hit_list = []
    hits = hits.map{|hit| hit.split("\t")}

    # for each hit 
    hits.group_by{|hit| hit[@hit_id_idx]}.each do |idx, hit|
      hit_seq = Sequence.new
      column_names.each_with_index do |column, i|
        hit_seq.init_tabular_attribute(column, hit[0][i])
      end

      # take all hsps
      hsps = hits.select{|hit| hit[@hit_id_idx] == idx}
      # for each hsp fill the Hsp structure
      hsps.each do |hsp_array|
        hsp = Hsp.new
        column_names.each_with_index do |column, i|
          hsp.init_tabular_attribute(column, hsp_array[i])
        end
        hit_seq.hsp_list.push(hsp)
      end 
      hit_seq.seq_type = @type
      hit_list.push(hit_seq)

    end 

    return hit_list

  end

end
