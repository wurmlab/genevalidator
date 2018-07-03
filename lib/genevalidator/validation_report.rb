# Top level module / namespace.
module GeneValidator
  Plot = Struct.new(:data, :type, :title, :footer, :xtitle, :ytitle, :aux1,
                    :aux2)

  ##
  # This is an abstract class extended by
  # all validation reports
  class ValidationReport
    attr_reader :message
    attr_reader :plot_files
    attr_reader :result
    attr_reader :expected
    attr_reader :validation_result
    attr_reader :errors
    attr_accessor :short_header
    attr_accessor :header
    attr_accessor :description
    attr_accessor :run_time
    attr_accessor :approach
    attr_accessor :explanation
    attr_accessor :conclusion

    ##
    # Initilizes the object
    # Params:
    # +message+: result of the validation (to be displayed in the output)
    # +validation_result+: :yes for pass validation, :no for fail, :unapplicable
    # or :error
    # +short_header+: String
    # +header+: String
    # +description+: String
    # by default)
    def initialize(message = 'Not enough evidence', validation_result = :no,
                   short_header = '', header = '', description = '',
                   approach = '', explanation = '', conclusion = '')
      @message           = message
      @errors            = []
      @result            = validation_result
      @expected          = :yes
      @validation_result = validation_result
      @short_header      = short_header
      @header            = header
      @description       = description
      @approach          = approach
      @explanation       = explanation
      @conclusion        = conclusion
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
      if validation == @expected
        'success'
      elsif validation == :error || validation == :unapplicable
        'warning'
      else
        validation == :warning ? 'warning' : 'danger'
      end
    end
  end
end
