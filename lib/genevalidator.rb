require 'genevalidator/arg_validation'
require 'genevalidator/get_raw_sequences'
require 'genevalidator/tabular_parser'
require 'genevalidator/blast'
require 'genevalidator/output'
require 'genevalidator/exceptions'
require 'genevalidator/validation_length_cluster'
require 'genevalidator/validation_length_rank'
require 'genevalidator/validation_blast_reading_frame'
require 'genevalidator/validation_gene_merge'
require 'genevalidator/validation_duplication'
require 'genevalidator/validation_open_reading_frame'
require 'genevalidator/validation_alignment'
require 'genevalidator/pool'
require 'bio-blastxmlparser'
require 'open-uri'
require 'uri'
require 'io/console'
require 'yaml'
require 'thread'

# Top level module / namespace.
module GeneValidator
  Pair1 = Struct.new(:x, :y)

  # Main Class that initalises and then runs validations.
  class Validation
    attr_reader :opt
    attr_reader :type
    attr_reader :input_fasta_file
    attr_reader :html_path
    attr_reader :yaml_path
    attr_reader :filename
    attr_reader :raw_seq_file_index
    attr_reader :raw_seq_file_load
    attr_accessor :idx  # current number of the querry processed
    attr_reader :start_idx
    # array of indexes for the start offsets of each query in the fasta file
    attr_reader :query_offset_lst
    attr_reader :overall_evaluation

    # global variables
    attr_reader :no_queries
    attr_reader :scores
    attr_reader :good_predictions
    attr_reader :bad_predictions
    attr_reader :nee
    attr_reader :no_mafft
    attr_reader :no_internet
    attr_reader :map_errors
    attr_reader :map_running_times

    attr_reader :threads
    attr_reader :mutex
    attr_reader :mutex_yaml
    attr_reader :mutex_html
    attr_reader :mutex_array

    ##
    # Initilizes the object
    # Params:
    # +opt+: A hash - Default Values: {validations: ['all'],
    # blast_tabular_file: nil, blast_tabular_options: nil, blast_xml_file: nil,
    # db: 'remote', raw_sequences: nil, num_threads: 1 fast: false}
    # +start_idx+: number of the sequence from the file to start with
    # +overall_evaluation+: boolean variable for printing overall evaluation
    def initialize(opt, start_idx = 1, overall_evaluation = true)
      # Validate opts
      @opt = GVArgValidation.validate_args(opt)

      puts "\nDepending on your input and your computational resources, this"\
           ' may take a while. Please wait...'

      @idx                    = 0
      @start_idx              = start_idx

      @overall_evaluation     = overall_evaluation

      # start a worker thread
      @threads                = [] # used for parallelizing the validations.
      @mutex                  = Mutex.new
      @mutex_yaml             = Mutex.new
      @mutex_html             = Mutex.new
      @mutex_array            = Mutex.new

      # global variables
      @no_queries             = 0
      @scores                 = []
      @good_predictions       = 0
      @bad_predictions        = 0
      @nee                    = 0
      @no_mafft               = 0
      @no_internet            = 0
      @map_errors             = Hash.new(0)
      @map_running_times      = Hash.new(Pair1.new(0, 0))

      @type                   = determine_sequence_type
      @query_offset_lst       = index_the_input

      # build the path of html folder output
      dir                     = File.dirname(@opt[:input_fasta_file])
      @filename               = File.basename(@opt[:input_fasta_file])
      @yaml_path              = dir
      @html_path              = "#{opt[:input_fasta_file]}.html"
      @plot_dir               = "#{@html_path}/files/json"

      # create 'html' directory
      Dir.mkdir(@html_path)
      # copy auxiliar folders to the html folder
      aux = File.join(File.dirname(File.expand_path(__FILE__)), '../aux/files')
      FileUtils.cp_r(aux, @html_path)
    end

    ##
    # Parse the blast output and run validations
    def run
      # Run BLAST on all sequences
      run_blast_on_the_input_file if @opt[:fast]

      unless @opt[:blast_xml_file] || @opt[:blast_tabular_file]
        # run BLAST on each sequence individually & then run validations
        run_blast_on_each_sequence
      else
        # Extract raw sequences of hits
        extract_raw_sequences_of_blast_hits unless @opt[:raw_sequences]
        create_an_index_file_of_raw_seq_file(@opt[:raw_sequences])
        # Run Validations
        iterator = parse_blast_output_file
        run_validations(iterator)
      end
      return unless @overall_evaluation
      Output.print_footer(@no_queries, @scores, @good_predictions,
                          @bad_predictions, @nee, @no_mafft, @no_internet,
                          @map_errors, @map_running_times, @html_path,
                          @filename)
    end

    def determine_sequence_type
      BlastUtils.guess_sequence_type_from_file(@opt[:input_fasta_file])
    end

    ##
    # Runs BLAST on the input file - only run when the opt[:fast] is true
    def run_blast_on_the_input_file
      return if @opt[:blast_xml_file] || @opt[:blast_tabular_file]
      puts 'Running BLAST'
      @opt[:blast_xml_file] = @opt[:input_fasta_file] + '.blast_xml'
      BlastUtils.run_blast_on_file(@opt)
    end

    ##
    # Extracts raw sequences of all blast hits
    def extract_raw_sequences_of_blast_hits
      puts 'Extracting sequences within the BLAST output file from the BLAST' \
           ' database'
      @opt[:raw_sequences] = GetRawSequences.run(@opt)
    end

    ##
    # create a list of index of the queries in the FASTA
    # These offset can then be used to quickly read the input file using the
    # start and end positions of each query.
    def index_the_input
      fasta_content = IO.binread(@opt[:input_fasta_file])
      offset_array  = fasta_content.enum_for(:scan, /(>[^>]+)/).map { Regexp.last_match.begin(0) }
      offset_array.push(fasta_content.length)
      fasta_content = nil
      offset_array
    end

    ##
    # Index the raw sequences file...
    def create_an_index_file_of_raw_seq_file(raw_sequence_file)
      # leave only the identifiers in the fasta description
      content = File.open(raw_sequence_file, 'rb').read.gsub(/ .*/, '')
      File.open(raw_sequence_file, 'w+') { |f| f.write(content) }

      # index the fasta file
      keys   = content.scan(/>(.*)\n/).flatten
      values = content.enum_for(:scan, /(>[^>]+)/).map { Regexp.last_match.begin(0) }

      # make an index hash
      index_hash = {}
      keys.each_with_index do |k, i|
        start = values[i]
        endf  = (i == values.length - 1) ? content.length - 1 : values[i + 1]
        index_hash[k] = [start, endf]
      end

      # create FASTA index
      @raw_seq_file_index = "#{raw_sequence_file}.idx"
      @raw_seq_file_load  = index_hash

      File.open(@raw_seq_file_index, 'w') do |f|
        YAML.dump(index_hash, f)
      end
      content = nil
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
        TabularParser.new(@opt[:blast_tabular_file],
                          @opt[:blast_tabular_options], @type)
      end
      ## TODO: Add a Rescue statement - e.g. if unable to create the Object...
    end

    ##
    #
    def run_blast_on_each_sequence
      # file seek for each query
      @query_offset_lst[0..@query_offset_lst.length - 2].each_with_index do |_pos, i|
        if (i + 1) >= @start_idx
          start_offset = @query_offset_lst[i + 1] - @query_offset_lst[i]
          end_offset   = @query_offset_lst[i]
          query = IO.binread(@opt[:input_fasta_file], start_offset, end_offset)

          # call blast with the default parameters
          blast_type = (type == :protein) ? 'blastp' : 'blastx'
          blast_xml_output = BlastUtils.run_blast(blast_type, query, @opt[:db],
                                                  @opt[:num_threads])
          iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(blast_xml_output).to_enum
          run_validations(iterator)
        else
          @idx += 1
        end
      end
    end

    ##
    #
    def run_validations(iterator)
      p = Pool.new(@opt[:num_threads]) if @opt[:num_threads] > 1

      while @idx + 1 < @query_offset_lst.length
        prediction = get_info_on_each_query_sequence
        @idx += 1

        hits = parse_next_iteration(iterator, prediction)

        if hits.nil?
          @idx -= 1
          break
        end
        current_idx = @idx
        # the first validation should be treated separately
        if current_idx == @start_idx || @multithreading == false
          validate(prediction, hits, current_idx)
        else
          p.schedule(prediction, hits, current_idx) do |prediction, hits, current_idx|
            validate(prediction, hits, current_idx)
          end
        end
      end
    ensure
      p.shutdown if @opt[:num_threads] > 1
    end

    def parse_next_iteration(iterator, prediction)
      iterator.next if @idx < @start_idx
      if @opt[:blast_xml_file]
        BlastUtils.parse_next(iterator, @type)
      elsif @opt[:blast_tabular_file]
        iterator.parse_next(prediction.identifier)
      end
    end

    ##
    # get info about the query
    def get_info_on_each_query_sequence
      prediction   = Sequence.new
      start_offset = @query_offset_lst[idx + 1] - @query_offset_lst[idx]
      end_offset   = @query_offset_lst[idx]
      query        = IO.binread(@opt[:input_fasta_file], start_offset, end_offset)
      parse_query  = query.scan(/>([^\n]*)\n([A-Za-z\n]*)/)[0]

      prediction.definition     = parse_query[0].gsub("\n", '')
      prediction.identifier     = prediction.definition.gsub(/ .*/, '')
      prediction.type           = @type
      prediction.raw_sequence   = parse_query[1].gsub("\n", '')
      prediction.length_protein = prediction.raw_sequence.length
      prediction.length_protein /= 3 if @type == :nucleotide
      prediction
    end

    ##
    # Validate one query and create validation report
    # Params:
    # +prediction+: Sequence object
    # +hits+: Array of +Sequence+ objects
    # +idx+: the index number of the query
    def validate(prediction, hits, current_idx)
      query_output = do_validations(prediction, hits, current_idx)
      query_output.generate_html
      query_output.print_output_file_yaml
      query_output.print_output_console

      validations = query_output.validations

      no_mafft = 0
      no_internet = 0
      errors = []
      validations.each do |v|
        unless v.errors.nil?
          no_mafft += v.errors.select { |e| e == NoMafftInstallationError }.length
          no_internet += v.errors.select { |e| e == NoInternetError }.length
        end
        errors.push(v.short_header) if v.validation == :error
      end

      no_evidence = validations.count { |v| v.result == :unapplicable || v.result == :warning } == validations.length
      nee = (no_evidence) ? 1 : 0

      good_predictions = (query_output.overall_score >= 75) ? 1 : 0
      bad_predictions  = (query_output.overall_score >= 75) ? 0 : 1

      @mutex_array.synchronize do
        @no_queries += 1
        @scores.push(query_output.overall_score)
        @good_predictions += good_predictions
        @bad_predictions += bad_predictions
        @nee += nee
        @no_mafft += no_mafft
        @no_internet += no_internet
        errors.each { |err| @map_errors[err] += 1 }

        validations.each do |v|
          next if v.running_time == 0 || v.running_time.nil?
          next if v.validation == :unapplicable || v.validation == :error
          p = Pair1.new(@map_running_times[v.short_header].x + v.running_time, @map_running_times[v.short_header].y + 1)
          @map_running_times[v.short_header] = p
        end
      end
      query_output
    end

    ##
    # Removes identical hits
    # Params:
    # +prediction+: Sequence object
    # +hits+: Array of +Sequence+ objects
    # Output:
    # new array of hit +Sequence+ objects
    def remove_identical_hits(prediction, hits)
      # remove the identical hits
      # identical hit means 100%coverage and >99% identity
      identical_hits = []
      hits.each do |hit|
        # check if all hsps have identity more than 99%
        low_identity = hit.hsp_list.select { |hsp| hsp.pidentity.nil? || hsp.pidentity < 99 }

        # check the coverage
        coverage = Array.new(prediction.length_protein, 0)
        hit.hsp_list.each do |hsp|
          len = hsp.match_query_to - hsp.match_query_from + 1
          coverage[hsp.match_query_from - 1..hsp.match_query_to - 1] = Array.new(len, 1)
        end

        if low_identity.length == 0 && coverage.uniq.length == 1
          identical_hits.push(hit)
        end
      end

      identical_hits.each { |hit| hits.delete(hit) }
      hits
    end

    ##
    # Runs all the validations and prints the outputs given the current
    # prediction query and the corresponding hits
    # Params:
    # +prediction+: Sequence object
    # +hits+: Array of +Sequence+ objects
    # +idx+: the index number of the query
    # Output:
    # +Output+ object
    def do_validations(prediction, hits, current_idx)
      begin
        hits = remove_identical_hits(prediction, hits)
        rescue Exception => error # NoPIdentError
      end

      query_output                = Output.new(@mutex, @mutex_yaml, @mutex_html,
                                               @filename, @html_path,
                                               @yaml_path, current_idx, @start_idx)
      query_output.prediction_len = prediction.length_protein
      query_output.prediction_def = prediction.definition
      query_output.nr_hits        = hits.length

      plot_path                   = File.join(@plot_dir, "#{@filename}_#{current_idx}")

      validations = []
      validations.push LengthClusterValidation.new(@type, prediction, hits,
                                                   plot_path)
      validations.push LengthRankValidation.new(@type, prediction, hits)
      validations.push GeneMergeValidation.new(@type, prediction, hits,
                                               plot_path)
      validations.push DuplicationValidation.new(@type, prediction, hits,
                                                 @opt[:raw_sequences],
                                                 @raw_seq_file_index,
                                                 @raw_seq_file_load, @opt[:db],
                                                 @opt[:num_threads])
      validations.push BlastReadingFrameValidation.new(@type, prediction, hits)
      validations.push OpenReadingFrameValidation.new(@type, prediction, hits,
                                                      plot_path)
      validations.push AlignmentValidation.new(@type, prediction, hits,
                                               plot_path, @opt[:raw_sequences],
                                               @raw_seq_file_index,
                                               @raw_seq_file_load,
                                               @opt[:db], @opt[:num_threads])

      validations = validations.select { |v| @opt[:validations].include? v.cli_name.downcase }

      # check the class type of the elements in the list
      validations.each do |v|
        fail ValidationClassError unless v.is_a? ValidationTest
      end

      # check alias duplication
      aliases = validations.map(&:cli_name)
      fail AliasDuplicationError unless aliases.length == aliases.uniq.length

      validations.each do |v|
        v.run
        fail ReportClassError unless v.validation_report.is_a? ValidationReport
      end
      query_output.validations = validations.map(&:validation_report)

      fail NoValidationError if query_output.validations.length == 0

      # compute validation score
      compute_scores(query_output)
      query_output

    rescue ValidationClassError => error
      error_line = error.backtrace[0].scan(%r{/([^/]+:\d+):.*})[0][0]
      $stderr.print "Class Type error at #{error_line}." \
                    ' Possible cause: type of one of the validations is not' \
                    " ValidationTest\n"
      exit 1
    rescue NoValidationError => error
      error_line = error.backtrace[0].scan(%r{/([^/]+:\d+):.*})[0][0]
      $stderr.print "Validation error at #{error_line}." \
                    " Possible cause: your -v arguments are not valid aliases\n"
      exit 1
    rescue ReportClassError => error
      error_line = error.backtrace[0].scan(%r{/([^/]+:\d+):.*})[0][0]
      $stderr.print "Class Type error at #{error_line}."\
                    ' Possible cause: type of one of the validation reports' \
                    " returned by the 'run' method is not ValidationReport\n"
      exit 1
    rescue AliasDuplicationError => error
      error_line = error.backtrace[0].scan(%r{/([^/]+:\d+):.*})[0][0]
      $stderr.print "Alias Duplication error at #{error_line}."\
                    ' Possible cause: At least two validations have the same' \
                    " CLI alias\n"
      exit 1
    end

    def compute_scores(query_output)
      validations = query_output.validations
      successes = validations.map { |v| v.result == v.expected }.count(true)

      fails = validations.map { |v| v.validation != :unapplicable &&
                                    v.validation != :error &&
                                    v.result != v.expected }.count(true)

      lcv = validations.select { |v| v.class == LengthClusterValidationOutput }
      lrv = validations.select { |v| v.class == LengthRankValidationOutput }
      if lcv.length == 1 && lrv.length == 1
        score_lcv = (lcv[0].result == lcv[0].expected)
        score_lrv = (lrv[0].result == lrv[0].expected)
        # if both are true this should be counted as a single success
        if score_lcv == true && score_lrv == true
          successes -= 1
        elsif score_lcv == false && score_lrv == false
          # if both are false this will be a fail
          fails -= 1
        else
          successes -= 0.5
          fails -= 0.5
        end
      end

      query_output.successes     = successes
      query_output.fails         = fails
      total_query                = successes.to_i + fails
      query_output.overall_score = (successes * 100 / (total_query)).round(0)
    end
  end
end
