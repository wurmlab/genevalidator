##
# This is an abstract class extended by
# all validation reports
class ValidationReport

  attr_reader :message
  attr_reader :bg_color

  ##
  # Initilizes the object
  # Params:  
  # +message+: result of the validation (to be displayed in the output)
  # +bg_color+: background color of the table cell for the html output (nil by default)
  def initialize(message = "Not enough evidence",  bg_color = nil)
    @message = message
    @bg_color = bg_color  
  end

  def print
    message
  end 

  def validation
    :no
  end 
  
  def color
    if bg_color != nil
      return bg_color
    end   
    if validation == :yes
      return "white"   
    else
      return "red"
    end
  end
end
