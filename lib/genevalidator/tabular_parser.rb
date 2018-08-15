require 'csv'
require 'forwardable'

require 'genevalidator/exceptions'
require 'genevalidator/hsp'
require 'genevalidator/query'

module GeneValidator
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
      lines = CSV.parse(File.read(filename), col_sep: "\t", skip_lines: /^#/,
                                             headers: @column_names)
      lines.map(&:to_hash)
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
      []
    end

    private

    ##
    #
    def initialise_classes(current_id, tab_results = @tab_results)
      hits = tab_results.partition { |h| h['qseqid'] == current_id }[0]
      grouped_hits = hits.group_by { |row| row['sseqid'] }

      grouped_hits.map do |_query_id, rows|
        hit_seq = Query.new
        hit_seq.init_tabular_attribute(rows[0])
        hit_seq.hsp_list = rows.map { |row| Hsp.new(tabular_input: row) }
        hit_seq.type = :protein
        hit_seq
      end
    end
  end
end
