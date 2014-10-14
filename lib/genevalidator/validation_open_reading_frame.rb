require 'genevalidator/validation_report'
require 'bio'

##
# Class that stores the validation output information
class ORFValidationOutput < ValidationReport

  attr_reader :orfs
  attr_reader :ratio
  attr_reader :threshold

  def initialize (orfs, ratio, longest_orf_frame, threshold = 0.8, expected = :yes)

    @short_header = "ORF"
    @header       = "Main ORF"
    @description  = 'Check whether there is a single main Open Reading Frame'<<
    ' in the predicted gene. Aplicable only for nucleotide queries.'

    @orfs         = orfs
    @ratio        = ratio
    @threshold    = threshold
    @expected     = expected
    @result       = validation
    @plot_files   = []
    @explanation  = "When translating the query sequence in all 6 frame, the"<<
                    " longest open reading frame is in frame #{longest_orf_frame}"<<
                    " and it covers #{(@ratio*100).round}% of the full sequence"
    @longest_orf_frame = longest_orf_frame
  end

  def print
    no_orfs = @orfs.map{|elem| elem[1].length}.reduce(:+)
    orf_list = ""
    @orfs.map{|elem| orf_list<<"#{elem[0]}:#{elem[1].to_s},"}

    "#{(@ratio*100).round}%&nbsp;(frame&nbsp;#{@longest_orf_frame})"
  end

  def validation
    if @ratio > @threshold
      :yes
    else
      :no    
    end
  end
end

##
# This class contains the methods necessary for
# checking whether there is a main Open Reading Frame
# in the predicted sequence
class OpenReadingFrameValidation < ValidationTest

  attr_reader :filename
  attr_reader :start_codons
  attr_reader :stop_codons

  ##
  # Initilizes the object
  # Params:
  # +type+: type of the predicted sequence (:nucleotide or :protein)
  # +prediction+: a +Sequence+ object representing the blast query
  # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
  # +plot_filename+: name of the input file, used when generatig the plot files
  # +start_codons+: +Array+ of codons
  # +stop_codons+: +Array+ of codons
  def initialize (type, prediction, hits, filename, start_codons = [], stop_codons = [])
    super
    @filename = filename
    @start_codons = start_codons
    @stop_codons = stop_codons
    @short_header = "ORF"
    @header = "Main ORF"
    @description = 'Check whether there is a single main Open Reading Frame'<<
    ' in the predicted gene. Aplicable only for nucleotide queries. Meaning'<<
    '  of the output displayed: %=MAIN ORF COVERAGE. Coverage higher than 80%'<<
    ' passe the validation test.'
    @cli_name = "orf"
  end


  ##
  # Check whether there is a main reading frame
  # Output:
  # +ORFValidationOutput+ object
  def run    
    begin
      if type.to_s != "nucleotide"
        @validation_report = ValidationReport.new("", :unapplicable)
        return @validation_report
      end

      raise NotEnoughHitsError unless hits.length >= 5
      raise Exception unless prediction.is_a? Sequence and 
                             hits[0].is_a? Sequence 

      start = Time.new
      orfs = get_orfs

      # check if longest ORF / prediction > 0.8 (ok)
      prediction_len = prediction.raw_sequence.length
      data = {}
      orfs.each do |frame, all_orfs|
        maxORF =[]
        all_orfs.each do |orf|
          maxORF << orf[1] - orf[0]
        end
        data[frame] = maxORF.max
      end

      longest_orf = data.values.max
      longest_orf_frame = data.key(longest_orf)

      ratio =  longest_orf/(prediction_len + 0.0)

      plot1 = plot_orfs(orfs)

      @validation_report = ORFValidationOutput.new(orfs, ratio, longest_orf_frame)
      @validation_report.running_time = Time.now - start

      @validation_report.plot_files.push(plot1)
      return @validation_report

    rescue  NotEnoughHitsError => error
      @validation_report = ValidationReport.new("Not enough evidence", :warning, @short_header, @header, @description, @explanation)
      return @validation_report
    rescue Exception => error
      @validation_report.errors.push OtherError
      return ValidationReport.new("Unexpected error", :error, @short_header, @header, @description, @explanation)
    end
  end

  ##
  # Find open reading frames in the original sequence
  # Applied only to nucleotide sequences
  # Params:
  # +orf_length+: minimimum ORF length, default 100
  # +prediction+: +Sequence+ object
  # +start_codons+: Array of +String+
  # +stop_codon+: Array of +String+
  # Output:
  # +Hash+ containing the reading frame (the key) and a list of intervals (the values) 
  def get_orfs(orf_length = 100, prediction = @prediction, start_codons = @start_codons, stop_codons = @stop_codons)

    if prediction.type != "nucleotide"
      "-"
    end

    seq = prediction.raw_sequence
    len = seq.length
    stops = {}

    stop_codons.each do |codon|
      occurences = (0 .. seq.length - 1).find_all { |i| seq[i,3].downcase == codon.downcase }
      occurences.each do |occ|
        stops[occ + 3] = codon
      end
    end        

    result = {}
    result[1] = []
    result[2] = []
    result[3] = []
    result[-1] = []
    result[-2] = []
    result[-3] = []

    #direct strand
    #reading frame 1, direct strand
    m3 = stops.map{|x| x[0]}.select{|y| y % 3 == 0}.sort

    m3 = [1, m3, prediction.raw_sequence.length].flatten
    (1..m3.length-1).each do |i|
      if start_codons.length == 0
        if m3[i] - m3[i-1] > orf_length
           result[1].push([m3[i-1], m3[i]])
        end
      else
        start_codons.each do |scd|
