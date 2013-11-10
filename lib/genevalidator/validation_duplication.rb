require 'genevalidator/validation_report'
require 'genevalidator/exceptions'

##
# Class that stores the validation output information
class DuplicationValidationOutput < ValidationReport

  attr_reader :pvalue
  attr_reader :threshold

  def initialize (pvalue, threshold = 0.05, expected = :no)

    @short_header    = "Duplication"
    @header          = "Duplication"
    @description = "Check whether there is a duplicated subsequence in the"<<
    " predicted gene by counting the hsp residue coverag of the prediction,"<<
    " for each hit. Meaning of the output displayed: P-value of the Wilcoxon"<<
    " test which test the distribution of hit average coverage against 1."<<
    " P-values higher than 5% pass the validation test."

    @pvalue    = pvalue
    @threshold = threshold
    @result    = validation
    @expected  = expected
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

  attr_reader :mafft_path
  attr_reader :raw_seq_file
  attr_reader :index_file_name
  attr_reader :raw_seq_file_load
 
  def initialize(type, prediction, hits, mafft_path, raw_seq_file, index_file_name, raw_seq_file_load)
    super
    @mafft_path      = mafft_path
    @raw_seq_file    = raw_seq_file
    @index_file_name = index_file_name
    @raw_seq_file_load = raw_seq_file_load

    @short_header    = "Duplication"
    @header          = "Duplication"
    @description = "Check whether there is a duplicated subsequence in the"<<
    " predicted gene by counting the hsp residue coverag of the prediction,"<<
    " for each hit. Meaning of the output displayed: P-value of the Wilcoxon"<<
    " test which test the distribution of hit average coverage against 1."<<
    " P-values higher than 5% pass the validation test."
    @cli_name        = "dup"

  end

  ##
  # Check duplication in the first n hits
  # Output:
  # +DuplicationValidationOutput+ object
  def run(n=10)    
    begin
      raise NotEnoughHitsError unless hits.length >= 5
      raise Exception unless prediction.is_a? Sequence and
                             prediction.raw_sequence != nil and 
                             hits[0].is_a? Sequence 

      start = Time.new
      # get the first n hits
      less_hits = @hits[0..[n-1,@hits.length].min]
      useless_hits = []

      # get raw sequences for less_hits
      less_hits.map do |hit|
        #get gene by accession number
        if hit.raw_sequence == nil

          hit.get_sequence_from_index_file(@raw_seq_file, @index_file_name, hit.identifier, @raw_seq_file_load)
  
          if hit.raw_sequence == nil or hit.raw_sequence.empty?
            if hit.type == :protein
              hit.get_sequence_by_accession_no(hit.accession_no, "protein")
            else
              hit.get_sequence_by_accession_no(hit.accession_no, "nucleotide")
            end
          end

          if hit.raw_sequence == nil
            useless_hits.push(hit)
          else
            if hit.raw_sequence.empty?
              useless_hits.push(hit)
            end
          end

        end
      end

      useless_hits.each{|hit| less_hits.delete(hit)}

      if less_hits.length == 0 
        raise NoInternetError
      end

      averages = []

      less_hits.each do |hit|
        coverage = Array.new(hit.length_protein,0)
        hit.hsp_list.each do |hsp|
        # align subsequences from the hit and prediction that match (if it's the case)
          if hsp.hit_alignment != nil and hsp.query_alignment != nil
            hit_alignment   = hsp.hit_alignment
            query_alignment = hsp.query_alignment
          else
            # indexing in blast starts from 1
            hit_local = hit.raw_sequence[hsp.hit_from-1..hsp.hit_to-1]
            query_local = prediction.raw_sequence[hsp.match_query_from-1..hsp.match_query_to-1]

            # in case of nucleotide prediction sequence translate into protein
            # use translate with reading frame 1 because 
            # to/from coordinates of the hsp already correspond to the 
            # reading frame in which the prediction was read to match this hsp 
            if @type == :nucleotide
              s = Bio::Sequence::NA.new(query_local)
              query_local = s.translate
            end

            # local alignment for hit and query
            seqs = [hit_local, query_local]

            begin
              options   = ['--maxiterate', '1000', '--localpair', '--quiet']
              mafft     = Bio::MAFFT.new(@mafft_path, options)
              report    = mafft.query_align(seqs)
              raw_align = report.alignment
              align     = []

              raw_align.each { |s| align.push(s.to_s) }
              hit_alignment   = align[0]
              query_alignment = align[1]
            rescue Exception => error                
              raise NoMafftInstallationError
            end
          end 

          
          # check multiple coverage

          # for each hsp of the curent hit
          # iterate through the alignment and count the matching residues
          [*(0 .. hit_alignment.length-1)].each do |i|
            residue_hit = hit_alignment[i]
            residue_query = query_alignment[i]
            if residue_hit != ' ' and residue_hit != '+' and residue_hit != '-'
              if residue_hit == residue_query             
                # indexing in blast starts from 1
                idx = i + (hsp.hit_from-1) - hit_alignment[0..i].scan(/-/).length 
                  coverage[idx] += 1
                #end
              end
            end
          end
        end
        overlap = coverage.reject{|x| x==0}
        if overlap != []
          averages.push(overlap.inject(:+)/(overlap.length + 0.0)).map{|x| x.round(2)}
        end
      end

      # if all hsps match only one time
      if averages.reject{|x| x==1} == []
        @validation_report = DuplicationValidationOutput.new(1)
        @validation_report.running_time = Time.now - start
        return @validation_report
      end
      
      pval = wilcox_test(averages)

      @validation_report = DuplicationValidationOutput.new(pval)        
      @running_time = Time.now - start
      return @validation_report

    rescue  NotEnoughHitsError => error
      @validation_report = ValidationReport.new("Not enough evidence", :warning, @short_header, @header, @description)
      return @validation_report
    rescue NoMafftInstallationError
      @validation_report = ValidationReport.new("Mafft error", :error, @short_header, @header, @description)
      @validation_report.errors.push NoMafftInstallationError                          
      return @validation_report
    rescue NoInternetError 
      @validation_report = ValidationReport.new("Internet error", :error, @short_header, @header, @description)
      @validation_report.errors.push NoInternetError
      return @validation_report
    rescue Exception => error
      #puts error.backtrace
      @validation_report.errors.push OtherError
      @validation_report = ValidationReport.new("Unexpected error", :error, @short_header, @header, @description)
      return @validation_report
    end
  end

  ##
  # wilcox test implementation from statsample ruby gem
  # many thanks to Claudio for helping us with the implementation!
  def wilcox_test (averages)
     require 'statsample'
     wilcox = Statsample::Test.wilcoxon_signed_rank(averages.to_scale, Array.new(averages.length,1).to_scale)
     if averages.length < 15
       return wilcox.probability_exact
     else
       return wilcox.probability_z
     end
  end


  ##
  # Calls R to calculate the p value for the wilcoxon-test
  # Input
  # +vector+ Array of values with nonparametric distribution
  def wilcox_test_R (averages)
    require 'rinruby'
    begin
      original_stdout = $stdout
      original_stderr = $stderr

      $stdout = File.new('/dev/null', 'w')
      $stderr = File.new('/dev/null', 'w')

      R.echo "enable = nil, stderr = nil, warn = nil"
      #make the wilcox-test and get the p-value
      R.eval("coverageDistrib = c#{averages.to_s.gsub('[','(').gsub(']',')')}")
      R.eval("coverageDistrib = c#{averages.to_s.gsub('[','(').gsub(']',')')}")
      R. eval("pval = wilcox.test(coverageDistrib - 1)$p.value")

      pval = R.pull "pval"
      $stdout = original_stdout
      $stderr = original_stderr

      return pval
    rescue Exception => error
      #return nil
    end
  end
end
