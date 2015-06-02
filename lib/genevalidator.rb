require 'genevalidator/arg_validation'
require 'genevalidator/get_raw_sequences'
require 'genevalidator/tabular_parser'
require 'genevalidator/blast'
require 'genevalidator/output'
require 'genevalidator/validation'
require 'bio-blastxmlparser'
require 'open-uri'
require 'uri'
require 'io/console'
require 'yaml'
require 'forwardable'
require 'fileutils'
require 'genevalidator/exceptions'

# Top level module / namespace.
module GeneValidator
  class << self
    attr_accessor :opt, :config, :overview
    attr_reader :raw_seq_file_index
    attr_reader :raw_seq_file_load
    # array of indexes for the start offsets of each query in the fasta file
    attr_reader :query_idx
    attr_reader :mutex
    attr_accessor :mutex_yaml, :mutex_html, :mutex_json, :mutex_array

    def init(opt, start_idx = 1, summary = true)
      puts 'Analysing input arguments'
      @opt = opt
      GVArgValidation.validate_args

      @config             = {}
      @config[:idx]       = 0
      @config[:start_idx] = start_idx
      @config[:summary]   = summary

      @config[:type]      = BlastUtils.guess_sequence_type_from_input_file
      @config[:filename]  = File.basename(@opt[:input_fasta_file])
      @config[:dir]       = File.dirname(@opt[:input_fasta_file])
      @config[:html_path] = "#{@opt[:input_fasta_file]}.html"
      @config[:json_file] = "#{@config[:dir]}/#{@config[:filename]}.json"
      @config[:plot_dir]  = "#{@config[:html_path]}/files/json"

      relative_aux_path   = File.join(File.dirname(__FILE__), '../aux')
      @config[:aux]       = File.expand_path(relative_aux_path)
      @config[:json_hash] = {}

      @overview           = {}

      @mutex              = Mutex.new
      @mutex_array        = Mutex.new
      @mutex_yaml         = Mutex.new
      @mutex_html         = Mutex.new
      @mutex_json         = Mutex.new
      create_output_folder
      index_the_input
      RawSequences.index_raw_seq_file if @opt[:raw_sequences]
    end

    ##
    # Parse the blast output and run validations
    def run
      # Run BLAST on all sequences
      BlastUtils.run_blast_on_input_file if @opt[:fast]

      unless @opt[:blast_xml_file] || @opt[:blast_tabular_file]
        # run BLAST on each sequence individually & then run validations
        analyse_each_sequence
      else
        # Obtain fasta file of all BLAST hits
        RawSequencess.run unless @opt[:raw_sequences]
        # Run Validations
        iterator = parse_blast_output_file
        (Validation.new).run_validations(iterator)
      end
      Output.write_json_file(@config[:json_hash], @config[:json_file])
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
        (TabularParser.new).analayse_tabular_file
      end
      ## TODO: Add a Rescue statement - e.g. if unable to create the Object...
    end

    ##
    #
    def analyse_each_sequence
      # file seek for each query
      @query_idx[0..@query_idx.length - 2].each_with_index do |_, i|
        if (i + 1) < @config[:start_idx]
          @config[:idx] += 1
          next
        end
        start_offset = @query_idx[i + 1] - @query_idx[i]
        end_offset   = @query_idx[i]
        query = IO.binread(@opt[:input_fasta_file], start_offset, end_offset)

        xml_output = BlastUtils.run_blast(query)
        iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(xml_output).to_enum
        (Validation.new).run_validations(iterator)
      end
    end
  end
end
