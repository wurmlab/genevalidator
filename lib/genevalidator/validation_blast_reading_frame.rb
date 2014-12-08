require 'genevalidator/validation_report'

##
# Class that stores the validation output information
class BlastRFValidationOutput < ValidationReport

  attr_reader :frames_histo
  attr_reader :msg

  def initialize(short_header, header, description, frames_histo, expected = :yes)

    @short_header, @header, @description = short_header, header, description
    @frames_histo = frames_histo
    @expected     = expected
    @result       = validation

    @msg          = ''
    @exp_msg      = ''
    @totalHSP     = 0
    @frames_histo.each do |x, y|
      @msg     << "#{y}&nbsp;HSPs&nbsp;align&nbsp;in&nbsp;frame&nbsp;#{x}; "
      @exp_msg << "#{y} HSPs align in frame #{x}; "
      @totalHSP += y.to_i
    end

    @approach     = 'We expect the query sequence to encode a single gene,' \
                    ' thus it should contain one main Open Reading Frame' \
                    '  (ORF). All all BLAST hits are thus expected to align' \
                    ' within this ORF.'
    @explanation  = explain
    @conclusion   = conclude

  end

  def explain 
    exp1 = "BLAST identified #{@totalHSP} High-scoring Segment Pairs" \
           " (HSPs)"
    if @result == :yes # i.e. if there is only one ORF...
      frame = @frames_histo.keys[0].to_s
      exp2  = "; all of these align in frame #{frame}."
    else
      exp2 = ": #{@exp_msg.gsub(/;$/, '')}."
    end
    exp1 + exp2
  end

  def conclude
    if @result == :yes # i.e. if there is only one ORF...
      'This is as expected.'
    else
      'The HSPs align in mulitple reading frames, this suggests there may be' \
      ' a frame shift in the query sequence.'
    end
  end

  def print
    @msg.gsub(/; $/, '')
  end

  def validation
    # chack if there are different reading frames
    count_p = 0
    count_n = 0
    frames_histo.each do |x, y|
      count_p += 1 if x > 0
      count_n += 1 if x < 0
    end

    (count_p > 1 or count_n > 1) ? :no : :yes 

  end
end

##
# This class contains the methods necessary for
# reading frame validation based on BLAST output
class BlastReadingFrameValidation < ValidationTest

  def initialize(type, prediction, hits = nil)
    super
    @short_header = 'Frame'
    @header       = 'Reading Frame'
    @description  = 'Check whether there is a single reading frame among' \
                    ' BLAST hits. Otherwise there might be a reading frame' \
                    ' shift in the query sequence.'
    @cli_name     = 'frame'
  end

  ##
  # Check reading frame inconsistency
  # Params:
  # +lst+: vector of +Sequence+ objects
  # Output:
  # +BlastRFValidationOutput+ object
  def run(lst = @hits)
    if type.to_s != 'nucleotide'
      @validation_report = ValidationReport.new('', :unapplicable)
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

    @validation_report = BlastRFValidationOutput.new(@short_header, @header, @description, frames_histo)
    @validation_report.running_time = Time.now - start
    return @validation_report

  # Exception is raised when blast founds no hits
  rescue  NotEnoughHitsError => error
    @validation_report = ValidationReport.new('Not enough evidence', :warning, @short_header, @header, @description, @approach, @explanation, @conclusion)
    return @validation_report
  rescue Exception => error
    @validation_report = ValidationReport.new('Unexpected error', :error, @short_header, @header, @description, @approach, @explanation, @conclusion)
    return @validation_report
  end
end
