require 'minitest'
require 'minitest/autorun'
require 'yaml'
require 'fileutils'
require 'validation'
require 'genevalidator/blast'
require 'genevalidator/validation_length_cluster'
require 'genevalidator/validation_length_rank'
require 'genevalidator/validation_blast_reading_frame'
require 'genevalidator/validation_gene_merge'
require 'genevalidator/validation_duplication'
require 'genevalidator/validation_open_reading_frame'
require 'genevalidator/validation_alignment'

class ValidateOutput < Minitest::Test


    filename = "test/test_files/test_validations"
    filename_fasta = "#{filename}.fasta"
    filename_xml = "#{filename}.xml"

    begin
      FileUtils.rm_rf("#{filename_fasta}.html")
    rescue Error
    end

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

    validations = b.do_validations(prediction, hits,1).validations

  describe "Test validations 1" do
    it "should check the number of hits" do
      assert_equal(499, hits.length)
    end


    it "should validate length by clusterization" do
       lcv = validations.select{|v| v.class == LengthClusterValidationOutput}[0]
       assert_equal([23,135], lcv.limits)
       assert_equal(108, lcv.query_length)
    end

    it "should validate length by rank" do
      lrv = validations.select{|v| v.class == LengthRankValidationOutput}[0]
      assert_equal(46.0, lrv.percentage.round(4))
    end

    it "should validate reading frame" do
      rfv = validations.select{|v| v.class == BlastRFValidationOutput}[0]
      assert_equal({1=>500}, rfv.frames_histo)
    end

    it "should validate gene merge" do
      gmv = validations.select{|v| v.class == GeneMergeValidationOutput}[0]
      assert_equal(0.0, gmv.slope.round(4))
    end

    it "should validate duplication" do
      dv  = validations.select{|v| v.class == DuplicationValidationOutput}[0]
      assert_equal(1, dv.pvalue.round(4))
    end
  end

  FileUtils.rm_rf("#{filename_fasta}.html")
end
