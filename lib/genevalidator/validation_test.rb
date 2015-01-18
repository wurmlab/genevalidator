module GeneValidator
  # This is an abstract class extended
  # by all validation classes
  class ValidationTest

    attr_accessor :type
    attr_accessor :prediction
    attr_accessor :hits
    attr_accessor :short_header
    attr_accessor :header
    attr_accessor :cli_name
    attr_accessor :description
    attr_accessor :validation_report
    attr_accessor :running_time

    ##
    # Initilizes the object
    # Params:
    # +type+: type of the predicted sequence (:nucleotide or :protein)
    # +prediction+: a +Sequence+ object representing the blast query
    # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
    # +argv+: aditional arguments if needed
    def initialize(type, prediction, hits = nil, *argv)
      @type              = type
      @prediction        = prediction
      @hits              = hits
      @short_header      = "NewVal"
      @header            = "New Validation"
      @running_time      = 0
      @cli_name          = "all"
      @description       = "No description available."
      @validation_report = ValidationReport.new("Not enough evidence")
    end

    def run
     raise 'run method should be implemented by all classes that extend ValidationTest'
    end
  end
end