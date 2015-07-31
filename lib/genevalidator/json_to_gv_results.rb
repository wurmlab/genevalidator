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

      def init
        @opt    = opt
        @config = {
          html_path: "#{@opt[:json_file]}.html",
          plot_dir: "#{@opt[:json_file]}.html/files/json",
          aux: File.expand_path(File.join(File.dirname(__FILE__), '../../aux')),
          filename: File.basename(@opt[:json_file]),
          output_max: 2500,
          run_no: 0
        }
        @json_array = load_json_file
      end

      def run
        init
        GeneValidator.create_output_folder(@config[:html_path], @config[:aux])
        @json_array.each do |row|
          @config[:run_no] += 1
          create_json_file(row)
          output_html = output_filename
          generate_html_header(output_html) unless File.exist?(output_html)
          generate_html_query(output_html, row)
        end
        html_footer
        calculate_overall_score
      end

      def load_json_file
        json_contents = File.read(File.expand_path(@opt[:json_file]))
        JSON.load(json_contents)
      end

      def create_json_file(row)
        @json_file = File.join(@config[:plot_dir],
                               "#{@config[:filename]}_#{row['idx']}.json")
        File.open(@json_file, 'w') { |f| f.write(row.to_json) }
      end

      def output_filename
        i = (@config[:run_no].to_f / @config[:output_max]).ceil
        File.join(@config[:html_path], "results#{i}.html")
      end

      def generate_html_header(output_html)
        return if File.exist?(output_html)
        json_header_template = File.join(@config[:aux], 'json_header.erb')
        template_contents    = File.open(json_header_template, 'r').read
        erb                  = ERB.new(template_contents, 0, '>')
        File.open(output_html, 'w+') { |f| f.write(erb.result(binding)) }
      end

      def generate_html_query(output_html, row)
        @row = row
        json_query_template = File.join(@config[:aux], 'json_query.erb')
        template_contents   = File.open(json_query_template, 'r').read
        erb                 = ERB.new(template_contents, 0, '>')
        File.open(output_html, 'a') { |f| f.write(erb.result(binding)) }
      end

      # Add footer to all output files
      def html_footer
        no_of_output_files = (@config[:run_no].to_f / @config[:output_max]).ceil

        output_files = []
        (1..no_of_output_files).each { |i| output_files << "results#{i}.html" }

        write_html_footer(no_of_output_files, output_files)
      end

      def write_html_footer(no_of_output_files, output_files)
        turn_off_automated_sorting
        json_footer_template = File.join(@config[:aux], 'json_footer.erb')
        template_contents    = File.open(json_footer_template, 'r').read
        erb                  = ERB.new(template_contents, 0, '>')
        (1..no_of_output_files).each do |i|
          results_html = File.join(@config[:html_path], "results#{i}.html")
          File.open(results_html, 'a+') { |f| f.write(erb.result(binding)) }
        end
      end

      # By default, on page load, the results are automatically sorted by the
      # index. However since the whole idea is that users would sort by JSON,
      # this is not wanted here.
      def turn_off_automated_sorting
        script_file = File.join(@config[:html_path],
                                'files/js/genevalidator.compiled.min.js')
        original_content = File.read(script_file)
        # removes the automatic sort on page load
        updated_content = original_content.gsub(',sortList:[[0,0]]', '')
        File.open("#{script_file}.tmp", 'w') { |f| f.puts updated_content }
        FileUtils.mv("#{script_file}.tmp", script_file)
      end

      def calculate_overall_score
        scores = []
        @json_array.each { |row| scores << row['overall_score'] }
        plot_dir = File.join(@config[:html_path], 'files/json')
        less     =  generate_evaluation(scores)
        Output.create_overview_json(scores, plot_dir, less, less)
      end

      def generate_evaluation(scores)
        no_of_queries = scores.length
        good_scores = scores.count { |s| s >= 75 }
        bad_scores  = scores.count { |s| s < 75 }
        nee         = calculate_no_quries_with_no_evidence # nee = no evidence

        good_pred = (good_scores == 1) ? 'One' : "#{good_scores} are"
        bad_pred  = (bad_scores == 1) ? 'One' : "#{bad_scores} are"
        eval = 'Overall Query Score Evaluation:<br>' \
               "#{no_of_queries} predictions were validated, from which there" \
               ' were:<br>' \
               "#{good_pred} good prediction(s),<br>" \
               "#{bad_pred} possibly weak prediction(s).<br>"
        return eval if nee == 0
        eval << "#{nee} could not be evaluated due to the lack of" \
                ' evidence.<br>'
        eval
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
    end
  end
end
