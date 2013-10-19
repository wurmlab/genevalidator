
# This is an abstract class extended  
# by all validation classes
class ValidationTest

  class << self
    def short_header(value)
      @short_header = value if value
      @short_header
    end

    def header(value)
      @header = value if value
      @header
    end

    def cli_name(value)
      @cli_name = value if value
      @cli_name
    end

    def description(value)
      @description = value if value
      @description
    end
  end

  short_header "NewVal"
  header       "New Validation"
  cli_name     "all"
  description  "No description available."

  ##
  # Initilizes the object
  # Params:  
  # +type+: type of the predicted sequence (:nucleotide or :protein)
  # +prediction+: a +Sequence+ object representing the blast query
  # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
  # +argv+: aditional arguments if needed
  def initialize(type, prediction, hits = nil, *argv)
    @type = type
    @prediction = prediction
    @hits = hits
    @running_time = 0
    @validation_report = ValidationReport.new("Not enough evidence")
  end

  attr_accessor :type
  attr_accessor :prediction
  attr_accessor :hits
  attr_accessor :validation_report
  attr_accessor :running_time

  def short_header
    self.class.short_header
  end

  def header
    self.class.header
  end

  def cli_name
    self.class.cli_name
  end

  def description
    self.class.description
  end

  def run
    start = Time.now
    yield
    @running_time = Time.now - start
    #raise 'run method should be implemented by all classes that extend ValidationTest'
  end  
end
