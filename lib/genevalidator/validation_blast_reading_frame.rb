require 'genevalidator/validation_report'

##
# Class that stores the validation output information
class BlastRFValidationOutput < ValidationReport

  attr_reader :frames_histo
  attr_reader :msg

  def initialize (frames_histo, expected = :yes)

    @short_header = 'Frame'
    @header       = 'Reading Frame'
    @description  = 'Check whether there is a single reading frame among' \
                    ' BLAST hits. Otherwise there might be a reading frame' \
                    ' shift in the query sequence.'
    @frames_histo = frames_histo
    @expected     = expected
    @result       = validation
    
    @msg          = ''
    @explaination_part = ''
    @totalHSP     = 0
    @frames_histo.each do |x, y|
      @msg               << "#{y}&nbsp;HSPs&nbsp;in&nbsp;frame&nbsp;#{x}; "
      @explaination_part << "#{y} HSPs were found to align within frame #{x}; "
      @totalHSP += y.to_i
    end

    @approach     = 'If the query sequence encodes a single gene, we expect' \
                    ' it to contain a single Open Reading Frame (ORF). Thus' \
                    ' all BLAST hits are expected to align within a single ORF.'
    @explanation  = explain
    @conclusion   = conclude

  end

  def explain 
    exp1 = "BLAST analysis produced #{@totalHSP} High-scoring Segment Pairs" \
           " (HSPs), of which"
    if @result == :yes # i.e. if there is only one ORF...
      frame = @frames_histo.keys[0].to_s
      exp2  = ", all were found to align within frame #{frame}."
    else
      exp2 = ": #{@explaination_part.gsub(/;$/, '')}."
    end
    exp1 + exp2
  end

  def conclude
    if @result == :yes # i.e. if there is only one ORF...
      'As all of HSPs align within a single ORF, there is no reason to' \
      ' believe there is any problem with the ORF of the query sequence.'
    else
      'As not all HSPs align within a single ORF, there may be a frame shift' \
      ' in the query sequence.'
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

    @validation_report = BlastRFValidationOutput.new(frames_histo)
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
