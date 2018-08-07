require 'erb'
require 'fileutils'
require 'forwardable'
require 'json'

require 'genevalidator'
require 'genevalidator/output'
require 'genevalidator/version'

module GeneValidator
  # produce GV results from a JSON previously produced from GV
  class JsonToGVResults
    class << self
      extend Forwardable
      def_delegators GeneValidator, :opt

      def run
        init
        write_html_output
        @json_array.each do |row|
          @config[:run_no] += 1
          create_row_json_plot_files(row)
        end
        calculate_overall_score
      end

      private

      def init
        @opt          = opt
        @config       = { output_max: 2500, run_no: 0 }
        @dirs         = GeneValidator.setup_dirnames(@opt[:json_file])
        @js_plots_dir = File.join(@dirs[:output_dir], 'html_files/json')
        @json_array = load_json_file
      end

      def load_json_file
        json_contents = File.read(File.expand_path(@opt[:json_file]))
        JSON.parse(json_contents)
      end

      def write_html_output
        return unless @opt[:output_formats].include? 'html'
        @all_html_fnames = all_html_filenames
        @json_array.each_slice(@config[:output_max]).with_index do |data, i|
          output_html       = html_output_filename(i)
          template_file     = File.join(@dirs[:aux_dir], 'from_json_to_html.erb')
          template_contents = File.open(template_file, 'r').read
          erb               = ERB.new(template_contents, 0, '>')
          File.open(output_html, 'w+') { |f| f.write(erb.result(binding)) }
        end
      end

      def html_output_filename(result_part_index)
        multiple_files_needed = @json_array.length < @config[:output_max]
        part = multiple_files_needed ? '' : "_#{result_part_index + 1}"
        fname = File.join(@dirs[:output_dir], "#{@dirs[:filename]}_results")
        fname + part + '.html'
      end

      def all_html_filenames
        result_parts = (@json_array.length / @config[:output_max]).ceil
        (0..result_parts).map { |idx| html_output_filename(idx) }
      end

      # By default, on page load, the results are automatically sorted by the
      # index. However since the whole idea is that users would sort by JSON,
      # this is not wanted here.
      def turn_off_automated_sorting
        js_file = File.join(@dirs[:output_dir], 'files/js/gv.compiled.min.js')
        original_content = File.read(js_file)
        # removes the automatic sort on page load
        updated_content = original_content.gsub(',sortList:[[0,0]]', '')
        File.open("#{script_file}.tmp", 'w') { |f| f.puts updated_content }
        FileUtils.mv("#{script_file}.tmp", script_file)
      end

      def calculate_overall_score
        scores_from_json = @json_array.map { |row| row['overall_score'] }
        quartiles = scores_from_json.all_quartiles
        min_hits = @json_array.count { |e| e['no_hits'] < @opt[:min_blast_hits] }
        scores = set_up_scores(scores_from_json, quartiles, min_hits)
        overall_eval = Output.calculate_overview(scores)
        Output.create_overview_json_for_html(overall_eval, scores_from_json,
                                             @opt, @dirs)
      end

      def set_up_scores(scores_from_json, quartiles, insufficient_BLAST_hits)
        {
          scores: scores_from_json,
          no_queries: scores_from_json.length,
          good_scores: scores_from_json.count { |s| s >= 75 },
          bad_scores: scores_from_json.count { |s| s < 75 },
          nee: calculate_no_quries_with_no_evidence, # nee = no evidence
          no_mafft: 0,
          no_internet: 0,
          map_errors: Hash.new(0),
          run_time: Hash.new(Pair1.new(0, 0)),
          first_quartile_of_scores: quartiles[0],
          second_quartile_of_scores: quartiles[1],
          third_quartile_of_scores: quartiles[2],
          insufficient_BLAST_hits: insufficient_BLAST_hits
        }
      end

      # calculate number of queries that had warnings for all validations.
      def calculate_no_quries_with_no_evidence
        all_warnings = 0
        @json_array.each do |row|
          status = row['validations'].map { |_, h| h['status'] }
          if status.count { |r| r == 'warning' } == status.length
            all_warnings += 1
          end
        end
        all_warnings
      end

      def create_row_json_plot_files(row)
        fname = "#{@dirs[:filename]}_#{row['idx']}.json"
        @json_file = File.join(@js_plots_dir, fname)
        File.open(@json_file, 'w') { |f| f.write(row.to_json) }
      end
    end
  end
end
