require 'csv'
require 'forwardable'

require 'genevalidator/exceptions'
require 'genevalidator/hsp'
require 'genevalidator/query'

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
    def initialize(tab_file = opt[:blast_tabular_file],
                   format = opt[:blast_tabular_options], type = config[:type])
      @column_names = format.gsub(/[-\d]/, '').split(/[ ,]/)
      @type         = type
      @tab_results  = analayse_tabular_file(tab_file)
      @rows         = @tab_results.to_enum
    end

    ##
    #
    def analayse_tabular_file(filename)
      results = []
      file    = File.read(filename)
      lines   = CSV.parse(file, col_sep: "\t", skip_lines: /^#/,
                                headers: @column_names)
      lines.each do |line|
        results << line.to_hash
      end
      results
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
    end

    alias move_to_next_query next

    ##
    #
    def parse_next(query_id = nil)
      current_id = @rows.peek['qseqid']
      return [] if !query_id.nil? && current_id != query_id
      hit_seq = initialise_classes(current_id)
      move_to_next_query
      hit_seq
    rescue StopIteration
      return []
    end

    private

    ##
    #
    def initialise_classes(current_id, tab_results = @tab_results)
      hits = tab_results.partition { |h| h['qseqid'] == current_id }[0]
      hit_list = []
      grouped_hits = hits.group_by { |row| row['sseqid'] }

      grouped_hits.each do |query_id, row|
        hit_seq = Query.new
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
        hsp.init_tabular_attribute(row)
        hit_seq.hsp_list.push(hsp)
      end
    end
  end
end
