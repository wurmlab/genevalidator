require 'genevalidator'
require 'genevalidator/output'
require 'fileutils'

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
        template_contents    = File.open(json_query_template, 'r').read
        erb                  = ERB.new(template_contents, 0, '>')
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

      # Since the whole idea is that users would sort by
      def turn_off_automated_sorting
        script_file = File.join(@config[:html_path], 'files/js/script.js')
        temp_file   = File.join(@config[:html_path], 'files/js/script.temp.js')
        File.open(temp_file, 'w') do |out_file|
          out_file.puts File.readlines(script_file)[0..23].join
          out_file.puts '}'
          out_file.puts File.readlines(script_file)[26..-1].join
        end
        FileUtils.mv(temp_file, script_file)
      end
    end
  end
end