#          start_offset = 0
#          unless i == 1
            #find the first occurence of the start codon in the prospective orf            
            start_offset = (m3[i-1]-1..m3[i]-orf_length).find_all{|i| seq[i,3].downcase == scd.downcase}.select{|y| y % 3 == 0}.first
#          end      
          if start_offset != nil and m3[i] - start_offset > orf_length
            result[1].push([start_offset, m3[i]])
          end
        end
      end
    end
 
    #reading frame 2, direct strand
    m3_1 = stops.map{|x| x[0]}.select{|y| y % 3 == 1}.sort
    m3_1 = [2, m3_1, prediction.raw_sequence.length].flatten
    (1..m3_1.length-1).each do |i|
      if start_codons.length == 0
        if m3_1[i] - m3_1[i-1] > orf_length
           result[2].push([m3_1[i-1], m3_1[i]])
        end
      else
        start_codons.each do |scd|
          start_offset = (m3_1[i-1]-1..m3_1[i]-orf_length).find_all{|i| seq[i,3].downcase == scd.downcase}.select{|y| y % 3 == 1}.first
          if start_offset != nil and m3_1[i] - start_offset > orf_length
            result[2].push([start_offset, m3_1[i]])
          end
        end
      end
    end

    #reading frame 3, direct strand
    m3_2 = stops.map{|x| x[0]}.select{|y| y % 3 == 2}.sort
    m3_2 = [3, m3_2, prediction.raw_sequence.length].flatten
    (1..m3_2.length-1).each do |i|
      if start_codons.length == 0
        if m3_2[i] - m3_2[i-1] > orf_length
           result[3].push([m3_2[i-1], m3_2[i]])
        end
      else
        start_codons.each do |scd|
          start_offset = (m3_2[i-1]-1..m3_2[i]-orf_length).find_all{|i| seq[i,3].downcase == scd.downcase}.select{|y| y % 3 == 2}.first
          if start_offset != nil and m3_2[i] - start_offset > orf_length
             result[3].push([start_offset, m3_2[i]])
          end
        end
      end
    end

    #reverse strand
    stops_reverse = {}
    
    seq_reverse = Bio::Sequence::NA.new(seq).reverse_complement
    stop_codons.each do |codon|
      occurences = (0 .. seq_reverse.length - 1).find_all { |i| seq_reverse[i,3].downcase == codon.downcase }
      occurences.each do |occ|
        stops_reverse[occ + 3] = codon
      end
    end

    m3 = stops_reverse.map{|x| x[0]}.select{|y| y % 3 == 0}.sort
    m3 = [1, m3, prediction.raw_sequence.length].flatten

    (1..m3.length-1).each do |i|
      if start_codons.length == 0
        if m3[i] - m3[i-1] > orf_length
          result[-1].push([len - m3[i], len - m3[i-1]])
        end
      else
        start_codons.each do |scd|
          start_offset = (m3[i-1]-1..m3[i]-orf_length).find_all{|i| seq_reverse[i,3].downcase == scd.downcase}.select{|y| y % 3 == 0}.first
          if start_offset != nil and m3[i] - start_offset > orf_length
            result[-1].push([len - m3[i], len - start_offset])
          end
        end
      end
    end

    m3_1 = stops_reverse.map{|x| x[0]}.select{|y| y % 3 == 1}.sort
    m3_1 = [2, m3_1, prediction.raw_sequence.length].flatten
    (1..m3_1.length-1).each do |i|
      if start_codons.length == 0
        if m3_1[i] - m3_1[i-1] > orf_length
          result[-2].push([len - m3_1[i], len - m3_1[i-1]])
        end
      else
        start_codons.each do |scd|
          start_offset = (m3_1[i-1]-1..m3_1[i]-orf_length).find_all{|i| seq_reverse[i,3].downcase == scd.downcase}.select{|y| y % 3 == 1}.first
          if start_offset != nil and m3_1[i] - start_offset > orf_length
            result[-2].push([len - m3_1[i], len - start_offset])
          end
        end
      end
    end

    m3_2 = stops_reverse.map{|x| x[0]}.select{|y| y % 3 == 2}.sort
    m3_2 = [3, m3_2, prediction.raw_sequence.length].flatten
    (1..m3_2.length-1).each do |i|
      if start_codons.length == 0
        if m3_2[i] - m3_2[i-1] > orf_length
          result[-3].push([len - m3_2[i], len - m3_2[i-1]])
        end
      else
        start_codons.each do |scd|
          start_offset = (m3_2[i-1]-1..m3_2[i]-orf_length).find_all{|i| seq_reverse[i,3].downcase == scd.downcase}.select{|y| y % 3 == 2}.first
          if start_offset != nil and m3_2[i] - start_offset > orf_length
             result[-3].push([len - m3_2[i], len - start_offset])
          end
        end
      end
    end

    result 
  end  

  ##  
  # Plots the resions corresponding to open reading frames
  # Param
  # +orfs+: +Hash+ containing the reading frame (the key) and a list of intervals (the values)
  # +output+: location where the plot will be saved in jped file format
  # +prediction+: Sequence objects
  def plot_orfs(orfs, output = "#{@filename}_orfs.json", prediction = @prediction)
    raise QueryError unless orfs.is_a? Hash

    len = prediction.raw_sequence.length
    chopping = len*0.02
    results = []

    # Create hashes for the Background
    (-3..3).each do |frame|
      next if frame == 0
      results << {"y"=>frame, "start"=>0, "stop"=>len-chopping, "color"=>"gray"}
    end

    # Create the hashes for the ORFs...
    orfs.each do |frame, all_orfs|
      all_orfs.each do |orf|
        results << {"y"=>frame, "start"=>orf[0], "stop"=>orf[1]-chopping, "color"=>"red"}
      end
    end

    f = File.open(output, "w")    
    f.write((results).to_json)
    f.close

    return Plot.new(output.scan(/\/([^\/]+)$/)[0][0],
                    :lines,
                    "Open reading frame with STOP codon",
                    "",
                    "offset in the prediction",
                    "Reading Frame",
                    14)

  end
end
