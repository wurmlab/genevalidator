class ValidationOutput

  attr_reader :message

  def initialize(message = "Not enough evidence")
    @message = message
  end

  def print
    message
  end 

  def validation
    :no
  end 
  
  def color
   
    if validation == :yes
      "white"   
    else
      "red"
    end
  end
end
