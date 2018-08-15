require 'fileutils'
require 'bio-blastxmlparser'

require 'genevalidator/arg_validation'
require 'genevalidator/blast'
require 'genevalidator/exceptions'
require 'genevalidator/get_raw_sequences'
require 'genevalidator/json_to_gv_results'
require 'genevalidator/output'
require 'genevalidator/output_files'
require 'genevalidator/tabular_parser'
require 'genevalidator/validation'

# Top level module / namespace.
module GeneValidator
  class << self
    attr_accessor :opt, :config, :overview, :dirs
    attr_reader :raw_seq_file_index
    attr_reader :raw_seq_file_load
    # array of indexes for the start offsets of each query in the fasta file
    attr_reader :query_idx
    attr_accessor :mutex, :mutex_array

    def init(opt, start_idx = 1)
      warn '==> Analysing input arguments'
      @opt = opt
      GVArgValidation.validate_args # validates @opt
      number_of_sequences = index_the_input

      @config = setup_config(start_idx, number_of_sequences)
      @dirs = setup_dirnames(@opt[:input_fasta_file])

      @mutex       = Mutex.new
      @mutex_array = Mutex.new

      resume_from_previous_run(opt[:resumable]) unless opt[:resumable].nil?

      RawSequences.index_raw_seq_file if @opt[:raw_sequences]
    end

    ##
    # Parse the blast output and run validations
    def run
      # Run BLAST on all sequences (generates @opt[:blast_xml_file])
      # if no BLAST OUTPUT file provided...
      unless @opt[:blast_xml_file] || @opt[:blast_tabular_file]
        blast_xml_fname = "#{dirs[:filename]}.blast_xml"
        opt[:blast_xml_file] = File.join(dirs[:tmp_dir], blast_xml_fname)
        BlastUtils.run_blast_on_input_file
      end
      # Obtain fasta file of all BLAST hits if running align or dup validations
      if @opt[:validations].include?('align') ||
         @opt[:validations].include?('dup')
        RawSequences.run unless @opt[:raw_sequences]
      end
      # Run Validations
      iterator = parse_blast_output_file
      Validations.new.run_validations(iterator)
      produce_output
      print_directories_locations
    end

    ##
    # Params:
    # +output+: filename or stream, according to the type
    # +type+: file or stream
    # Returns an iterator..
    def parse_blast_output_file
      if @opt[:blast_xml_file]
        Bio::BlastXMLParser::XmlIterator.new(@opt[:blast_xml_file]).to_enum
      else
        TabularParser.new
      end
      ## TODO: Add a Rescue statement - e.g. if unable to create the Object...
    end

    # Also called by json_to_gv script
    def setup_dirnames(input_file)
      fname = File.basename(input_file, File.extname(input_file))
      out_dir = setup_output_dir(fname)
      { filename: fname,
        output_dir: out_dir,
        tmp_dir: File.join(out_dir, 'tmp'),
        json_dir:  File.join(out_dir, 'tmp/json'),
        html_file: File.join(out_dir, "#{fname}_results*.html"),
        json_file: File.join(out_dir, "#{fname}_results.json"),
        csv_file: File.join(out_dir, "#{fname}_results.csv"),
        summary_file: File.join(out_dir, "#{fname}_summary.csv"),
        fasta_file: File.join(out_dir, "#{fname}_results.fa"),
        aux_dir: File.expand_path('../aux', __dir__) }
    end

    def extract_input_fasta_sequence(index)
      start_offset = @query_idx[index + 1] - @query_idx[index]
      end_offset = @query_idx[index]
      IO.binread(@opt[:input_fasta_file], start_offset, end_offset)
    end

    def produce_output
      @overview = Output.generate_overview(@config[:json_output],
                                           @opt[:min_blast_hits])
      eval_text = Output.generate_evaluation_text(@overview)
      Output.print_console_footer(eval_text, @opt)

      output_files = OutputFiles.new
      output_files.write_json
      output_files.write_html(eval_text)
      output_files.write_csv
      output_files.write_summary
      output_files.print_best_fasta
    end

    private

    def setup_config(start_idx, seq_length)
      {
        idx: 0,
        start_idx: start_idx,

        type: BlastUtils.guess_sequence_type_from_input_file,

        json_output: Array.new(seq_length),
        run_no: 0,
        output_max: 2500 # max no. of queries in the output html file
      }
    end

    ##
    # Creates the output folder and copies the auxiliar folders to this folder
    def setup_output_dir(fname)
      dir_name = "#{fname}_" + Time.now.strftime('%Y_%m_%d_%H_%M_%S')
      default_outdir = File.join(Dir.pwd, dir_name)
      output_dir = @opt[:output_dir].nil? ? default_outdir : @opt[:output_dir]
      assert_output_dir_does_not_exist(output_dir)
      Dir.mkdir(output_dir)
      Dir.mkdir(File.join(output_dir, 'tmp'))
      cp_html_files(output_dir)
      output_dir
    end

    def assert_output_dir_does_not_exist(output_dir)
      return unless Dir.exist?(output_dir)
      FileUtils.rm_r(output_dir) if @opt[:force_rewrite]
      return if @opt[:force_rewrite]
      warn "The output directory (#{output_dir}) already exists."
      warn ''
      warn 'Please remove this directory before continuing.'
      warn 'Alternatively, you rerun GeneValidator with the `--force` argument,'
      warn 'which rewrites over any previous output.'
      exit 1
    end

    def cp_html_files(output_dir)
      if @opt[:output_formats].include? 'html'
        aux_files = File.expand_path('../aux/html_files/', __dir__)
        FileUtils.cp_r(aux_files, output_dir)
        FileUtils.ln_s(File.join('..', 'html_files', 'json'),
                       File.join(output_dir, 'tmp', 'json'))
      else
        Dir.mkdir(File.join(output_dir, 'tmp', 'json'))
      end
    end

    ##
    # create a list of index of the queries in the FASTA
    # These offset can then be used to quickly read the input file using the
    # start and end positions of each query.
    def index_the_input
      fasta_content = IO.binread(@opt[:input_fasta_file])
      @query_idx = fasta_content.enum_for(:scan, /(>[^>]+)/).map do
        Regexp.last_match.begin(0)
      end
      @query_idx.push(fasta_content.length)
      @query_idx.length - 1
    end

    def print_directories_locations
      warn '==> GeneValidator output files have been saved to:'
      warn "    #{File.expand_path(@dirs[:output_dir])}"
    end

    def resume_from_previous_run(prev_dir)
      prev_tmp_dir = File.join(prev_dir, 'tmp')
      return unless Dir.exist? prev_tmp_dir
      copy_blast_xml_files(prev_tmp_dir)
      copy_raw_seq_files(prev_tmp_dir)
      copy_prev_json_output(prev_tmp_dir)
    end

    def copy_blast_xml_files(prev_tmp_dir)
      return if @opt[:blast_xml_file] || @opt[:blast_tabular_file]
      prev_blast_xml = Dir[File.join(prev_tmp_dir, '*blast_xml')]
      return if prev_blast_xml.empty?
      blast_xml_fname = "#{@dirs[:filename]}.blast_xml"
      @opt[:blast_xml_file] = File.join(@dirs[:tmp_dir], blast_xml_fname)
      FileUtils.cp(prev_blast_xml[0], @opt[:blast_xml_file])
    end

    def copy_raw_seq_files(prev_tmp_dir)
      return if @opt[:raw_sequences]
      return unless @opt[:validations].include?('align') ||
                    @opt[:validations].include?('dup')
      prev_raw_seq = Dir[File.join(prev_tmp_dir, '*raw_seq')]
      return if prev_raw_seq.empty?
      raw_seq_fname = "#{@dirs[:filename]}.blast_xml.raw_seq"
      @opt[:raw_sequences] = File.join(@dirs[:tmp_dir], raw_seq_fname)
      FileUtils.cp(prev_raw_seq[0], @opt[:raw_sequences])
    end

    def copy_prev_json_output(prev_tmp_dir)
      prev_json_dir = File.join(prev_tmp_dir, 'json')
      return unless Dir.exist? prev_json_dir
      all_jsons = Dir[File.join(prev_json_dir, '*.json')]
      FileUtils.cp(all_jsons, @dirs[:json_dir])
      overview_json = Dir[File.join(prev_json_dir, 'overview.json')]
      data_jsons = all_jsons - overview_json
      parse_prev_json(data_jsons)
    end

    def parse_prev_json(data_jsons)
      data_jsons.each do |json|
        json_contents = File.read(File.expand_path(json))
        data = JSON.parse(json_contents, symbolize_names: true)
        idx = json.match(/(\d+).json/)[1].to_i - 1
        @config[:json_output][idx] = data
        print_prev_json_to_console(data)
      end
    end

    def print_prev_json_to_console(data)
      JsonToGVResults.print_console_header(data)
      JsonToGVResults.print_output_console(data)
    end
  end
end
