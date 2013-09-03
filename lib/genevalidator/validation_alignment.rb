require 'genevalidator/validation_output'

##
# Class that stores the validation output information
class AlignmentValidationOutput < ValidationReport

  attr_reader :gaps
  attr_reader :extra_seq
  attr_reader :threahsold

  def initialize (gaps = 0, extra_seq = 0, threshold = 0.2, expected = :yes)
    @gaps = gaps
    @extra_seq = extra_seq
    @threshold = threshold
    @result = validation
    @expected = expected
  end

  def print
    "gaps=#{gaps.round(2)}, insertions=#{extra_seq.round(2)}"
  end

  def validation
    if gaps < @threshold and extra_seq < @threshold
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

  def initialize(type, prediction, hits, filename)
    super
    @filename = filename
    @short_header = "MA"
    @header = "Multiple Alignment"
    @description = "Finds gaps/extra regions in the prediction based on the multiple alignment of the best hits. Meaning of the output displayed: gaps= gap coverage insertions= extra sequence coverage. Validation fails if one of these values is higher than 20%"
    @multiple_alignment = []
  end

  ##
  # Find gaps/extra regions based on the multiple alignment 
  # of the first n hits
  # Output:
  # +AlignmentValidationOutput+ object
  def run(n=10)    
    begin
      raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence

      # get the first n hits
      less_hits = @hits[0..[n-1,@hits.length].min]

      # get raw sequences for less_hits
      less_hits.map do |hit| 
        #get gene by accession number
        if hit.seq_type == :protein
          hit.get_sequence_by_accession_no(hit.accession_no, "protein")
        else
          hit.get_sequence_by_accession_no(hit.accession_no, "nucleotide")
        end
      end

      # multiple align sequences from  less_hits with the prediction
      multiple_align_mafft(prediction, less_hits)
      sm  = get_sm_pssm(@multiple_alignment[0..@multiple_alignment.length-2])
      # remove isolated residues from the predicted sequence
      #puts sm
      #puts ""
      sm = remove_isolated_residues(sm)
      #puts sm

      # get indeces of consensus in the multiple alignment
      consensus = get_consensus(@multiple_alignment[0..@multiple_alignment.length-2])
      consensus_idxs = consensus.split(//).each_index.select{|j| isalpha(consensus[j])}

      ma = @multiple_alignment

      len = ma[0].length
      f = File.open("#{@filename}_ma.json" , "w")
      f.write((ma[0..ma.length-2].each_with_index.map{ |seq, j| {"y"=>ma.length-j, "start"=>0, "stop"=>len, "color"=>"red"}} + 
      ma[0..ma.length-2].each_with_index.map{|seq, j| seq.split(//).each_index.select{|j| seq[j] == '-'}.map{|gap| {"y"=>ma.length-j, "start"=>gap, "stop"=>gap+1, "color"=>"black"}}}.flatten +
      ma[0..ma.length-2].each_with_index.map{|seq, j| consensus_idxs.map{|con|{"y"=>ma.length-j, "start"=>con, "stop"=>con+1, "color"=>"yellow"}}}.flatten +
      #plot prediction
      [{"y"=>1, "start"=>0, "stop"=>len, "color"=>"salmon"}] +
      ma[ma.length-1].split(//).each_index.select{|j| ma[ma.length-1][j] == '-'}.map{|gap|{"y"=>1, "start"=>gap, "stop"=>gap+1, "color"=>"black"}} +
      #plot statistical model
      [{"y"=>0, "start"=>0, "stop"=>len, "color"=>"orange"}] +
      sm.split(//).each_index.select{|j| isalpha(sm[j])}.map{|con|{"y"=>0, "start"=>con, "stop"=>con+1, "color"=>"yellow"}} +      
      sm.split(//).each_index.select{|j| sm[j] == '-'}.map{|gap|{"y"=>0, "start"=>gap, "stop"=>gap+1, "color"=>"black"}}).to_json) 

      f.close
      @plot_files.push(Plot.new("#{@filename}_ma.json".scan(/\/([^\/]+)$/)[0][0],
                                :lines,
                                "Multiple alignment and Statistical model of blast hits",
                                "gaps(white);consensus(yellow);mismatches(red);prediction(salmon);stat.model(orange)",
                                "length",
                                "idx"))

      prediction_raw = remove_isolated_residues(@multiple_alignment[@multiple_alignment.length-1])
  
      gaps = gap_validation(prediction_raw, sm)
      extra_seq = extra_sequence_validation(prediction_raw, sm)
      
      @validation_report = AlignmentValidationOutput.new(gaps, extra_seq)        

      # Exception is raised when blast founds no hits
      rescue Exception => error
        puts error.backtrace
        ValidationReport.new("Not enough evidence")
    end
  end

  ##
  # Builds the multiple alignment between 
  # all the hits and the prediction
  # using MAFFT tool
  # Params:
  # +prediction+: a +Sequence+ object representing the blast query
  # +hits+: a vector of +Sequience+ objects (usually representig the blast hits)
  # Output:
  # Array of +String+s, corresponding to the multiple aligned sequences
  def multiple_align_mafft(prediction = @prediction, hits = @hits, path = "/usr/bin/mafft")
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
    no_insertions = 0
    (0..sm.length-1).each do |i|
      if prediction_raw[i] != '-' and  sm[i]=='-'
        no_insertions += 1
      end
    end
    no_insertions/(sm.length+0.0)
    
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

  def plot_multiple_alignment(output = "#{@filename}_ma.jpg", ma = @multiple_alignment, sm = nil)

    max_len = ma.map{|seq| seq.length}.max

    # get indeces of consensus in the multiple alignment
    consensus = get_consensus(@multiple_alignment[0..@multiple_alignment.length-2])
    consensus_idxs_all = consensus.split(//).each_index.select{|j| isalpha(consensus[j])}

    R.eval "jpeg('#{output}')"

    R.eval "plot(0:#{ma.length + 1}, xlim=c(0,#{max_len}), xlab='Multiple alignment of blast hits: gaps(white), consensus(yellow),\n alignment mismatches(red), prediction(green), statistical model (orange)', ylab='Hit noumber', col='white', main='Multiple Alignment and Statistical Model')"

    ma[0..ma.length-2].each_with_index do |seq,j|

      i = ma.length-j-1
      R.eval "lines(c(1,#{seq.length}), c(#{i+1}, #{i+1}), lwd=8, col = 'red')"

      # get indeces of the gaps according to the multiple alignment
      gaps = seq.split(//).each_index.select{|j| seq[j] == '-'}

      (0..(consensus_idxs_all.length-1)/300).each do |j|
        consensus_idxs = consensus_idxs_all[j*200..(j+1)*200 - 1]
        R.eval "points(c#{consensus_idxs.to_s.gsub('[','(').gsub(']',')')}, 
                rep(#{i+1},#{consensus_idxs.length}), 
                col = 'yellow', 
                type='p', 
                pch=16)"

      end

      (0..(gaps.length-1)/300).each do |j|
        gaps_idxs = gaps[j*200..(j+1)*200 - 1]

        R.eval "points(c#{gaps_idxs.to_s.gsub('[','(').gsub(']',')')}, 
                rep(#{i+1},#{gaps_idxs.length}), 
                col = 'black', 
                type='p', 
                pch=16)"
      end


    end

    #plot the prediction
    seq = ma[ma.length-1]
    #i = ma.length-1
    R.eval "lines(c(0,#{seq.length}), c(1, 1), lwd=8, col = 'green')"

    # get indeces of the gaps according to the multiple alignment
    gaps = seq.split(//).each_index.select{|j| seq[j] == '-'}

    (0..(gaps.length-1)/300).each do |j|
        gaps_idxs = gaps[j*200..(j+1)*200 - 1]
        R.eval "points(c#{gaps_idxs.to_s.gsub('[','(').gsub(']',')')}, 
                rep(1,#{gaps_idxs.length}), 
                col = 'black', 
                type='p', 
                pch=16)"
    end

    # plot the statistical model
    unless sm == nil
      seq = sm
      i = ma.length-1
      R.eval "lines(c(0,#{seq.length}), c(0, 0), lwd=8, col = 'orange')"

      # get indeces of the gaps according to the multiple alignment
      gaps = seq.split(//).each_index.select{|j| seq[j] == '-'}

      consensus_idxs_all = seq.split(//).each_index.select{|j| isalpha(seq[j])} 
      (0..(consensus_idxs_all.length-1)/300).each do |j|
        consensus_idxs = consensus_idxs_all[j*200..(j+1)*200 - 1]
        R.eval "points(c#{consensus_idxs.to_s.gsub('[','(').gsub(']',')')}, 
              rep(0,#{consensus_idxs.length}), 
              col = 'yellow', 
              type='p', 
              pch=16)"
      end

      (0..(gaps.length-1)/300).each do |j|
        gaps_idxs = gaps[j*200..(j+1)*200 - 1]
        R.eval "points(c#{gaps_idxs.to_s.gsub('[','(').gsub(']',')')}, 
                rep(0,#{gaps_idxs.length}), 
                col = 'black', 
                type='p', 
                pch=16)"
      end
    end

    R.eval "dev.off()"
    
  end
  ##
  # Returns true if the string contains only letters
  # and false otherwise
  def isalpha(str)
    !str.match(/[^A-Za-z]/)
  end

end

