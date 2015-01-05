# A module to validate the command line Arguments
## CREDIT: most of these methods have been adapted from SequenceServer
module GVArgValidation

  class << self
    def validate_args(input_file, opt)
      assert_output_dir_does_not_exist(input_file)
      Blast.assert_blast_database_provided(opt[:db])
      if opt[:db] !~ /remote/
        Blast.assert_blast_database_exists(opt[:db])
      end
      Blast.assert_blast_installation(opt[:blast_bin])
      Mafft.assert_mafft_installation(opt[:mafft_bin])
    end

    def assert_output_dir_does_not_exist(input_file)
      output_dir = "#{input_file}.html"
      if File.exists? output_dir
        puts "The output directory already exists for this fasta file.\n"
        puts "For a new validation please remove the following directory: #{output_dir}\n"
        puts "You can run the following command to remove the folder.\n"
        puts "\n   $ rm -r #{output_dir} \n"
        exit 1
      end
    end
  end

  class Blast
    # Use a fixed minimum version of BLAST+
    MINIMUM_BLAST_VERSION           = '2.2.29+'
    # Use the following exit codes, or 1.
    EXIT_BLAST_NOT_INSTALLED        = 2
    EXIT_BLAST_NOT_COMPATIBLE       = 3
    EXIT_NO_BLAST_DATABASE          = 4

    def self.assert_blast_installation(blast_bin_dir = nil)
      # Validate BLAST installation
      if blast_bin_dir.nil?
        assert_blast_installed_and_compatible
      else
        export_bin_dir(blast_bin_dir)
      end
    end

    def self.assert_blast_database_provided(blast_db = nil)
      if blast_db.nil?
        puts "Error: A BLAST database is required."
        puts "Please pass a local or remote BLAST database to GeneValidator as follows:"
        puts # a blank line
        puts "    $ genevalidator -d '~/blastdb/SwissProt' Input_File"
        puts # a blank line
        puts "Or use a remote database:"
        puts # a blank line
        puts "    $ genevalidator -d 'swissprot -remote' Input_File" 
        exit 1
      end
    end

    def self.assert_blast_database_exists(blast_db_path)
      unless system("blastdbcmd -db #{blast_db_path} -info > /dev/null 2>&1")
        puts "*** No BLAST database found at the provided path."
        puts "    Please ensure that the provided path is correct and then" +
             " try again."
        exit EXIT_NO_BLAST_DATABASE
      end
    end

    private
    
    def self.assert_blast_installed_and_compatible
      unless GVArgValidation::command?('blastdbcmd')
        puts "*** Could not find BLAST+ binaries."
        exit EXIT_BLAST_NOT_INSTALLED
      end
      version = %x|blastdbcmd -version|.split[1]
      unless version >= MINIMUM_BLAST_VERSION
        puts "*** Your BLAST+ version #{version} is outdated."
        puts "    GeneValidator needs NCBI BLAST+ version" +
             " #{MINIMUM_BLAST_VERSION} or higher."
        exit EXIT_BLAST_NOT_COMPATIBLE
      end
    end

    def self.export_bin_dir(blast_bin_dir)
      if File.directory?(blast_bin_dir)
        GVArgValidation::add_to_path(blast_bin_dir)
      else
        puts "*** The provided BLAST bin directory does not exist."
        puts "    Please ensure that the provided BLAST bin directory is" +
             " correct and try again."
        exit EXIT_BLAST_NOT_INSTALLED
      end
    end
  end

  class Mafft
    def self.assert_mafft_installation(mafft_bin = nil)
      if mafft_bin.nil?
        GVArgValidation::Mafft.assert_mafft_installed
      else
        GVArgValidation::Mafft.export_bin_dir(mafft_bin)
      end
    end

    private

    def self.assert_mafft_installed
      unless GVArgValidation::command?('mafft')
        puts "*** Could not find Mafft binaries."
        puts "    Ignoring error and continuing - Please note that some" +
             " validations may be skipped."
        puts # a blank line
      end
    end

    def self.export_bin_dir(mafft_bin_dir)
      if File.directory?(mafft_bin_dir)
        GVArgValidation::add_to_path(mafft_bin_dir)
      else
        puts "*** The provided Mafft bin directory does not exist."
        puts "    Ignoring error and continuing - Please note that some" +
             " validations may be skipped."
        puts # a blank line
      end
    end
  end

  ## Check whether dir is in the $PATH and if not, adds the dir to the $PATH.
  def self.add_to_path(bin_dir)
    unless ENV['PATH'].split(':').include?(bin_dir)
      ENV['PATH'] = "#{bin_dir}:#{ENV['PATH']}"
    end
  end

  # Return `true` if the given command exists and is executable.
  def self.command?(command)
    system("which #{command} > /dev/null 2>&1")
  end
end
