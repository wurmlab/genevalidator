module GeneValidator
  # Exception raised when BLAST path is not added to the CLASSPATH
  class ClasspathError < Exception
  end


  # Exception raised when the command line type argument
  # does not corrsepond to the type of the sequences in the fasta file
  class SequenceTypeError < Exception
    def to_s
      "\nSequence Type error: Possible cause include that the blast output" \
      " was not obtained against a protein database.\n"
    end
  end

  # Exception raised when an unexisting file is accessed
  class FileNotFoundException < Exception
  end

  # Exception raised when blast does not find any hit
  class QueryError < Exception
  end

  # Exception raised when a validation class is not instance of ValidationTest
  class ValidationClassError < Exception
    def to_s
      "\nClass Type error: Possible cause include that one of the validations" \
      " is not a sub-class of ValidationTest\n"
    end
  end

  # Exception raised when a validation report class is not instance of
  #   ValidationReport
  class ReportClassError < Exception
    def to_s
      "\nClass Type error: Possible causes include that the type of one of" \
      ' the validation reports is not a subclass of the ValidationReport' \
      " class.\n"
    end
  end

  # Exception raised when there are not enough blast hits to make a statistical
  #   validation
  class NotEnoughHitsError < Exception
  end

  # Exception raised when function dependig on the internet connection raise
  #   Exception
  class NoInternetError < Exception
  end

  # Exception raised when the alignment initialization raises exception
  class NoMafftInstallationError < Exception
  end

  # Exception raised when the -v argument didn't filter any validatio test
  class NoValidationError < Exception
    def to_s
      "\nValidation error: Possible cause inlcude that the -v arguments" \
      " supplied is not valid\n"
    end
  end

  # Exception raised when the are alias duplications
  class AliasDuplicationError < Exception
    def to_s
      "\nAlias Duplication error: Possible cause: At least two validations" \
      " have the same CLI alias\n"
    end
  end

  # Exception raised when the are alias duplications
  class NoPIdentError < Exception
  end

  # Exception raised when the tabular format does not correspond to the tabular
  #   argument
  class InconsistentTabularFormat < Exception
  end

  # Exception raised when there are more than one reading frame among the hits
  #   of one prediction
  class ReadingFrameError < Exception
  end

  class OtherError < Exception
  end
end
