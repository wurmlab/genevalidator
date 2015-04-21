require 'genevalidator/validation_report'
require 'bio'
module GeneValidator
  ##
  # Class that stores the validation output information
  class ORFValidationOutput < ValidationReport
    attr_reader :orfs
    attr_reader :coverage
    attr_reader :threshold
    attr_reader :mainORFFrame
    attr_reader :result

    def initialize(short_header, header, description, orfs, coverage,
                   longest_orf_frame, threshold = 80, expected = :yes)
      @short_header, @header, @description = short_header, header, description

      @orfs         = orfs
      @coverage     = coverage
      @threshold    = threshold
      @expected     = expected
      @result       = validation
      @plot_files   = []
      @mainORFFrame = longest_orf_frame
      @approach     = 'We expect the query sequence to encode a single gene,' \
                      ' thus it should contain one main Open Reading Frame' \
                      ' (ORF) that occupies most of the query sequence.'
      @explanation  = " The longest ORF is in frame #{@mainORFFrame}, where" \
                      " it occupies #{(@coverage).round}% of the query" \
                      ' sequence.'
      @conclusion   = conclude
    end

    def conclude
      if @result == :yes
        'There is no evidence to believe that there is any problem with the' \
        ' ORF of the query sequence.'
      else
        'This only represents a portion of the query sequence. In some cases' \
        ' this indicates that a frame shift exists in the query sequence.'
      end
    end

    def print
      @orfs.map { |elem| elem[1].length }.reduce(:+)
      orf_list = ''
      @orfs.map { |elem| orf_list << "#{elem[0]}:#{elem[1]}," }

      "#{(@coverage).round}%&nbsp;(frame&nbsp;#{@mainORFFrame})"
    end

    def validation
      (@coverage > @threshold) ? :yes : :no
    end
  end

  ##
  # This class contains the methods necessary for checking whether there is
  # a main Open Reading Frame in the predicted sequence
  class OpenReadingFrameValidation < ValidationTest
    attr_reader :filename

    ##
    # Initilizes the object
    # Params:
    # +type+: type of the predicted sequence (:nucleotide or :protein)
    # +prediction+: a +Sequence+ object representing the blast query
    # +hits+: a vector of +Sequence+ objects (representing blast hits)
    # +plot_filename+: name of the input file, used when making plot files
    def initialize(type, prediction, hits, filename)
      super
      @short_header = 'ORF'
      @header       = 'Main ORF'
      @description  = 'Check whether there is a single main Open Reading' \
                      ' Frame in the predicted gene. Applicable only for' \
                      ' nucleotide queries.'
      @cli_name     = 'orf'
      @filename     = filename
    end

    ##
    # Check whether there is a main reading frame
    # Output:
    # +ORFValidationOutput+ object
    def run
      if type.to_s != 'nucleotide'
        @validation_report = ValidationReport.new('', :unapplicable)
        return @validation_report
      end

      fail Exception unless prediction.is_a?(Sequence)

      start = Time.new
      orfs = get_orfs

      longest_orf       = orfs.sort_by { |_key, hash| hash[:coverage] }.last
      longest_orf_frame = longest_orf[1][:frame]
      coverage          = longest_orf[1][:coverage]
      translated_length = longest_orf[1][:translated_length]
      plot1             = plot_orfs(orfs, translated_length)

      @validation_report = ORFValidationOutput.new(@short_header, @header,
                                                   @description, orfs,
                                                   coverage, longest_orf_frame)
      @validation_report.running_time = Time.now - start

      @validation_report.plot_files.push(plot1)
      @validation_report
    rescue Exception
      @validation_report = ValidationReport.new('Unexpected error', :error,
                                                @short_header, @header,
                                                @description, @approach,
                                                @explanation, @conclusion)
      @validation_report.errors.push 'Unexpected Error'
    end

    ##
    # Find open reading frames in the original sequence
    # Applied only to nucleotide sequences
    # Params:
    # +orf_length+: minimimum ORF length, default 100
    # +prediction+: +Sequence+ object
    # Output:
    # +Hash+ containing the data on ORFs
    def get_orfs(_orf_length = 100, prediction = @prediction)
      '-' if prediction.type != 'nucleotide'

      seq = Bio::Sequence::NA.new(prediction.raw_sequence)

      result = {}
      key = 0
      (1..6).each do |f|
        s = seq.translate(f)
        f = -1 if f == 4
        f = -2 if f == 5
        f = -3 if f == 6
        s.scan(/(\w{30,})/) do |_orf|
          orf_start = $~.offset(0)[0] + 1
          orf_end   = $~.offset(0)[1] + 1
          coverage = (((orf_end - orf_start) / s.length.to_f) * 100).ceil
          # reduce the orf_end and the translated length by 2% to increase the
          #   width between ORFs on the plot
          chopping = s.length * 0.02
          orf_end = (orf_end.to_f - chopping).floor
          translated_length = (s.length - chopping).ceil
          key += 1
          result[key] = { frame: f, orf_start: orf_start, orf_end: orf_end,
                          coverage: coverage,
                          translated_length: translated_length }
        end
      end
      result
    end

    ##
    # Plots the resions corresponding to open reading frames
    # Param
    # +orfs+: +Hash+ containing the open reading frame
    # +output+: location where the plot will be saved in jped file format
    # +prediction+: Sequence objects
    def plot_orfs(orfs, translated_length, output = "#{@filename}_orfs.json")
      fail QueryError unless orfs.is_a? Hash

      results = []

      # Create hashes for the Background
      (-3..3).each do |frame|
        next if frame == 0
        results << { 'y' => frame, 'start' => 1, 'stop' => translated_length,
                     'color' => 'gray' }
      end

      # Create the hashes for the ORFs...
      orfs.each do |_key, h|
        results << { 'y' => h[:frame], 'start' => h[:orf_start],
                     'stop' => h[:orf_end], 'color' => 'red' }
      end

      f = File.open(output, 'w')
      f.write((results).to_json)
      f.close

      Plot.new(output.scan(%r{([^/]+)$})[0][0],
               :lines,
               'Open Reading Frames in all 6 Frames',
               'Open Reading Frame (Minimimum Length: 30 amino acids),red',
               'Offset in the Prediction',
               'Reading Frame',
               14)
    end
  end
end
