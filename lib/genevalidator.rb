require 'fileutils'
require 'bio-blastxmlparser'

require 'genevalidator/arg_validation'
require 'genevalidator/blast'
require 'genevalidator/exceptions'
require 'genevalidator/get_raw_sequences'
require 'genevalidator/output'
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
    attr_accessor :mutex, :mutex_html, :mutex_json, :mutex_array, :mutex_csv

    def init(opt, start_idx = 1)
      warn '==> Analysing input arguments'
      @opt = opt
      GVArgValidation.validate_args # validates @opt

      @config = setup_config(start_idx)
      @overview = setup_overview_hash
      @dirs = setup_dirnames(@opt[:input_fasta_file])

      @mutex       = Mutex.new
      @mutex_array = Mutex.new
      @mutex_html  = Mutex.new
      @mutex_json  = Mutex.new
      @mutex_csv   = Mutex.new

      index_the_input
      RawSequences.index_raw_seq_file if @opt[:raw_sequences]
    end

    ##
    # Parse the blast output and run validations
    def run
      # Run BLAST on all sequences (generates @opt[:blast_xml_file])
      # if no BLAST OUTPUT file provided...
      unless @opt[:blast_xml_file] || @opt[:blast_tabular_file]
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

    private

    def setup_config(start_idx)
      {
        idx: 0,
        start_idx: start_idx,

        type: BlastUtils.guess_sequence_type_from_input_file,

        json_output: [],
        run_no: 0,
        output_max: 2500 # max no. of queries in the output html file
      }
    end

    def setup_overview_hash
      {
        scores: [], no_queries: 0, good_scores: 0, bad_scores: 0, nee: 0,
        no_mafft: 0, no_internet: 0, map_errors: Hash.new(0),
        run_time: Hash.new(Pair1.new(0, 0))
      }
    end

    ##
    # Creates the output folder and copies the auxiliar folders to this folder
    def setup_output_dir(fname)
      dir_name = "#{fname}_" + Time.now.strftime('%Y_%m_%d_%H_%M_%S')
      default_outdir = File.join(Dir.pwd, dir_name)
      output_dir = @opt[:output_dir].nil? ? default_outdir : @opt[:output_dir]
      Dir.mkdir(output_dir)
      Dir.mkdir(File.join(output_dir, 'tmp'))
      cp_html_files(output_dir)
      output_dir
    end

    def cp_html_files(output_dir)
      if @opt[:output_formats].include? 'html'
        aux_files = File.expand_path('../aux/html_files/', __dir__)
        FileUtils.cp_r(aux_files, output_dir)
        FileUtils.ln_s(File.join(output_dir, 'html_files', 'json'),
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
    end

    def produce_output
      add_summary_statistics
      overall_eval = Output.calculate_overview(@overview)
      Output.print_console_footer(overall_eval, @opt)
      Output.print_html_footer(@opt, @config, @dirs)
      Output.create_overview_json_for_html(overall_eval, @overview[:scores],
                                           @opt, @dirs)
      Output.write_json_file(@config[:json_output], @dirs[:json_file], @opt)
      Output.write_best_fasta(@config[:json_output], @dirs[:fasta_file],
                              @opt[:input_fasta_file], @query_idx, opt)
      Output.write_summary_file(@overview, @dirs[:summary_file], @opt)
    end

    def print_directories_locations
      warn '==> GeneValidator output files have been saved to:'
      warn "    #{File.expand_path(@dirs[:output_dir])}"
    end

    def add_summary_statistics(json_output = @config[:json_output])
      quartiles = json_output.collect { |e| e[:overall_score] }.all_quartiles
      @overview[:first_quartile_of_scores] = quartiles[0]
      @overview[:second_quartile_of_scores] = quartiles[1]
      @overview[:third_quartile_of_scores] = quartiles[2]
      min_hits = json_output.count { |e| e[:no_hits] < @opt[:min_blast_hits] }
      @overview[:insufficient_BLAST_hits] = min_hits
    end
  end
end
