require 'genevalidator/validation_output'

##
# Class that stores the validation output information
class DuplciationValidationOutput < ValidationReport

  attr_reader :pvalue
  attr_reader :threshold

  def initialize (pvalue, threshold = 0.05, expected = :no)
    @pvalue = pvalue
    @threshold = threshold
    @result = validation
    @expected = expected
  end

  def print
    "pval=#{@pvalue.round(2)}"
  end

  def validation
    if @pvalue < @threshold
      :yes
    else
      :no
    end
  end

  def color
    if validation == :no
      "success"
    else
      "danger"
    end
  end
end

##
# This class contains the methods necessary for
# finding duplicated subsequences in the predicted gene
class DuplicationValidation < ValidationTest

  def initialize(type, prediction, hits = nil)
    super
    @short_header = "Duplication"
    @header = "Duplication"
    @description = "Check whether there is a duplicated subsequence in the predicted gene by counting the hsp residue coverag of the prediction, for each hit. Meaning of the output displayed: P-value of the Wilcoxon test which test the distribution of hit average coverage against 1. P-values higher than 5% pass the validation test."
    @cli_name = "dup"
  end

  ##
  # Check duplication in the first n hits
  # Output:
  # +DuplciationValidationOutput+ object
  def run(n=10)    
    begin
      raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence and hits.length >= 5

      # get the first n hits
      less_hits = @hits[0..[n-1,@hits.length].min]
      averages = []

      less_hits.each do |hit|
        # indexing in blast starts from 1
#unused !!!!!!!!!!
        start_match_interval =  hit.hsp_list.each.map{|x| x.hit_from}.min - 1
        end_match_interval = hit.hsp_list.map{|x| x.hit_to}.max - 1
   
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
        @validation_report = DuplciationValidationOutput.new(1)
        return @validation_report
      end

      R.eval("library(preprocessCore)")

      #make the wilcox-test and get the p-value
      R.eval("coverageDistrib = c#{averages.to_s.gsub('[','(').gsub(']',')')}")
      R. eval("pval = wilcox.test(coverageDistrib - 1)$p.value")

      pval = R.pull "pval"

      @validation_report = DuplciationValidationOutput.new(pval)        

      # Exception is raised when blast founds no hits
      rescue Exception => error
#        puts error.backtrace
        ValidationReport.new("Not enough evidence")
    end
  end
end
