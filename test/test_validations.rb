require "rubygems"
require "shoulda"
require 'mini_shoulda'
require 'minitest/autorun'
require "yaml"
require 'genevalidator/blast'
require 'genevalidator/validation'
require 'genevalidator/validation_length_cluster'
require 'genevalidator/validation_length_rank'
require 'genevalidator/validation_blast_reading_frame'
require 'genevalidator/validation_gene_merge'
require 'genevalidator/validation_duplication'
require 'genevalidator/validation_open_reading_frame'
require 'genevalidator/validation_alignment'

class ValidateOutput < MiniTest::Unit::TestCase


    filename = "test/test_files/test_validations"
    filename_fasta = "#{filename}.fasta"
    filename_xml = "#{filename}.xml"   
    b = Validation.new(filename_fasta, ["all"], nil, filename_xml)
    output = File.open(filename_xml, "rb").read
    iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(output).to_enum
    hits = BlastUtils.parse_next_query_xml(iterator, :nucleotide)
    
    prediction = Sequence.new

    prediction.definition = ""
    prediction.identifier = ""
    prediction.type = :nucleotide
    prediction.raw_sequence = "aaa"

    prediction.length_protein = 108

    validations = b.do_validations(prediction, hits).validations

  describe "Test validations 1" do  
    it "should check the number of hits" do
      assert_equal hits.length, 499
    end


    it "should validate length by clusterization" do
       lcv = validations.select{|v| v.class == LengthClusterValidationOutput}[0]
       assert_equal lcv.limits, [23,135]
       assert_equal lcv.prediction_len, 108
    end

    it "should validate length by rank" do
      lrv = validations.select{|v| v.class == LengthRankValidationOutput}[0]
      assert_equal lrv.percentage.round(4), 0.46
    end

    it "should validate reading frame" do
      rfv = validations.select{|v| v.class == BlastRFValidationOutput}[0]
      assert_equal rfv.frames_histo, {1=>500}
    end

    it "should validate gene merge" do
      gmv = validations.select{|v| v.class == GeneMergeValidationOutput}[0]
      assert_equal gmv.slope.round(4), -0.1089
    end

    it "should validate duplication" do
      dv  = validations.select{|v| v.class == DuplicationValidationOutput}[0]
      assert_equal dv.pvalue.round(4), 1
    end
  end

end
