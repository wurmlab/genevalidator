require 'genevalidator/exceptions'
require 'csv'

TabularEntry = Struct.new(:filename, :type, :title, :footer, :xtitle, :ytitle, :aux1, :aux2)

##
# This class parses the tabular output of BLAST (outfmt 6) 
class TabularParser

  attr_reader :lines
  attr_reader :format
  attr_reader :type
  attr_reader :column_names
  attr_reader :query_id_idx
  attr_reader :hit_id_idx

  ##
  # Initializes the object
  # +file_content+ : String with the tabular BLAST output
  # +format+: format of the tabular output (string with column sepatared by space or coma)
  # +type+: :nucleotide or :mrna
  def initialize (filename, format, type)

    file = File.open(filename, "r");
    @lines = file.each_line

    # skip the comment lines
    while CSV.parse(@lines.peek, :col_sep => "\t")[0][0].match(/#.*/) != nil
      @lines.next
    end
    
    if format == nil
      @format = "qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore"
    else 
      @format = format.gsub(/[-\d]/,"")
    end

    @column_names = @format.split(/[ ,]/)
    @type = type
    @query_id_idx = @column_names.index("qseqid")
    @hit_id_idx = @column_names.index("sseqid")
  end 

  ##
  # Jumps to the next query
  def jump_next
    begin
      # get current query id
      # search for the endline

      entry = CSV.parse(@lines.peek, :col_sep => "\t")[0]
      unless entry.length == @column_names.length
        raise InconsistentTabularFormat
      end

      query_id = entry[query_id_idx]
      while 1
        entry = CSV.parse(@lines.peek, :col_sep => "\t")[0]
        unless query_id == entry[query_id_idx]
          break;
        end
        @lines.next
      end

    rescue StopIteration => error
    end

  end

  def make_hit_list(hits)
      hit_list = []
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
            hsp.init_tabular_attribute(column, hsp_array[i], @type)
          end
          hit_seq.hsp_list.push(hsp)
        end
        # all the hits are proteins because are obtained with blastx or blastp
        hit_seq.type = :protein
        hit_list.push(hit_seq)
      end
      return hit_list
  end
 
  # Returns the next query output
  # +identifier+: +String+, the identifier of the next expected query
  # if the identifier is nil, it takes the next query
  # Output:
  # Array of +Sequence+ objects corresponding to hits
  def next(identifier = nil)
    begin
      # get current query id
      # search for the endline      

      begin
        entry = CSV.parse(@lines.peek, :col_sep => "\t")[0]
      rescue StopIteration => error
        return []
      end
      
      unless entry.length == @column_names.length
        raise InconsistentTabularFormat
      end

      query_id = entry[query_id_idx]
      if (identifier != nil and query_id != identifier)
        return []
      end
 
      hits = []

      begin
        while 1
          entry = CSV.parse(@lines.peek, :col_sep => "\t")[0] 
          unless query_id == entry[query_id_idx]
            return make_hit_list(hits)
          end

          hits << entry
          @lines.next
        end
      rescue StopIteration => error
        return make_hit_list(hits)
      end

      return make_hit_list(this)

    rescue InconsistentTabularFormat => error
      puts error.backtrace
      $stderr.print "Tabular format error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. "<<
        "Possible cause: The tabular file and the tabular header do not correspond. "<<
        "Please provide -tabular argument with the correct format of the columns\n"
      exit!
    rescue Exception => error
      $stderr.print "Tabular format error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}.\n"
      exit
    end
  end
end
