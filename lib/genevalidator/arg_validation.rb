# A module to validate the command line Arguments
## CREDIT: most of these methods have been adapted from SequenceServer
module GVArgValidation

  class Blast
    # Use a fixed minimum version of BLAST+
    MINIMUM_BLAST_VERSION           = '2.2.27+'
    # Use the following exit codes, or 1.
    EXIT_BLAST_NOT_INSTALLED        = 2
    EXIT_BLAST_NOT_COMPATIBLE       = 3
    EXIT_NO_BLAST_DATABASE          = 4
    EXIT_BLAST_INSTALLATION_FAILED  = 5
    EXIT_CONFIG_FILE_NOT_FOUND      = 6
    EXIT_NO_SEQUENCE_DIR            = 7

    def self.assert_blast_installed_and_compatible
      unless GVArgValidation::command?('blastdbcmd')
        puts "*** Could not find BLAST+ binaries."
        exit EXIT_BLAST_NOT_INSTALLED
      end
      version = %x|blastdbcmd -version|.split[1]
      unless version >= MINIMUM_BLAST_VERSION
        puts "*** Your BLAST+ version #{version} is outdated."
        puts "    GeneValidator needs NCBI BLAST+ version #{MINIMUM_BLAST_VERSION} or higher."
        exit EXIT_BLAST_NOT_COMPATIBLE
      end
    end

    def self.export_bin_dir(blast_bin_dir)
      if File.directory?(blast_bin_dir)
        GVArgValidation::add_to_path(blast_bin_dir)
      else
        puts "*** The provided BLAST bin directory does not exist."
        puts "    Please ensure that the provided BLAST bin directory is correct and try again."
        exit EXIT_BLAST_NOT_INSTALLED
      end
    end

    def self.assert_blast_database_exists(blast_db_path)
      unless system("blastdbcmd -db #{blast_db_path} -info > /dev/null 2>&1")
        puts "*** No BLAST database found at the provided path."
        puts "    Please ensure that the provided path is correct and then try again."
        exit EXIT_NO_BLAST_DATABASE
      end
    end
  end

  class Mafft
    def self.assert_mafft_installed
      unless GVArgValidation::command?('mafft')
        puts "*** Could not find Mafft binaries."
        exit!
      end
    end

    def self.export_bin_dir(mafft_bin_dir)
      if File.directory?(mafft_bin_dir)
        GVArgValidation::add_to_path(mafft_bin_dir)
      else
        puts "*** The provided Mafft bin directory does not exist."
        puts "    Please ensure that the provided Mafft bin directory is correct and try again."
        exit!
      end
    end
  end

  ## Check whether dir is in the $PATH and if not, adds the dir to the $PATH. If the
  #   dir is not a directory, the method returns false, otherwise it returns true. 
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