
TabularEntry = Struct.new(:filename, :type, :title, :footer, :xtitle, :ytitle, :aux1, :aux2)

##
# This class parses the tabular output of BLAST (outfmt 6) 
class TabularParser

  attr_reader :content
  attr_reader :iterator
  attr_reader :cnt

  ##
  #+content+ : String with the tabular BLAST output
  def initialize content
    @content = content
    @iterator = content
    @cnt = 2
  end 

  def has_next
    @cnt -= 1
    return @cnt > 0
    
  end
 
  #Returns the next query output
  def next
    query_id = @iterator.scan(/([^\s]*)\s.*/)[0][0]
    puts query_id
    hits = @iterator.scan(/#{query_id.gsub("|","\|").gsub(".","\.")}(.*)\n/)

=begin    

    hit = hit.scan(/([^\s]*)\s.*/)[0][0]
    hsps = hit.scan(/#{identifier.gsub("|","\|").gsub(".","\.")}(.*)\n/)

         predicted_seq.xml_length = iter.field("Iteration_query-len").to_i
      if @type == :nucleotide
        predicted_seq.xml_length /= 3
      end
      predicted_seq.definition = iter.field("Iteration_query-def")

      # parse blast the xml output and get the hits
      iter.each do | hit |

        seq = Sequence.new

        seq.xml_length = hit.len.to_i
        seq.seq_type = @type
        seq.database = iter.field("BlastOutput_db")
        seq.id = hit.hit_id
        seq.definition = hit.hit_def
        seq.accession_no = hit.accession

        species_regex = hit.hit_def.scan(/\[([^\]\[]+)\]$/)
        if species_regex[0] == nil
          seq.species = "Unknown"
        else
          seq.species = species_regex[0][0]
        end

        # get all high-scoring segment pairs (hsp)
        hsps = []
        hit.hsps.each do |hsp|
          current_hsp = Hsp.new
          current_hsp.bit_score = hsp.bit_score.to_i
          current_hsp.hsp_score = hsp.score.to_i
          current_hsp.hsp_evalue = hsp.evalue.to_i

          current_hsp.hit_from = hsp.hit_from.to_i
          current_hsp.hit_to = hsp.hit_to.to_i
          current_hsp.match_query_from = hsp.query_from.to_i
          current_hsp.match_query_to = hsp.query_to.to_i

          if @type == :nucleotide
            current_hsp.match_query_from /= 3
            current_hsp.match_query_to /= 3
          end
=end
    #@iterator[r..r+10000].scan(/(>[^>]*).*/)[0] != nil
  end

  def parse_tabular_output
    
  end  

end
