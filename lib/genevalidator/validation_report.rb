
Plot = Struct.new(:filename, :type, :title, :footer, :xtitle, :ytitle, :aux1, :aux2) 

##
# This is an abstract class extended by
# all validation reports
class ValidationReport

  attr_reader :message
  attr_reader :bg_color
  attr_reader :plot_files
  attr_reader :result  
  attr_reader :expected
  attr_reader :validation_result
  attr_reader :errors
  attr_accessor :short_header
  attr_accessor :header
  attr_accessor :description
  attr_accessor :running_time
  attr_accessor :approach
  attr_accessor :explanation
  attr_accessor :conclusion

  ##
  # Initilizes the object
  # Params:  
  # +message+: result of the validation (to be displayed in the output)
  # +validation_result+: :yes for pass validation, :no for fail, :unapplicable or :error
  # +short_header+: String 
  # +header+: String
  # +description+: String
  # +bg_color+: background color of the table cell for the html output (nil by default)
  def initialize(message = "Not enough evidence", validation_result = :no, short_header="", header="", description="", approach="", explanation="", conclusion="")
    @message = message
    @errors = []
    @result = validation_result
    @expected = :yes
    @validation_result = validation_result
    @short_header = short_header
    @header = header
    @description = description
    @approach = approach
    @explanation = explanation
    @conclusion = conclusion
  end

  def print
    message
  end 

  def validation
    validation_result
  end 
  
  ##
  # May return "success" or "error"
  def color
    if bg_color != nil
      return bg_color
    end   
    if validation == @expected
      return "success"
    else  
      if validation == :warning
        return "warning"      
      else
        return "danger" 
      end
    end
  end
end
