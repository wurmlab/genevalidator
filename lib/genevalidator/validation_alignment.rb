require 'genevalidator/validation_output'

##
# Class that stores the validation output information
class AlignmentValidationOutput < ValidationReport

  attr_reader :msg

  def initialize (msg)
    @msg = msg
  end

  def print
    msg
  end

  def validation
    :yes
  end

  def color
    "white"
  end
end

##
# This class contains the methods necessary for
# validations based on multiple alignment
class AlignmentValidation < ValidationTest

  def initialize(type, prediction, hits = nil)
    super
    @short_header = "MA Test"
    @header = "Multiple Alignment Test"
    @description = "Finds gaps/extra regions based on the multiple alignment of the best hits."
  end

  ##
  # Find gaps/extra regions based on the multiple alignment 
  # of the first n hits
  # Output:
  # +AlignmentValidationOutput+ object
  def run(n=25)    
    begin
      raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence

      # get the first n hits
      less_hits = @hits[0..[n-1,@hits.length].min]

      @validation_report = AlignmentValidationOutput.new("In progress...")        

      # Exception is raised when blast founds no hits
      rescue Exception => error
        ValidationReport.new("Not enough evidence")
    end
  end
end
