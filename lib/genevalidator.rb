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
    attr_accessor :opt, :config, :overview
    attr_reader :raw_seq_file_index
    attr_reader :raw_seq_file_load
    # array of indexes for the start offsets of each query in the fasta file
    attr_reader :query_idx
    attr_accessor :mutex, :mutex_html, :mutex_json, :mutex_array

    def init(opt, start_idx = 1, summary = true)
      $stderr.puts 'Analysing input arguments'
      @opt = opt
      GVArgValidation.validate_args # validates @opt
      @config = {
        idx: 0,
        start_idx: start_idx,
        summary: summary,

        type: BlastUtils.guess_sequence_type_from_input_file,
        filename: File.basename(@opt[:input_fasta_file]),
        html_path: "#{@opt[:input_fasta_file]}.html",
        json_file: File.join(File.dirname(@opt[:input_fasta_file]),
                             "#{File.basename(@opt[:input_fasta_file])}.json"),
        plot_dir: "#{@opt[:input_fasta_file]}.html/files/json",
        aux: File.expand_path(File.join(File.dirname(__FILE__), '../aux')),

        json_output: [],
        run_no: 0,
        output_max: 2500 # max no. of queries in the output file
      }

      @overview = {
        no_queries: 0,
        scores: [],
        good_scores: 0,
        bad_scores: 0,
        nee: 0,
        no_mafft: 0,
        no_internet: 0,
        map_errors: Hash.new(0),
        run_time: Hash.new(Pair1.new(0, 0))
      }

      @mutex       = Mutex.new
      @mutex_array = Mutex.new
      @mutex_html  = Mutex.new
      @mutex_json  = Mutex.new
      create_output_folder
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

      # Obtain fasta file of all BLAST hits
      RawSequences.run if @opt[:raw_sequences]

      # Run Validations  
      iterator = parse_blast_output_file
      (Validations.new).run_validations(iterator)
    
      Output.write_json_file(@config[:json_output], @config[:json_file])
      Output.print_footer(@overview, @config)
    end

    ##
    # Creates the output folder and copies the auxiliar folders to this folder
    def create_output_folder(output_dir = @config[:html_path],
                             aux_dir = @config[:aux])
      Dir.mkdir(output_dir)
      aux_files = File.join(aux_dir, 'files/')
      FileUtils.cp_r(aux_files, output_dir)
    end

    ##
    # create a list of index of the queries in the FASTA
    # These offset can then be used to quickly read the input file using the
    # start and end positions of each query.
    def index_the_input
      fasta_content = IO.binread(@opt[:input_fasta_file])
      @query_idx = fasta_content.enum_for(:scan, /(>[^>]+)/).map { Regexp.last_match.begin(0) }
      @query_idx.push(fasta_content.length)
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
  end
end
