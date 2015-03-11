# A module to validate the command line Arguments
## CREDIT: some of these methods have been adapted from SequenceServer
module GeneValidator
# TODO: If a tabular file is provided, ensure that a tabular file has the right number of columns
# TODO: assert_if_ruby_version_is_supported
  # A module to validate the arguments passed to the Validation Class
  module GVArgValidation
    class << self
      def validate_args(opt)
        @opt = opt
        assert_validations
        assert_file_present('input file', opt[:input_fasta_file])
        assert_input_file_probably_fasta
        assert_input_contains_single_type_sequence
        assert_output_dir_does_not_exist
        assert_BLAST_output_files

        Blast.validate(opt) unless @opt[:test]
        Mafft.assert_mafft_installation(opt)
        @opt
      end 

      private

      def assert_validations
        validations = %w(lenc lenr frame merge dup orf align)
        if @opt[:validations]
          val = @opt[:validations].collect { |v| v.strip.downcase }
          validations = val unless val.include? 'all'
        end
        @opt[:validations] = validations
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
        puts "The output directory already exists for this fasta file.\n"
        puts "Please remove the following directory: #{output_dir}\n"
        puts "You can run the following command to remove the folder.\n"
        puts "\n   $ rm -r #{output_dir} \n"
        exit 1
      end

      def assert_tabular_options_exists
        return if @opt[:blast_tabular_options]
        puts '*** Error: BLAST tabular options (-o) have not been set.'
        puts '    Please set the "-o" option with the custom format'
        puts '    used in the BLAST -outfmt argument'
        exit 1
      end

      def assert_input_file_probably_fasta
        File.open(@opt[:input_fasta_file], 'r') do |file_stream|
          (file_stream.readline[0] == '>') ? true : false
        end
      end

      def assert_file_present(desc, file, exit_code = 1)
        return if file && File.exist?(File.expand_path(file))
        puts "*** Error: Couldn't find the #{desc}: #{file}."
        exit exit_code
      end

      alias_method :assert_dir_present, :assert_file_present

      def assert_input_contains_single_type_sequence
        fasta_content = IO.binread(@opt[:input_fasta_file])
        type = BlastUtils.type_of_sequences(fasta_content)
        return if type == :nucleotide || type == :protein
        puts '*** Error: The input files does not contain just protein or'
        puts '    nucleotide data. Please correct this and try again.'
        exit 1
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
          @opt = opt
          assert_blast_installation
          assert_blast_database_provided
          assert_local_blast_database_exists if @opt[:db] !~ /remote/
        end

        def assert_blast_installation
          # Validate BLAST installation
          if @opt[:blast_bin].nil?
            assert_blast_installed
            assert_blast_compatible
          else
            export_bin_dir
          end
        end

        def assert_blast_database_provided
          return unless @opt[:db].nil?
          puts '*** Error: A BLAST database is required. Please pass a local or'
          puts '    remote BLAST database to GeneValidator as follows:'
          puts # a blank line
          puts "      $ genevalidator -d '~/blastdb/SwissProt' Input_File"
          puts # a blank line
          puts '    Or use a remote database:'
          puts # a blank line
          puts "      $ genevalidator -d 'swissprot -remote' Input_File"
          exit 1
        end

        def assert_local_blast_database_exists
          return if system("blastdbcmd -db #{@opt[:db]} -info > /dev/null 2>&1")
          puts '*** No BLAST database found at the provided path.'
          puts '    Please ensure that the provided path is correct and then' \
               ' try again.'
          exit EXIT_NO_BLAST_DATABASE
        end

        private

        def assert_blast_installed
          return if GVArgValidation.command?('blastdbcmd')
          puts '*** Could not find BLAST+ binaries.'
          exit EXIT_BLAST_NOT_INSTALLED
        end

        def assert_blast_compatible
          version = `blastdbcmd -version`.split[1]
          return if version >= MINIMUM_BLAST_VERSION
          puts "*** Your BLAST+ version #{version} is outdated."
          puts '    GeneValidator needs NCBI BLAST+ version' \
               " #{MINIMUM_BLAST_VERSION} or higher."
          exit EXIT_BLAST_NOT_COMPATIBLE
        end

        def export_bin_dir
          if File.directory?(@opt[:blast_bin])
            GVArgValidation.add_to_path(@opt[:blast_bin])
          else
            puts '*** The provided BLAST bin directory does not exist.'
            puts '    Please ensure that the provided BLAST bin directory is' \
                 ' correct and try again.'
            exit EXIT_BLAST_NOT_INSTALLED
          end
        end
      end
    end

    # Validates Mafft installation
    class Mafft
      class << self
        def assert_mafft_installation(opt)
          @opt = opt
          if @opt[:mafft_bin].nil?
            assert_mafft_installed
          else
            export_bin_dir
          end
        end

        private

        def assert_mafft_installed
          return if GVArgValidation.command?('mafft')
          puts '*** Could not find Mafft binaries.'
          puts '    Ignoring error and continuing - Please note that some' \
               ' validations may be skipped.'
          puts # a blank line
        end

        def export_bin_dir
          if File.directory?(@opt[:mafft_bin])
            GVArgValidation.add_to_path(@opt[:mafft_bin])
          else
            puts '*** The provided Mafft bin directory does not exist.'
            puts '    Ignoring error and continuing - Please note that some' \
                 ' validations may be skipped.'
            puts # a blank line
          end
        end
      end
    end

    class << self
      ## Checks if dir is in $PATH and if not, it adds the dir to the $PATH.
      def add_to_path(bin_dir)
        return if ENV['PATH'].split(':').include?(bin_dir)
        ENV['PATH'] = "#{bin_dir}:#{ENV['PATH']}"
      end

      # Return `true` if the given command exists and is executable.
      def command?(command)
        system("which #{command} > /dev/null 2>&1")
      end
    end
  end
end
