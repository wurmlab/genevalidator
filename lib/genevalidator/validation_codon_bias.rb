require 'genevalidator/validation_report'
require 'genevalidator/codon_bias'
require 'genevalidator/exceptions'

##
# Class that stores the validation output information
class CodonBiasValidationOutput < ValidationReport

  attr_reader :codon_bias

  def initialize (codon_bias, threshold = 0.2, expected = :yes)

    @short_header = "CodonBias"
    @header = "Codon Bias"
    @description = "Check if the codon bias of the coding parts of the prediction"<<
    " fits the codon bias of the whole genome dataset."

    @codon_bias = codon_bias
    @threshold = threshold
    @result = validation
    @expected = expected
  end

  def print
    "pass"
  end

  def validation
    :yes
=begin
    if gaps < @threshold and extra_seq < @threshold and (1-consensus) < @threshold
      :yes
    else
      :no
    end
=end
  end

end

##
# This class contains the methods necessary for
# validations based on multiple alignment
class CodonBiasValidation < ValidationTest

  ##
  # Initilizes the object
  # Params:  
  # +type+: type of the predicted sequence (:nucleotide or :protein)
  # +prediction+: a +Sequence+ object representing the blast query
  # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
  def initialize(type, prediction, hits)
    super

    @short_header = "CodonBias"
    @header = "Codon Bias"
    @description = "Check if the codon bias of the coding parts of the prediction"<<
    " fits the codon bias of the whole genome dataset."
    @cli_name = "codon"

  end

  ##
  # Find gaps/extra regions based on the multiple alignment
  # of the first n hits
  # Output:
  # +AlignmentValidationOutput+ object
