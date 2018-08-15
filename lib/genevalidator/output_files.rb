require 'csv'
require 'slim'
require 'fileutils'
require 'forwardable'
require 'json'

require 'genevalidator/version'

module GeneValidator
  # A Class for creating output files
  class OutputFiles
    extend Forwardable
    def_delegators GeneValidator, :opt, :config, :dirs, :overview

    def initialize()
      @config    = config
      @opt       = opt
      @dirs      = dirs
      @overview  = overview
      @json_data = @config[:json_output]
    end

    def write_html(overall_eval)
      return unless @opt[:output_formats].include? 'html'
      @all_html_fnames = all_html_filenames
      @json_data.each_slice(@config[:output_max]).with_index do |data, i|
        @json_data_section = data
        template_file = File.join(@dirs[:aux_dir], 'gv_results.slim')
        template_contents = File.open(template_file, 'r').read
        html_output = Slim::Template.new { template_contents }.render(self)
        File.open(@all_html_fnames[i], 'w') { |f| f.write(html_output) }
      end
      create_overview_json_file(overall_eval)
    end

    def write_json
      return unless @opt[:output_formats].include? 'json'
      File.open(@dirs[:json_file], 'w') { |f| f.write(@json_data.to_json) }
    end

    def write_csv
      return unless @opt[:output_formats].include? 'csv'
      File.open(@dirs[:csv_file], 'a') do |file|
        file.puts csv_header.join(',')
        @json_data.each do |data|
          short_def = data[:definition].split(' ')[0]
          line = [data[:idx], data[:overall_score], short_def, data[:nr_hits]]
          line += data[:validations].values.map { |e| e[:print] }
                                    .each { |e| e.gsub!('&nbsp;', ' ') }
          line.map { |e| e.gsub!(',', ' -') if e.is_a? String }
          file.puts line.join(',')
        end
      end
    end

    def write_summary
      return unless @opt[:output_formats].include? 'summary'
      data = generate_summary_data
      File.open(@dirs[:summary_file], 'w') do |f|
        f.write data.map(&:to_csv).join
      end
    end

    def print_best_fasta
      return unless @opt[:select_single_best]
      top_data = @json_data.max_by { |e| [e[:overall_score], e[:no_hits]] }
      query = GeneValidator.extract_input_fasta_sequence(top_data[:idx])
      File.open(@dirs[:fasta_file], 'w') { |f| f.write(query) }
      puts query
    end

    private

    def all_html_filenames
      result_parts = (@json_data.length / @config[:output_max]).ceil
      (0..result_parts).map do |idx|
        multiple_files_needed = @json_data.length < @config[:output_max]
        part = multiple_files_needed ? '' : "_#{idx + 1}"
        fname = File.join(@dirs[:output_dir], "#{@dirs[:filename]}_results")
        fname + part + '.html'
      end
    end

    # By default, on page load, the results are automatically sorted by the
    # index. However since the whole idea is that users would sort by JSON,
    # this is not wanted here.
    def turn_off_automated_sorting
      js_file = File.join(@dirs[:output_dir], 'html_files/js/gv.compiled.min.js')
      original_content = File.read(js_file)
      # removes the automatic sort on page load
      updated_content = original_content.gsub(',sortList:[[0,0]]', '')
      File.open("#{script_file}.tmp", 'w') { |f| f.puts updated_content }
      FileUtils.mv("#{script_file}.tmp", script_file)
    end

    def create_overview_json_file(overall_eval)
      evaluation = overall_eval.flatten.join('<br>').gsub("'", %q(\\\'))
      less = overall_eval[0].join('<br>')
      hash = overview_html_hash(evaluation, less)
      json = File.join(@dirs[:json_dir], 'overview.json')
      File.open(json, 'w') { |f| f.write hash.to_json }
    end

    # make the historgram with the resulted scores
    def overview_html_hash(evaluation, less)
      data = [@overview[:scores].group_by { |a| a }.map do |k, vs|
        { 'key': k, 'value': vs.length, 'main': false }
      end]
      { data: data, type: :simplebars, aux1: 10, aux2: '',
        title: 'Overall GeneValidator Score Evaluation', footer: '',
        xtitle: 'Validation Score', ytitle: 'Number of Queries',
        less: less, evaluation: evaluation }
    end

    def csv_header
      header = %w[AnalysisNumber GVScore Identifier NumberOfHits]
      header += @json_data[0][:validations].keys
      header
    end

    def generate_summary_data
      [
        ['num_predictions', @overview[:no_queries]],
        ['num_good_predictions', @overview[:good_scores]],
        ['num_bad_predictions', @overview[:bad_scores]],
        ['num_predictions_with_insufficient_blast_hits',
         @overview[:insufficient_BLAST_hits]],
        ['first_quartile_of_scores', @overview[:first_quartile_of_scores]],
        ['second_quartile_of_scores', @overview[:second_quartile_of_scores]],
        ['third_quartile_of_scores', @overview[:third_quartile_of_scores]]
      ]
    end
  end
end
