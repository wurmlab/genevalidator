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
    @description = "Check whether there is a duplicated subsequence in the"<<
    " predicted gene by counting the hsp residue coverag of the prediction,"<<
    " for each hit. Meaning of the output displayed: P-value of the Wilcoxon"<<
    " test which test the distribution of hit average coverage against 1."<<
    " P-values higher than 5% pass the validation test."
    @cli_name = "dup"
  end

  ##
  # Check duplication in the first n hits
  # Output:
  # +DuplciationValidationOutput+ object
  def run(n=10)    
    begin
      raise Exception unless prediction.is_a? Sequence and 
                             hits[0].is_a? Sequence and 
                             hits.length >= 5

      # get the first n hits
      less_hits = @hits[0..[n-1,@hits.length].min]

      # get raw sequences for less_hits
      less_hits.map do |hit|
        #get gene by accession number
        if hit.raw_sequence == nil
          if hit.seq_type == :protein
            hit.get_sequence_by_accession_no(hit.accession_no, "protein")
          else
            hit.get_sequence_by_accession_no(hit.accession_no, "nucleotide")
          end
        end
      end

      averages = []

      less_hits.each do |hit|

        coverage = Array.new(hit.xml_length,0)
        hit.hsp_list.each do |hsp|
          # indexing in blast starts from 1
          hit_local = hit.raw_sequence[hsp.hit_from-1..hsp.hit_to-1]
          query_local = prediction.raw_sequence[hsp.match_query_from-1..hsp.match_query_to-1]

          # local alignment for hit and query
          seqs = [hit_local, query_local]

          options = ['--maxiterate', '1000', '--localpair', '--quiet']
          mafft = Bio::MAFFT.new("/usr/bin/mafft", options)
          report = mafft.query_align(seqs)
          raw_align = report.alignment
          align = []
          raw_align.each { |s| align.push(s.to_s) }
          hit_alignment = align[0]
          query_alignment = align[1]
=begin
          puts hit_alignment
          puts ""
          puts query_alignment
=end
          aux = []
          # for each hsp
          # iterate through the alignment and count the matching residues
          [*(0 .. hsp.align_len-1)].each do |i|
            residue_hit = hit_alignment[i]
            residue_query = query_alignment[i]
            if residue_hit != ' ' and residue_hit != '+' and residue_hit != '-'
              if residue_hit == residue_query             
                # indexing in blast starts from 1
                idx = i + (hsp.hit_from-1) - hit_alignment[0..i].scan(/-/).length 
                if coverage.length > idx
                  coverage[idx] += 1
                end
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
        puts error.backtrace
        ValidationReport.new("Not enough evidence")
    end
  end
end
