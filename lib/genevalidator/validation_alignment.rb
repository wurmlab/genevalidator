require 'genevalidator/validation_output'
require 'genevalidator/exceptions'

##
# Class that stores the validation output information
class AlignmentValidationOutput < ValidationReport

  attr_reader :gaps
  attr_reader :extra_seq
  attr_reader :consensus
  attr_reader :threahsold

  def initialize (gaps = 0, extra_seq = 0, consensus = 1, threshold = 0.2, expected = :yes)
    @gaps = gaps
    @extra_seq = extra_seq
    @consensus = consensus
    @threshold = threshold
    @result = validation
    @expected = expected
    @plot_files = []
  end

  def print
    "#{(gaps*100).round(0)}% missing, #{(extra_seq*100).round(0)}% extra, #{(consensus*100).round(0)}% conserved"
  end

  def validation
    if gaps < @threshold and extra_seq < @threshold #and consensus < @threshold
      :yes
    else
      :no
    end
  end

end

##
# This class contains the methods necessary for
# validations based on multiple alignment
class AlignmentValidation < ValidationTest

  attr_reader :filename
  attr_reader :multiple_alignment
  attr_reader :mafft_path

  def initialize(type, prediction, hits, filename, mafft_path)
    super
    @filename = filename
    @mafft_path = mafft_path
    @short_header = "MA"
    @header = "Missing/Extra sequences"
    @description = "Finds missing and extra sequences in the prediction, based"<<
    " on the multiple alignment of the best hits. Meaning of the output displayed:"<<
    " the percentages of the missing/extra sequences with respect to the multiple"<<
    " alignment. Validation fails if one of these values is higher than 20%"
    @multiple_alignment = []
    @cli_name = "align"
  end

  ##
  # Find gaps/extra regions based on the multiple alignment 
  # of the first n hits
  # Output:
  # +AlignmentValidationOutput+ object
  def run(n=10)    
    begin
      if n > 50
        n = 50
      end

      raise NotEnoughHitsError unless hits.length >= n
      raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence
      start = Time.new
      # get the first n hits
      less_hits = @hits[0..[n-1,@hits.length].min]
      useless_hits = []
      begin
        # get raw sequences for less_hits
        less_hits.map do |hit| 
          if hit.raw_sequence == nil
            #get gene by accession number
            if hit.type == :protein
              hit.get_sequence_by_accession_no(hit.accession_no, "protein")
            else
              hit.get_sequence_by_accession_no(hit.accession_no, "nucleotide")
            end
            if hit.raw_sequence == ""
              useless_hits.push(hit)
            end         
          end
        end
      end
      useless_hits.each{|hit| less_hits.delete(hit)}

      begin
        # multiple align sequences from  less_hits with the prediction
        multiple_align_mafft(prediction, less_hits)
      rescue Exception => error
        raise NoInternetError
      end
      
      sm  = get_sm_pssm(@multiple_alignment[0..@multiple_alignment.length-2])


      # remove isolated residues from the predicted sequence
      prediction_raw = remove_isolated_residues(@multiple_alignment[@multiple_alignment.length-1])
      # remove isolated residues from the statistical model
      sm = remove_isolated_residues(sm)
  
      plot1 = plot_alignment(sm)
      gaps = gap_validation(prediction_raw, sm)
      extra_seq = extra_sequence_validation(prediction_raw, sm)      
      consensus = consensus_validation(prediction_raw, get_consensus(@multiple_alignment[0..@multiple_alignment.length-2]))
      @validation_report = AlignmentValidationOutput.new(gaps, extra_seq, consensus)        
      @validation_report.plot_files.push(plot1)
      @running_time = Time.now - start
      return @validation_report

    # Exception is raised when blast founds no hits
    rescue  NotEnoughHitsError => error
      @validation_report = ValidationReport.new("Not enough evidence", :warning)
      return @validation_report
    rescue NoMafftInstallationError
      @validation_report = ValidationReport.new("Unexpected error", :error)
      @validation_report.errors.push NoMafftInstallationError
      return @validation_report
    rescue NoInternetError
      @validation_report = ValidationReport.new("Unexpected error", :error)
      @validation_report.errors.push NoInternetError
      return @validation_report
    rescue Exception => error
      puts error.backtrace
      @validation_report.errors.push "Unexpected Error"
      @validation_report = ValidationReport.new("Unexpected error", :error)
      @validation_report.errors.push OtherError
      return @validation_report
    end
  end

  ##
  # Builds the multiple alignment between 
  # all the hits and the prediction
  # using MAFFT tool
  # Also creates a fasta file with the alignment
  # Params:
  # +prediction+: a +Sequence+ object representing the blast query
  # +hits+: a vector of +Sequience+ objects (usually representig the blast hits)
  # Output:
  # Array of +String+s, corresponding to the multiple aligned sequences
  def multiple_align_mafft(prediction = @prediction, hits = @hits, path = @mafft_path)
    raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence

      options = ['--maxiterate', '1000', '--localpair', '--quiet']
      mafft = Bio::MAFFT.new(path, options)
      sequences = hits.map{|hit| hit.raw_sequence}
      sequences.push(prediction.raw_sequence)

      report = mafft.query_align(sequences)
      # Accesses the actual alignment.
      align = report.alignment

      # Prints each sequence to a file.
      f = File.open("#{@filename}_ma.fasta" , "w")
      align.each_with_index do |s,i|
         @multiple_alignment.push(s.to_s)
         f.write(">seq#{i}\n")
         f.write(s.to_s)
         f.write("\n")
      end
      f.close

      return @multiple_alignment
  end

  ##
  # Returns the consensus regions among 
  # a set of multiple aligned sequences
  # i.e positions where there is the same 
  # element in all sequences
  # Params:
  # +ma+: array of +String+s, corresponding to the multiple aligned sequences
  # Output:
  # +String+ with the consensus regions
  def get_consensus(ma = @multiple_alignment)
    align = Bio::Alignment.new(ma)
    consensus = align.consensus
  end

  ##
  # Returns the percentage of gaps in the prediction 
  # with respect to the statistical model
  # Params:
  # +prediction+: +String+ corresponding to the prediction sequence
  # +sm+: +String+ corresponding to the statistical model
  # Output:
  # +Fixnum+ with the score
  def gap_validation(prediction_raw, sm)
    # find gaps in the prediction and
    # not in the statistical model
    if prediction_raw.length != sm.length
      return 1
    end
    no_gaps = 0
    (0..sm.length-1).each do |i|
      if prediction_raw[i] == '-' and  sm[i]!='-'
        no_gaps += 1
      end
    end
    no_gaps/(sm.length+0.0)
  end

  ##
  # Returns the percentage of extra sequences in the prediction 
  # with respect to the statistical model
  # Params:
  # +prediction+: +String+ corresponding to the prediction sequence
  # +sm+: +String+ corresponding to the statistical model
  # Output:
  # +Fixnum+ with the score
  def extra_sequence_validation(prediction_raw, sm)
    if prediction_raw.length != sm.length
      return 1
    end
    # find residues that are in the prediction
    # but not in the statistical model
    no_insertions = 0
    (0..sm.length-1).each do |i|
      if prediction_raw[i] != '-' and  sm[i]=='-'
        no_insertions += 1
      end
    end
    no_insertions/(sm.length+0.0)
    
  end

  ##
  # Returns the percentage of consesnsus residues from the ma
  # that are in the prediction 
  # Params:
  # +prediction+: +String+ corresponding to the prediction sequence
  # +consensus+: +String+ corresponding to the statistical model
  # Output:
  # +Fixnum+ with the score
  def consensus_validation(prediction_raw, consensus)
    if prediction_raw.length != consensus.length
      return 1
    end
    # find consnsus that are in the ma
    # but not in the prediction
    no_conserved_pred = 0
    no_conserved_residues = 0
    (0..consensus.length-1).each do |i|
      if consensus[i] != '-'
        no_conserved_residues += 1 
      end
      if consensus[i] != '-' and prediction_raw[i] == consensus[i]
        no_conserved_pred  += 1
      end
    end
    return no_conserved_pred/(no_conserved_residues + 0.0)
  end

  ##
  # Builds a statistical model from 
  # a set of multiple aligned sequences
  # based on PSSM (Position Specific Matrix)
  # Params:
  # +ma+: array of +String+s, corresponding to the multiple aligned sequences
  # Output:
  # +String+ representing the statistical model
  def get_sm_pssm(ma = @multiple_alignment, threshold = 0.7)
    sm = ""
    (0..ma[0].length-1).each do |i|
      freqs = Hash.new(0)
      ma.map{|seq| seq[i]}.each{|res| freqs[res] += 1}
      # get the residue with the highest frequency
      max_freq = freqs.map{|res, n| n}.max
      if max_freq/(ma.length+0.0) >= threshold
        residue = (freqs.map{|res, n| n == max_freq ? res : []}.flatten)[0]
        sm << residue
      else
        sm << "?"
      end
    end
    sm
  end

  ##
  # Remove isolated residues inside long gaps 
  # from a given sequence
  # Params:
  # +String+: sequence of residues
  # +Fixnum+: number of isolated residues to be removed
  # Output:
  # +String+: the new sequence
  def remove_isolated_residues(seq, len = 2)
    #puts seq
    gap_starts = seq.to_enum(:scan,/(-\w{1,#{len}}-)/i).map{|m| $`.size + 1}
    #puts gap_starts.to_s
    # remove isolated residues 
    gap_starts.each do |i|
      (i..i+len-1).each do |j|
        if isalpha(seq[j])
          seq[j] = '-'
        end
      end
    end
    #remove isolated gaps
    res_starts = seq.to_enum(:scan,/([?\w]-{1,2}[?\w])/i).map{|m| $`.size + 1}
    res_starts.each do |i|
      (i..i+len-1).each do |j|
        if seq[j] == '-'
          seq[j] = '?'
        end
      end
    end
    seq
  end

  ##
  # Returns true if the string contains only letters
  # and false otherwise
  def isalpha(str)
    !str.match(/[^A-Za-z]/)
  end

  # Generates a json file cotaining data used for plotting
  # lines for multiple hits alignment, prediction and statistical model
  # Params:
  # +output+: filneme of the json file
  # +ma+: +String+ array with the multiple alignmened hits and prediction
  # +prediction+: +Sequence+ object
  # +sm+: +String+ with the statistical model
  def plot_alignment (output = "#{@filename}_ma.json", ma = @multiple_alignment, prediction = @prediction, sm)

      # get indeces of consensus in the multiple alignment
      consensus = get_consensus(@multiple_alignment[0..@multiple_alignment.length-2])
      consensus_idxs = consensus.split(//).each_index.select{|j| isalpha(consensus[j])}

      len = ma[0].length

      f = File.open(output , "w")
      f.write((ma[0..ma.length-2].each_with_index.map{ |seq, j| {"y"=>ma.length-j, "start"=>0, "stop"=>len, "color"=>"red"}} +
      ma[0..ma.length-2].each_with_index.map{|seq, j| seq.split(//).each_index.select{|j| seq[j] == '-'}.map{|gap| {"y"=>ma.length-j, "start"=>gap, "stop"=>gap+1, "color"=>"black"}}}.flatten +
      ma[0..ma.length-2].each_with_index.map{|seq, j| consensus_idxs.map{|con|{"y"=>ma.length-j, "start"=>con, "stop"=>con+1, "color"=>"yellow"}}}.flatten +
      #plot prediction
      [{"y"=>1, "start"=>0, "stop"=>len, "color"=>"green"}] +
      ma[ma.length-1].split(//).each_index.select{|j| ma[ma.length-1][j] == '-'}.map{|gap|{"y"=>1, "start"=>gap, "stop"=>gap+1, "color"=>"black"}} +
      #plot statistical model
      [{"y"=>0, "start"=>0, "stop"=>len, "color"=>"red"}] +
      sm.split(//).each_index.select{|j| isalpha(sm[j])}.map{|con|{"y"=>0, "start"=>con, "stop"=>con+1, "color"=>"orange"}} +
      sm.split(//).each_index.select{|j| sm[j] == '-'}.map{|gap|{"y"=>0, "start"=>gap, "stop"=>gap+1, "color"=>"black"}}).to_json)
      f.close

      yAxisValues = "sm, pred"
      (1..ma.length-1).each do |i|
         yAxisValues << ", hit#{ma.length - i}"
      end

      return Plot.new(output.scan(/\/([^\/]+)$/)[0][0],
                                :lines,
                                "Multiple alignment and Statistical model of blast hits",
                                "gaps, black;consensus, yellow;mismatches, red;prediction, green;statistical model,orange",
                                "alignment length",
                                "idx",
                                ma.length+1,
                                yAxisValues)

  end

end

