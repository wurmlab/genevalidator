require 'genevalidator/validation_output'

##
# Class that stores the validation output information
class AlignmentValidationOutput < ValidationReport

  attr_reader :msg

  def initialize (msg)
    @msg = msg
  end

  def print
    msg
  end

  def validation
    :yes
  end

  def color
    "success"
  end
end

##
# This class contains the methods necessary for
# validations based on multiple alignment
class AlignmentValidation < ValidationTest

  attr_reader :filename
  attr_reader :plot
  attr_reader :multiple_alignment

  def initialize(type, prediction, hits, filename, plot = true)
    super
    @filename = filename
    @plot = plot
    @short_header = "MA Test"
    @header = "Multiple Alignment Test"
    @description = "Finds gaps/extra regions based on the multiple alignment of the best hits."
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
      ma = MultipleAlignment.new(prediction, less_hits)

      if plot
        plot_multiple_alignment("#{@filename}_ma.jpg")
        @plot_files.push("#{@filename}_ma.jpg")
      end

#      @multiple_alignment.each do |ma|
#        puts ma.to_s
#      end

      @validation_report = AlignmentValidationOutput.new("In progress...")        

      # Exception is raised when blast founds no hits
      rescue Exception => error
        puts error.backtrace
#        ValidationReport.new("Not enough evidence")
    end
  end

  def plot_multiple_alignment(output = "#{@filename}_ma.jpg", ma = @multiple_alignment)

    max_len = ma.map{|seq| seq.length}.max

    # get indeces of consensus in the multiple alignment
    align = Bio::Alignment.new(@multiple_alignment)
    consensus = consensus()align.consensus
    consensus_idxs_all = consensus.split(//).each_index.select{|j| isalpha(consensus[j])}

    R.eval "jpeg('#{output}')"

    R.eval "plot(0:#{ma.length}, xlim=c(0,#{max_len}), xlab='Multiple alignment of blast hits:\n gaps(white), consensus(yellow), alignment mismatches(red), prediction(green)',ylab='Hit noumber', col='white')"

    ma[0..ma.length-2].each_with_index do |seq,i|
      R.eval "lines(c(1,#{seq.length}), c(#{i+1}, #{i+1}), lwd=8, col = 'red')"

      # get indeces of the gaps according to the multiple alignment
      gaps = seq.split(//).each_index.select{|j| seq[j] == '-'}

      (0..(gaps.length-1)/300).each do |j|
        gaps_idxs = gaps[j*200..(j+1)*200 - 1]

        R.eval "points(c#{gaps_idxs.to_s.gsub('[','(').gsub(']',')')}, 
                rep(#{i+1},#{gaps_idxs.length}), 
                col = 'white', 
                type='p', 
                pch=16)"
      end

      (0..(consensus_idxs_all.length-1)/300).each do |j|
        consensus_idxs = consensus_idxs_all[j*200..(j+1)*200 - 1]
        R.eval "points(c#{consensus_idxs.to_s.gsub('[','(').gsub(']',')')}, 
                rep(#{i+1},#{consensus_idxs.length}), 
                col = 'yellow', 
                type='p', 
                pch=16)"

      end
    end

    #plot prediction
    seq = ma[ma.length-1]
    i = ma.length-1
    R.eval "lines(c(1,#{seq.length}), c(0, 0), lwd=10, col = 'green')"

    # get indeces of the gaps according to the multiple alignment
    gaps = seq.split(//).each_index.select{|j| seq[j] == '-'}

    (0..(gaps.length-1)/300).each do |j|
        gaps_idxs = gaps[j*200..(j+1)*200 - 1]
        R.eval "points(c#{gaps_idxs.to_s.gsub('[','(').gsub(']',')')}, 
                rep(0,#{gaps_idxs.length}), 
                col = 'white', 
                type='p', 
                pch=16)"
    end

    (0..(consensus_idxs_all.length-1)/300).each do |j|
        consensus_idxs = consensus_idxs_all[j*200..(j+1)*200 - 1]    
      R.eval "points(c#{consensus_idxs.to_s.gsub('[','(').gsub(']',')')}, 
              rep(0,#{consensus_idxs.length}), 
              col = 'yellow', 
              type='p', 
              pch=16)"
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

class MultipleAlignment

  attr_reader :hits
  attr_reader :prediction
  attr_reader :ma

  ##
  # Initilizes the object
  # Params:
  # +prediction+: a +Sequence+ object representing the blast query
  # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
  def initialize (prediction, hits)
    raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence
    @prediction = prediction
    @hits = hits
  end

  ##
  # Builds the multiple alignment between 
  # all the hits and the prediction
  # using MAFFT tool
  # Params:
  # +prediction+: a +Sequence+ object representing the blast query
  # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)  
  # Output:
  # Array of +String+s, corresponding to the multiple aligned sequences
  def multiple_align_mafft(prediction = @prediction, hits = @hits, path = "/usr/bin/mafft")
    raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence

      less_hits.add(prediction)

      options = ['--maxiterate', '1000', '--localpair', '--quiet']
      mafft = Bio::MAFFT.new(path, options)
      report = mafft.query_align(less_hits.map{|hit| hit.raw_sequence})

      # Accesses the actual alignment.
      align = report.alignment

      # Prints each sequence to the console.
      align.each do |s|
         @ma.push(s.to_s)
      end
  end

  ##
  # Returns the consensus regions among 
  # a set of multiple aligned sequences
  # Params:
  # +ma+: array of +String+s, corresponding to the multiple aligned sequences
  # Output:
  # +String+ with the consensus regions
  def get_consensus(ma = @ma)
    align = Bio::Alignment.new(@multiple_alignment)
    consensus = align.consensus
  end

end
