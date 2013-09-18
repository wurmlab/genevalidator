
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
  ##
  # Initilizes the object
  # Params:  
  # +message+: result of the validation (to be displayed in the output)
  # +bg_color+: background color of the table cell for the html output (nil by default)
  def initialize(message = "Not enough evidence", validation_result = :no)
    @message = message
    @plot_files = []
    @errors = []
    @result = validation_result
    @expected = :yes
    @validation_result = validation_result
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