#  def self.codonBias
  def run

    begin
      raise NotEnoughHitsError unless hits.length >= 1
      raise Exception unless prediction.is_a? Sequence and
                             hits[0].is_a? Sequence

    start = Time.now

    # in case of nucleotide prediction sequence translate into protein
    # translate with the reading frame of all hits considered for the alignment

    less_hits = @hits[0..[10,@hits.length].min]
    reading_frames = less_hits.map{|hit| hit.reading_frame}.uniq
    if reading_frames.length != 1
      raise ReadingFrameError
    end

    if @type == :nucleotide
      s = Bio::Sequence::NA.new(prediction.raw_sequence)
      prediction.protein_translation = s.translate(reading_frames[0])
    end

    # compute the codon bias for the prediction
    ala = CodonBias.new("A", "ALA", "Alanine", ["GCA", "GCC", "GCG", "GCT"])
    asx = CodonBias.new("B", "ASX","Asparagine", ["AAC", "AAT", "GAC", "GAT"])
    cys = CodonBias.new("C", "CYS", "Cysteine", ["TGC", "TGT"])
    asp = CodonBias.new("D", "ASP", "Aspartic acid", ["GAC", "GAT"])
    glu = CodonBias.new("E", "GLU", "Glutamic acid", ["GAA", "GAG"])
    phe = CodonBias.new("F", "PHE", "Phenylalanine", ["TTC", "TTT"])
    gle = CodonBias.new("G", "GLE", "Glycine", ["GGA", "GGC", "GGG", "GGT"])
    his = CodonBias.new("H", "HIS", "Histidine", ["CAC", "CAT"])
    ile = CodonBias.new("I", "ILE", "Isoleucine", ["ATA", "ATC", "ATT"])
    lys = CodonBias.new("K", "LYS", "Lysine", ["AAA", "AAG"])
    leu = CodonBias.new("L", "LEU", "Leucine", ["CTA", "CTC", "CTG", "CTT", "TTA", "TTG"])
    met = CodonBias.new("M", "MET", "Methionine", ["ATG"])
    asl = CodonBias.new("N", "ASL", "Asparagine", ["AAC", "AAT"])
    pro = CodonBias.new("P", "PRO", "Proline", ["CCA", "CCC", "CCG", "CCT"])
    gln = CodonBias.new("Q", "GLN", "Glutamine", ["CAA", "CAG"])
    arg = CodonBias.new("R", "ARG", "Arginine", ["AGA", "AGG", "CGA", "CGC", "CGG", "CGT"])
    ser = CodonBias.new("S", "SER", "Serine", ["AGC", "AGT", "TCA", "TCC", "TCG", "TCT"])
    thr = CodonBias.new("T", "THR", "Threonine", ["ACA", "ACC", "ACG", "ACT"])
    val = CodonBias.new("V", "VAL", "Valine", ["GTA", "GTC", "GTG", "GTT"])
    trp = CodonBias.new("W", "TRP", "Tryptophan", ["TGG"])
    tyr = CodonBias.new("Y", "TYR", "Tyrosine", ["TAC", "TAT"])
    glx = CodonBias.new("Z", "GLX", "Glutamine", ["CAA", "CAG", "GAA", "GAG"])

    map_codon_aa = {"GCA"=>ala,"GCC"=>ala,"GCG"=>ala, "GCT"=>ala, "AAC"=>asx, "AAT"=>asx, "GAC"=>asx, "GAT"=>asx}
    amino_acids = ['F', 'L', 'I', 'M', 'V', 'S', 'P', 'T', 'A', 'Y', 'H', 'Q', 'N', 'K', 'D', 'E', 'C', 'W', 'R', 'G']
    codon_bias = {}
    amino_acids.each do |aa|
      codon_bias[aa] = prediction.protein_translation.upcase.count(aa)/(prediction.protein_translation.length + 0.0)  
    end

    puts codon_bias.to_s

    sum = 0
    amino_acids.each do |aa|
      sum = sum + codon_bias[aa]
    end
    puts sum

    @validation_report = CodonBiasValidationOutput.new(codon_bias)
    @validation_report.running_time = Time.now - start

    return @validation_report

    # Exception is raised when blast founds no hits
    rescue  NotEnoughHitsError => error
      @validation_report = ValidationReport.new("Not enough evidence", :warning, @short_header, @header, @description)
      return @validation_report
    rescue ReadingFrameError => error
      @validation_report = ValidationReport.new("Multiple reading frames", :error, @short_header, @header, @description)
      return @validation_report
    rescue Exception => error
      puts error.backtrace
      @validation_report.errors.push "Unexpected Error"
      @validation_report = ValidationReport.new("Unexpected error", :error, @short_header, @header, @description)
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
  # +path+: path of mafft installation
  # Output:
  # Array of +String+s, corresponding to the multiple aligned sequences
  # the prediction is the last sequence in the vector
  def multiple_align_mafft(prediction = @prediction, hits = @hits, path = @mafft_path)
    raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence

      options = ['--maxiterate', '1000', '--localpair', '--anysymbol', '--quiet']
      mafft = Bio::MAFFT.new(path, options)
      sequences = hits.map{|hit| hit.raw_sequence}
      sequences.push(prediction.protein_translation)

      report = mafft.query_align(sequences)
      # Accesses the actual alignment.
      align = report.alignment

      align.each_with_index do |s,i|
         @multiple_alignment.push(s.to_s)
      end

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
      if prediction_raw[i] == '-' and sm[i]!='-'
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
      if prediction_raw[i] != '-' and sm[i]=='-'
        no_insertions += 1
      end
    end
    no_insertions/(sm.length+0.0)
    
  end

  ##
  # Returns the percentage of consesnsus residues from the ma
  # that are in the prediction
  # Params:
  # +prediction_raw+: +String+ corresponding to the prediction sequence
  # +consensus+: +String+ corresponding to the statistical model
  # Output:
  # +Fixnum+ with the score
  def consensus_validation(prediction_raw, consensus)

    if prediction_raw.length != consensus.length
      return 1
    end
    # no of conserved residues among the hits
    no_conserved_residues = consensus.length - consensus.scan(/[\?-]/).length

    if no_conserved_residues == 0
      return 1
    end

    # no of conserved residues from the hita that appear in the prediction
    no_conserved_pred = consensus.split(//).each_index.select{|j| consensus[j] != '-' and consensus[j]!='?' and consensus[j] == prediction_raw[j]}.length

    return no_conserved_pred/(no_conserved_residues + 0.0)

  end

  ##
  # Builds a statistical model from
  # a set of multiple aligned sequences
  # based on PSSM (Position Specific Matrix)
  # Params:
  # +ma+: array of +String+s, corresponding to the multiple aligned sequences
  # +threshold+: the percentage of the genes that will be considered in the statistical model
  # Output:
  # +String+ representing the statistical model
  # +Array+ with the maximum frequeny of the majoritary residue for each position
  def get_sm_pssm(ma = @multiple_alignment, threshold = 0.7)
    sm = ""
    freq = []
    (0..ma[0].length-1).each do |i|
      freqs = Hash.new(0)
      ma.map{|seq| seq[i]}.each{|res| freqs[res] += 1}
      # get the residue with the highest frequency
      max_freq = freqs.map{|res, n| n}.max
      residue = (freqs.map{|res, n| n == max_freq ? res : []}.flatten)[0]
      if residue == '-'
        freq.push(0)
      else
        freq.push(max_freq/(ma.length+0.0))
      end

      if max_freq/(ma.length+0.0) >= threshold
        sm << residue
      else
        sm << "?"
      end
    end
    [sm, freq]
  end

  ##
  # Remove isolated residues inside long gaps
  # from a given sequence
  # Params:
  # +seq+:+String+: sequence of residues
  # +len+:+Fixnum+: number of isolated residues to be removed
  # Output:
  # +String+: the new sequence
  def remove_isolated_residues(seq, len = 2)
    gap_starts = seq.to_enum(:scan,/(-\w{1,#{len}}-)/i).map{|m| $`.size + 1}
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

  ##
  # converts an array of integers into array of ranges
  def array_to_ranges(ar)

    prev = ar[0]

    ranges = ar.slice_before { |e|
      prev, prev2 = e, prev
      prev2 + 1 != e
    }.map{|a| a[0]..a[-1]}

    return ranges

  end

  # Generates a json file cotaining data used for plotting
  # lines for multiple hits alignment, prediction and statistical model
  # Params:
  # +freq+: +String+ residue frequency from the statistical model
  # +output+: filneme of the json file
  # +ma+: +String+ array with the multiple alignmened hits and prediction
  def plot_alignment (freq, output = "#{@filename}_ma.json", ma = @multiple_alignment)

      # get indeces of consensus in the multiple alignment
      consensus = get_consensus(@multiple_alignment[0..@multiple_alignment.length-2])
      consensus_idxs = consensus.split(//).each_index.select{|j| isalpha(consensus[j])}
      consensus_ranges = array_to_ranges(consensus_idxs)

      consensus_all = get_consensus(@multiple_alignment)
      consensus_all_idxs = consensus_all.split(//).each_index.select{|j| isalpha(consensus_all[j])}
      consensus_all_ranges = array_to_ranges(consensus_all_idxs)

      match_alignment = ma[0..ma.length-2].each_with_index.map{|seq, j| seq.split(//).each_index.select{|j| isalpha(seq[j])}}
      match_alignment_ranges = []
      match_alignment.each { |arr| match_alignment_ranges << array_to_ranges(arr) }

      query_alignment = ma[ma.length-1].split(//).each_index.select{|j| isalpha(ma[ma.length-1][j])}
      query_alignment_ranges = array_to_ranges(query_alignment)

      len = ma[0].length

      f = File.open(output , "w")
      f.write((
      # plot statistical model
      freq.each_with_index.map{|f, j| {"y"=>ma.length, "start"=>j, "stop"=>j+1, "color"=>"orange", "height"=>f}} +
      # hits
      match_alignment_ranges.each_with_index.map{|ranges, j| ranges.map{ |range| {"y"=>ma.length-j-1, "start"=>range.first, "stop"=>range.last, "color"=>"red", "height"=>-1}}}.flatten +
      ma[0..ma.length-2].each_with_index.map{|seq, j| #consensus_idxs.map{|con|{"y"=>j+1, "start"=>con, "stop"=>con+1, "color"=>"yellow", "height"=>-1}}}.flatten +
                           consensus_ranges.map{ |range| {"y"=>j+1, "start"=>range.first, "stop"=>range.last, "color"=>"yellow", "height"=>-1}}}.flatten +
      # plot prediction
      [{"y"=>0, "start"=>0, "stop"=>len, "color"=>"gray", "height"=>-1}] +
      query_alignment_ranges.map{ |range| {"y"=>0, "start"=>range.first, "stop"=>range.last, "color"=>"red", "height"=>-1}}.flatten +

      # plot consensus
      consensus_all_ranges.map{ |range| {"y"=>0, "start"=>range.first, "stop"=>range.last, "color"=>"yellow", "height"=>-1}}.flatten).to_json)

      f.close

      yAxisValues = "prediction"
      (1..ma.length-1).each do |i|
         yAxisValues << ", hit#{i}"
      end

      yAxisValues << ", statistical model"

      return Plot.new(output.scan(/\/([^\/]+)$/)[0][0],
                                :align,
                                "[Missing/Extra sequences] Multiple Align. & Statistical model of hits",
                                "conserved region, yellow", 
                                "offset in the alignment",
                                "",
                                ma.length+1,
                                yAxisValues)

  end
end
