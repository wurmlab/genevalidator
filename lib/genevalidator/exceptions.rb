
# Exception raised when BLAST path is not added to the CLASSPATH
class ClasspathError < Exception
end

# Exception raised when the command line type argument 
# does not corrsepond to the type of the sequences in the fasta file
class SequenceTypeError < Exception
end

# Exception raised when an unexisting file is accessed
class FileNotFoundException < Exception
end

# Exception raised when blast does not find any hit
class QueryError < Exception
end

# Exception raised when a validation class is not instance of ValidationTest
class ValidationClassError < Exception
end

# Exception raised when a validation report class is not instance of ValidationReport
class ReportClassError < Exception
end
