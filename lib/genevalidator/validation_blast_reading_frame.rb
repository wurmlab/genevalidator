require 'genevalidator/validation_report'

##
# Class that stores the validation output information
class BlastRFValidationOutput < ValidationReport

  attr_reader :frames_histo
  attr_reader :msg

  def initialize (frames_histo, expected = :yes)

    @short_header = "Frame"
    @header       = "Reading Frame"
    @description  = "Check whether there is a single reading frame among BLAST"<<
    " hits. Otherwise there might be a reading frame shift in the query sequence."<<
    " Meaning of the output displayed: (reading frame: no hsps)"

    @frames_histo = frames_histo
    @msg = ""
    frames_histo.each do |x, y|
      @msg << "#{x}:#{y}; "      
    end
    @expected = expected
    @result = validation
  end

  def print
    @msg
  end

  def validation
    # chack if there are different reading frames 
    count_p = 0
    count_n = 0
    frames_histo.each do |x, y|
      if x > 0
        count_p += 1
      else
        if x < 0
          count_n += 1
        end
      end
    end

    if count_p > 1 or count_n > 1
      :no
    else
      :yes
    end

  end
end

##
# This class contains the methods necessary for 
# reading frame validation based on BLAST output
class BlastReadingFrameValidation < ValidationTest

  def initialize(type, prediction, hits = nil)
    super
    @short_header = "Frame"
    @header       = "Reading Frame"
    @description  = "Check whether there is a single reading frame among BLAST"<<
    " hits. Otherwise there might be a reading frame shift in the query sequence."<<
    " Meaning of the output displayed: (reading frame: no hsps)"
    @cli_name     = "frame"
  end

  ## 
  # Check reading frame inconsistency
  # Params:
  # +lst+: vector of +Sequence+ objects
  # Output:
  # +BlastRFValidationOutput+ object
  def run(lst = @hits)
    begin
      if type.to_s != "nucleotide"
        @validation_report = ValidationReport.new("", :unapplicable)
        return @validation_report
      end

      raise NotEnoughHitsError unless hits.length >= 5
      raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence

      start = Time.now

      rfs =  lst.map{ |x| x.hsp_list.map{ |y| y.query_reading_frame}}.flatten
      frames_histo = Hash[rfs.group_by { |x| x }.map { |k, vs| [k, vs.length] }]

      # get the main reading frame 
      main_rf = frames_histo.map{|k,v| v}.max
      @prediction.nucleotide_rf = frames_histo.select{|k,v| v==main_rf}.first.first

      @validation_report = BlastRFValidationOutput.new(frames_histo)
      @validation_report.running_time = Time.now - start
      return @validation_report

    # Exception is raised when blast founds no hits
    rescue  NotEnoughHitsError => error
      @validation_report = ValidationReport.new("Not enough evidence", :warning, @short_header, @header, @description)
      return @validation_report
    rescue Exception => error
      @validation_report = ValidationReport.new("Unexpected error", :error, @short_header, @header, @description)
      return @validation_report
    end
  end
end

