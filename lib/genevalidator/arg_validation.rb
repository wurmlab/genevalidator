require 'forwardable'

require 'genevalidator/blast'

# A module to validate the command line Arguments
## CREDIT: some of these methods have been adapted from SequenceServer
module GeneValidator
  # TODO: If a tabular file is provided, ensure that a tabular file has the
  #       right number of columns
  # TODO: assert_if_ruby_version_is_supported
  # A class to validate the arguments passed to the Validation Class
  class GVArgValidation
    class << self
      extend Forwardable
      def_delegators GeneValidator, :opt

      def validate_args
        @opt = opt
        assert_file_present('input file', opt[:input_fasta_file])
        assert_input_file_probably_fasta
        assert_input_sequence
        assert_BLAST_output_files

        assert_validations_arg
        check_num_threads

        export_bin_dirs unless @opt[:bin].nil?
        Blast.validate(opt) unless @opt[:test]
        assert_mafft_installation
      end

      # Return `true` if the given command exists and is executable.
      def command?(command)
        system("which #{command} > /dev/null 2>&1")
      end

      private

      def assert_validations_arg
        validations = %w[lenc lenr frame merge dup orf align]
        if @opt[:validations]
          val = @opt[:validations].collect { |v| v.strip.downcase }
          validations = val unless val.include? 'all'
        end
        @opt[:validations] = validations
      end

      def check_num_threads
        @opt[:num_threads] = Integer(@opt[:num_threads])
        unless @opt[:num_threads].positive?
          warn 'Number of threads can not be lower than 0'
          warn 'Setting number of threads to 1'
          @opt[:num_threads] = 1
        end
        return unless @opt[:num_threads] > 256
        warn "Number of threads set at #{@opt[:num_threads]} is" \
                     ' unusually high.'
      end

      def assert_BLAST_output_files
        return unless @opt[:blast_xml_file] || @opt[:blast_tabular_file]
        if @opt[:blast_xml_file]
          assert_file_present('BLAST XML file', @opt[:blast_xml_file])
        elsif @opt[:blast_tabular_file]
          assert_file_present('BLAST tabular file', @opt[:blast_tabular_file])
          assert_tabular_options_exists
        end
      end

      def assert_tabular_options_exists
        return if @opt[:blast_tabular_options]
        warn '*** Error: BLAST tabular options (-o) have not been set.'
        warn '    Please set the "-o" option with the custom format'
        warn '    used in the BLAST -outfmt argument'
        exit 1
      end

      def assert_input_file_probably_fasta
        File.open(@opt[:input_fasta_file], 'r') do |file_stream|
          file_stream.readline[0] == '>'
        end
      end

      def assert_file_present(desc, file, exit_code = 1)
        return if file && File.exist?(File.expand_path(file))
        warn "*** Error: Couldn't find the #{desc}: #{file}."
        exit exit_code
      end

      alias assert_dir_present assert_file_present

      def assert_input_sequence
        fasta_content = IO.binread(@opt[:input_fasta_file])
        type = BlastUtils.type_of_sequences(fasta_content)
        return if %i[nucleotide protein].include? type
        warn '*** Error: The input files does not contain just protein'
        warn '    or nucleotide data.'
        warn '    Please correct this and try again.'
        exit 1
      end

      def export_bin_dirs
        @opt[:bin].each do |bin|
          bin = File.expand_path(bin)
          if File.exist?(bin) && File.directory?(bin)
            add_to_path(bin)
          else
            warn '*** The following bin directory does not exist:'
            warn "    #{bin}"
          end
        end
      end

      ## Checks if dir is in $PATH and if not, it adds the dir to the $PATH.
      def add_to_path(bin_dir)
        return unless bin_dir
        return if ENV['PATH'].split(':').include?(bin_dir)
        ENV['PATH'] = "#{bin_dir}:#{ENV['PATH']}"
      end

      def assert_mafft_installation
        return if command?('mafft')
        warn '*** Could not find Mafft binaries.'
        warn '    Ignoring error and continuing - Please note that' \
                     ' some validations may be skipped.'
        warn # a blank line
      end
    end

    # Validates BLAST Installation (And BLAST databases)
    class Blast
      class << self
        # Use a fixed minimum version of BLAST+
        MINIMUM_BLAST_VERSION           = '2.2.30+'.freeze
        # Use the following exit codes, or 1.
        EXIT_BLAST_NOT_INSTALLED        = 2
        EXIT_BLAST_NOT_COMPATIBLE       = 3
        EXIT_NO_BLAST_DATABASE          = 4

        def validate(opt)
          assert_blast_installation
          assert_local_blast_database_exists(opt[:db]) if opt[:db] !~ /remote/
        end

        def assert_blast_installation
          # Validate BLAST installation
          assert_blast_installed
          assert_blast_compatible
        end

        def assert_local_blast_database_exists(db)
          return if system("blastdbcmd -db #{db} -info > /dev/null 2>&1")
          warn '*** No BLAST database found at the provided path.'
          warn '    Please ensure that the provided path is correct' \
                       ' and then try again.'
          exit EXIT_NO_BLAST_DATABASE
        end

        private

        def assert_blast_installed
          return if GVArgValidation.command?('blastdbcmd')
          warn '*** Could not find BLAST+ binaries.'
          exit EXIT_BLAST_NOT_INSTALLED
        end

        def assert_blast_compatible
          version = `blastdbcmd -version`.split[1]
          return if version >= MINIMUM_BLAST_VERSION
          warn "*** Your BLAST+ version #{version} is outdated."
          warn '    GeneValidator needs NCBI BLAST+ version' \
                       " #{MINIMUM_BLAST_VERSION} or higher."
          exit EXIT_BLAST_NOT_COMPATIBLE
        end
      end
    end
  end
end
