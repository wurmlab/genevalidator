require 'forwardable'
require 'mkmf'

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
        assert_output_dir_does_not_exist
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
        (find_executable command) !~ nil 
      end

      private

      def assert_validations_arg
        validations = %w(lenc lenr frame merge dup orf align)
        if @opt[:validations]
          val = @opt[:validations].collect { |v| v.strip.downcase }
          validations = val unless val.include? 'all'
        end
        @opt[:validations] = validations
      end

      def check_num_threads
        @opt[:num_threads] = Integer(@opt[:num_threads])
        unless @opt[:num_threads] > 0
          $stderr.puts 'Number of threads can not be lower than 0'
        end
        return unless @opt[:num_threads] > 256
        $stderr.puts "Number of threads set at #{@opt[:num_threads]} is unusually high."
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

      def assert_output_dir_does_not_exist
        output_dir = "#{@opt[:input_fasta_file]}.html"
        return unless File.exist?(output_dir)
        $stderr.puts "The output directory already exists for this fasta file.\n"
        $stderr.puts "Please remove the following directory: #{output_dir}\n"
        $stderr.puts "You can run the following command to remove the folder.\n"
        $stderr.puts "\n   $ rm -r #{output_dir} \n"
        exit 1
      end

      def assert_tabular_options_exists
        return if @opt[:blast_tabular_options]
        $stderr.puts '*** Error: BLAST tabular options (-o) have not been set.'
        $stderr.puts '    Please set the "-o" option with the custom format'
        $stderr.puts '    used in the BLAST -outfmt argument'
        exit 1
      end

      def assert_input_file_probably_fasta
        File.open(@opt[:input_fasta_file], 'r') do |file_stream|
          (file_stream.readline[0] == '>') ? true : false
        end
      end

      def assert_file_present(desc, file, exit_code = 1)
        return if file && File.exist?(File.expand_path(file))
        $stderr.puts "*** Error: Couldn't find the #{desc}: #{file}."
        exit exit_code
      end

      alias_method :assert_dir_present, :assert_file_present

      def assert_input_sequence
        fasta_content = IO.binread(@opt[:input_fasta_file])
        type = BlastUtils.type_of_sequences(fasta_content)
        return if type == :nucleotide || type == :protein
        $stderr.puts '*** Error: The input files does not contain just protein or'
        $stderr.puts '    nucleotide data. Please correct this and try again.'
        exit 1
      end

      def export_bin_dirs
        @opt[:bin].each do |bin|
          if File.directory?(bin)
            add_to_path(bin)
          else
            $stderr.puts '*** The following bin directory does not exist:'
            $stderr.puts "    #{bin}"
          end
        end
      end

      ## Checks if dir is in $PATH and if not, it adds the dir to the $PATH.
      def add_to_path(bin_dir)
        return if ENV['PATH'].split(':').include?(bin_dir)
        ENV['PATH'] = "#{bin_dir}:#{ENV['PATH']}"
      end

      def assert_mafft_installation
        return if command?('mafft')
        $stderr.puts '*** Could not find Mafft binaries.'
        $stderr.puts '    Ignoring error and continuing - Please note that' \
                     ' some validations may be skipped.'
        $stderr.puts # a blank line
      end
    end

    # Validates BLAST Installation (And BLAST databases)
    class Blast
      class << self
        # Use a fixed minimum version of BLAST+
        MINIMUM_BLAST_VERSION           = '2.2.30+'
        # Use the following exit codes, or 1.
        EXIT_BLAST_NOT_INSTALLED        = 2
        EXIT_BLAST_NOT_COMPATIBLE       = 3
        EXIT_NO_BLAST_DATABASE          = 4

        def validate(opt)
          assert_blast_installation
          #warn_if_remote_database(opt[:db])
          assert_local_blast_database_exists(opt[:db]) if opt[:db] !~ /remote/
        end

        def assert_blast_installation
          # Validate BLAST installation
          assert_blast_installed
          assert_blast_compatible
        end

        def warn_if_remote_database(db)
          return if db !~ /remote/
          $stderr.puts # a blank line
          $stderr.puts 'Warning: BLAST will be carried out on remote servers.'
          $stderr.puts 'This may take quite a bit of time.'
          $stderr.puts 'You may want to install a local BLAST database for' \
                       ' faster analyses.'
          $stderr.puts # a blank line
        end

        def assert_local_blast_database_exists(db)
          return if system("blastdbcmd -db #{db} -info > /dev/null 2>&1")
          $stderr.puts '*** No BLAST database found at the provided path.'
          $stderr.puts '    Please ensure that the provided path is correct' \
                       ' and then try again.'
          exit EXIT_NO_BLAST_DATABASE
        end

        private

        def assert_blast_installed
          return if GVArgValidation.command?('blastdbcmd')
          $stderr.puts '*** Could not find BLAST+ binaries.'
          exit EXIT_BLAST_NOT_INSTALLED
        end

        def assert_blast_compatible
          version = `blastdbcmd -version`.split[1]
          return if version >= MINIMUM_BLAST_VERSION
          $stderr.puts "*** Your BLAST+ version #{version} is outdated."
          $stderr.puts '    GeneValidator needs NCBI BLAST+ version' \
                       " #{MINIMUM_BLAST_VERSION} or higher."
          exit EXIT_BLAST_NOT_COMPATIBLE
        end
      end
    end
  end
end
