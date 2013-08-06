require "rubygems"
require "shoulda"
require 'mini_shoulda'
require 'minitest/autorun'
require "yaml"
require "rinruby"
require 'genevalidator/blast'

class ValidateOutput < Test::Unit::TestCase

    # redirect the cosole messages of R
    R.echo "enable = nil, stderr = nil, warn = nil"

    filename = "test/test_validations"
    filename_fasta = "#{filename}.fasta"
    filename_xml = "#{filename}.xml"   

    b = Blast.new(filename_fasta, "mrna", filename_xml)
    output = File.open(filename_xml, "rb").read

    iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(output).to_enum

  describe "Test validations 1" do  

    sequences = b.parse_next_query(iterator) #returns [hits, predicted_seq]

    hits = sequences[0]
    prediction = sequences[1]
    short_def = prediction.definition.scan(/([^ ]+)/)[0][0]

    should "validate length by clusterization for #{short_def}" do
      lcv = LengthClusterValidation.new(hits, prediction, "", false).run
      assert_equal lcv.limits, [23,135]
      assert_equal lcv.prediction_len, 108
    end

    it "should validate length by rank #{short_def}" do
      lrv = LengthRankValidation.new(hits, prediction).run
      assert_equal lrv.percentage.round(4), 0.46
    end

    it "should validate reading frame #{short_def}" do
      rfv = BlastReadingFrameValidation.new(hits, prediction).run
      assert_equal rfv.frames_histo, {1=>501}
    end

    it "should validate gene merge #{short_def}" do
      gmv = GeneMergeValidation.new(hits, prediction, "", false).run
      assert_equal gmv.slope.round(4), -0.1112
    end

    it "should validate duplication #{short_def}" do
      dv  = DuplicationValidation.new(hits, prediction).run
      assert_equal dv.pvalue.round(4), 1
    end

  end

  describe "Test validations 2" do

    sequences = b.parse_next_query(iterator) #returns [hits, predicted_seq]
    hits = sequences[0]
    prediction = sequences[1]
    short_def = prediction.definition.scan(/([^ ]+)/)[0][0]

    it "should validate length by clusterization #{short_def}" do
      lcv = LengthClusterValidation.new(hits, prediction, "", false).run
      assert_equal lcv.limits, [665, 749]
      assert_equal lcv.prediction_len, 1327
    end

    it "should validate length by rank #{short_def}" do
      lrv = LengthRankValidation.new(hits, prediction).run
      assert_equal lrv.percentage.round(4), 0.0
    end

    it "should validate reading frame #{short_def}" do
      rfv = BlastReadingFrameValidation.new(hits, prediction).run
      assert_equal rfv.frames_histo, {1=>133, 3=>137}
    end

    it "should validate gene merge #{short_def}" do
      gmv = GeneMergeValidation.new(hits, prediction, "", false).run
      assert_equal gmv.slope.round(4), -0.0553
    end

    it "should validate duplication #{short_def}" do
      dv  = DuplicationValidation.new(hits, prediction).run
      assert_equal dv.pvalue.round(4), 0.0055
    end

  end
end
