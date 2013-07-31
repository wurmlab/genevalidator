require 'genevalidator/validation_output'

class LengthRankValidationOutput < ValidationOutput

  attr_reader :prercentage
  attr_reader :msg

  def initialize (percentage, msg)       
    @percentage = percentage
    @msg = msg
  end

  def print
    "#{@percentage} (#{msg})"
  end

  def validation
    if msg == "YES"
      :yes
    else
      :no
    end
  end

end


##
# This class contains the methods necessary for 
# length validation by ranking the hit lengths
class LengthRankValidation

  attr_reader :hits
  attr_reader :prediction
  attr_reader :threshold

  ##
  # Initilizes the object
  # Params:
  # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
  # +prediction+: a +Sequence+ object representing the blast query
  # +filename+: name of the input file, used when generatig the plot files
  # query_index: the number of the query in the blast output
  def initialize(hits, prediction, threshold = 0.2)
    begin
      raise QueryError unless hits[0].is_a? Sequence and prediction.is_a? Sequence 
      @hits = hits
      @prediction = prediction
      @threshold = threshold
    end
  end

  ##
  # Calculates a precentage based on the rank of the predicion among the hit lengths
  # Params:
  # +threshold+: limit above which we consider the validation passed
  # +hits+ (optional): a vector of +Sequence+ objects
  # +prediction+ (optional): a +Sequence+ object
  def validation_test(hits = @hits, prediction = @prediction)
    begin
      raise TypeError unless hits[0].is_a? Sequence and prediction.is_a? Sequence

      lengths = hits.map{ |x| x.xml_length.to_i }.sort{|a,b| a<=>b}
      len = lengths.length
      median = len % 2 == 1 ? lengths[len/2] : (lengths[len/2 - 1] + lengths[len/2]).to_f / 2

      predicted_len = prediction.xml_length

      if predicted_len < median
        rank = lengths.find_all{|x| x < predicted_len}.length
        percentage = rank / (len + 0.0)
        msg = "TOO_SHORT"
      else
        rank = lengths.find_all{|x| x > predicted_len}.length
        percentage = rank / (len + 0.0)
        msg = "TOO_LONG"
      end

      if percentage >= threshold
        msg = "YES"
      end

      answ = LengthRankValidationOutput.new(percentage.round(2), msg)

    rescue TypeError => error
      $stderr.print "Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: one of the arguments of 'length_rank' method has not the proper type.\n"
      exit
    end
  end

end
