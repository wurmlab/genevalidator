require 'genevalidator/validation_output'

class DuplciationValidationOutput < ValidationOutput

  attr_reader :pvalue
  attr_reader :threshold

  def initialize (pvalue, threshold = 0.05)
    @pvalue = pvalue
    @threshold = threshold
    
  end

  def print
    "#{validation.to_s} (pval=#{@pvalue.round(2)})"
  end

  def validation

    if pvalue < @threshold
      :yes
    else
      :no
    end
  end

  def color
    if validation == :no
      "white"
    else
      "red"
    end
  end


end

class DuplicationValidation

  attr_reader :hits
  attr_reader :prediction

  ##
  #
  def initialize(hits, prediction)
    begin
      raise QueryError unless hits[0].is_a? Sequence and prediction.is_a? Sequence
      @hits = hits
      @prediction = prediction
    end
  end

  ##
  # Check duplication in the first n hits
  # Returns yes/no answer
  def validation_test(n=10)

    # get the first n hits
    less_hits = @hits[0..[n-1,@hits.length].min]
    averages = []

    less_hits.each do |hit|
      # indexing in blast starts from 1
      start_match_interval =  hit.hsp_list.each.map{|x| x.hit_from}.min - 1
      end_match_interval = hit.hsp_list.map{|x| x.hit_to}.max - 1
   
      #puts "#{hit.xml_length} #{start_match_interval} #{end_match_interval}" 

      coverage = Array.new(hit.xml_length,0)
      hit.hsp_list.each do |hsp|
        aux = []
        # for each hsp
        # iterate through the alignment and count the matching residues
        [*(0 .. hsp.align_len-1)].each do |i|
          residue_hit = hsp.hit_alignment[i]
          residue_query = hsp.query_alignment[i]
          if residue_hit != ' ' and residue_hit != '+' and residue_hit != '-'
            if residue_hit == residue_query             
              idx = i + (hsp.hit_from-1) - hsp.hit_alignment[0..i].scan(/-/).length 
              aux.push(idx)
              #puts "#{idx} #{i} #{hsp.hit_alignment[0..i].scan(/-/).length}"
              # indexing in blast starts from 1
              coverage[idx] += 1
            end
          end
        end
      end
      overlap = coverage.reject{|x| x==0}
      averages.push(overlap.inject(:+)/(overlap.length + 0.0)).map{|x| x.round(2)}
    end

    # if all hsps match only one time
    if averages.reject{|x| x==1} == []
      return DuplciationValidationOutput.new(1)
    end

    R.eval("library(preprocessCore)")

    #make the wilcox-test and get the p-value
    R.eval("coverageDistrib = c#{averages.to_s.gsub('[','(').gsub(']',')')}")
    R. eval("pval = wilcox.test(coverageDistrib - 1)$p.value")

    pval = R.pull "pval"

    DuplciationValidationOutput.new(pval)        

  end
end
