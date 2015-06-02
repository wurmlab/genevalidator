require 'genevalidator/exceptions'
require 'csv'

#
module GeneValidator
  TabularEntry = Struct.new(:filename, :type, :title, :footer, :xtitle,
                            :ytitle, :aux1, :aux2)
  ##
  # This class parses the tabular output of BLAST (outfmt 6 & 7)
  class TabularParser
    extend Forwardable
    def_delegators GeneValidator, :opt, :config

    attr_reader :rows
    attr_reader :tab_results
    attr_reader :column_names
    attr_reader :type

    ##
    # Initializes the object
    def initialize(format = opt[:blast_tabular_options], type = config[:type])
      @opt          = opt
      @config       = config
      @column_names = format.gsub(/[-\d]/, '').split(/[ ,]/)
      @type         = type
      @tab_results  = []
      @rows         = nil
    end

    ##
    #
    def analayse_tabular_file(filename = @opt[:blast_tabular_file])
      file         = File.read(filename)
      lines        = CSV.parse(file, col_sep: "\t",
                                     skip_lines: /^#/,
                                     headers: @column_names)
      lines.each do |line|
        @tab_results << line.to_hash
      end
      @rows = @tab_results.to_enum
    end

    ##
    # move to next query
    def next
      current_entry = @rows.peek['qseqid']
      loop do
        entry = @rows.peek['qseqid']
        @rows.next
        break unless entry == current_entry
      end
      # rescue StopIteration
    end

    alias move_to_next_query next

    ##
    #
    def parse_next(query_id = nil)
      current_id = @rows.peek['qseqid']
      return [] if !query_id.nil? && current_id != query_id
      hits = @tab_results.partition { |h| h['qseqid'] == current_id }[0]
      hit_seq = initialise_classes(hits)
      move_to_next_query
      hit_seq
    rescue StopIteration
      return []
    end

    ##
    #
    def initialise_classes(hits)
      hit_list = []
      grouped_hits = hits.group_by { |row| row['sseqid'] }

      grouped_hits.each do |query_id, row|
        hit_seq = Sequence.new
        hit_seq.init_tabular_attribute(row[0])

        initialise_all_hsps(query_id, hits, hit_seq)

        hit_seq.type = :protein
        hit_list.push(hit_seq)
      end
      hit_list
    end

    ##
    #
    def initialise_all_hsps(current_query_id, hits, hit_seq)
      hsps = hits.select { |row| row['sseqid'] == current_query_id }
      hsps.each do |row|
        hsp = Hsp.new
        hsp.init_tabular_attribute(row, type)
        hit_seq.hsp_list.push(hsp)
      end
    end
  end
end
