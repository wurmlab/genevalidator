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
    @msg          = ''
    @expected     = expected
    @result       = validation
    @totalHSP     = 0
    @approach     = ''
    @explanation  = put_together_explanation
    @conclusion   = ''

    @explaination_part = ''
    @frames_histo.each do |x, y|
      @msg               << "#{y}&nbsp;HSPs&nbsp;in&nbsp;frame&nbsp;#{x}; "
      @explaination_part << "#{y} HSPs had a main ORF of frame #{x}; "

      @totalHSP += y.to_i
    end
  end

  def put_together_explanation
    approach      = "If the query sequence is well conserved and homologous" \
                    " sequences derived from the reference database are" \
                    " correct, we would expect that the main open reading" \
                    " frame (ORF) of each homologous sequence to match the" \
                    " main open reading frame of the query sequence. "
    explanation1  = "BLAST Analysis of the query sequence produced" \
                    " #{@totalHSP} High-scoring Segment Pairs (HSPs), "
    if @result == :yes
      # i.e. there is only one ORF...
      explanation2 = "of which, all had a main open reading frame of" \
                     " frame #{@frames_histo.keys[0].to_s}. "
      conclusion   = "Since all of the HSPs are in a single open reading" \
                     " frame, we can be relatively confident about the query"
    else
      explanation2 = "of which: #{@explaination_part}. "
      conclusion   = "Since all of the HSPs are not all in a single ORF," \
                     " we are not as confident about the query. This may" \
                     " suggest a frame shift in the query."
    end
    approach + explanation1 + explanation2 + conclusion
  end

  def print
    @msg.gsub(/; $/, '')
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
    begin
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
end
