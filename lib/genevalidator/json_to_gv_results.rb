require 'forwardable'
require 'json'

require 'genevalidator'
require 'genevalidator/version'

module GeneValidator
  # produce GV results from a JSON previously produced from GV
  class JsonToGVResults
    class << self
      extend Forwardable
      def_delegators GeneValidator, :opt, :config, :dirs

      def init(opt)
        GeneValidator.opt = opt
        GeneValidator.config = { output_max: 2500, run_no: 0,
                                 json_output: load_json_file }
        GeneValidator.dirs = GeneValidator.setup_dirnames(opt[:json_file])
      end

      def run
        warn '==> Parsing input JSON results'
        print_console_header(config[:json_output][0])
        config[:json_output].each do |row|
          print_output_console(row)
          create_row_json_plot_files(row)
        end
        GeneValidator.produce_output
      end

      def print_console_header(first_row)
        return unless opt[:output_formats].include? 'stdout'
        return if config[:console_header_printed]
        config[:console_header_printed] = true
        warn '' # blank line
        c_fmt = "%3s\t%5s\t%20s\t%7s\t"
        print format(c_fmt, 'No', 'Score', 'Identifier', 'No_Hits')
        puts first_row[:validations].keys.join("\t")
      end

      def print_output_console(row)
        return unless opt[:output_formats].include? 'stdout'
        c_fmt = "%3s\t%5s\t%20s\t%7s\t"
        short_def = row[:definition].split(' ')[0]
        print format(c_fmt, row[:idx], row[:overall_score], short_def,
                     row[:no_hits])
        puts row[:validations].values.map { |e| e[:print] }.join("\t")
                              .gsub('&nbsp;', ' ')
      end

      private

      def load_json_file
        json_contents = File.read(File.expand_path(opt[:json_file]))
        JSON.parse(json_contents, symbolize_names: true)
      end

      def create_row_json_plot_files(row)
        config[:run_no] += 1
        fname = "#{dirs[:filename]}_#{row[:idx]}.json"
        json_file = File.join(dirs[:json_dir], fname)
        File.open(json_file, 'w') { |f| f.write(row.to_json) }
      end
    end
  end
end
