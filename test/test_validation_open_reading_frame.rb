require "rubygems"
require 'shoulda'
require 'mini_shoulda'
require 'minitest/autorun'
require 'rinruby'
require 'genevalidator/validation_test'
require 'genevalidator/validation_open_reading_frame'
require 'genevalidator/sequences'

class TestORFValidation < MiniTest::Unit::TestCase

  describe "ORF Validation" do

    # redirect the cosole messages of R
    R.echo "enable = nil, stderr = nil, warn = nil"

    prediction = Sequence.new
    prediction.raw_sequence = 
       "ATGGCTCTCTGGATCCGGTCGCTGCCTCTCCTGGCCCTTCTTGCTCTTTCTGGCCCTGGGATCAGCCACG\
CAGCTGCCAACCAGCACCTCTGTGGCTCCCACTTGGTTGAGGCTCTCTACCTGGTGTGTGGGGAGCGGGG\
TTTCTTCTACTCCCCCAAAACACGGCGGGACGTTGAGCAGCCTCTAGTGAACGGTCCCCTGCATGGCGAG\
GTGGGAGAGCTGCCGTTCCAGCATGAGGAATACCAGAAAGTCAAGCGAGGCATCGTTGAGCAATGCTGTG\
AAAACCCGTGCTCCCTCTACCAACTGGAAAACTACTGCAACTAG"      
   
    it "should find ORFs between two STOP codons " do
      validation = OpenReadingFrameValidation.new(:nucleotide, prediction, nil, "", ["ATG"], ["TAG", "TAA", "TGA"])
      result = {1=>[[0, 324]], 2=>[[202, 324]], 3=>[], -1=>[], -2=>[[146, 263]], -3=>[]}
      assert_equal result, validation.get_orfs
    end

    it "should find ORFs between a START and a STOP codon" do
      validation = OpenReadingFrameValidation.new(:nucleotide, prediction, nil, "", [], ["TAG", "TAA", "TGA"])
      result = {+1=>[[1, 324]], +2=>[[2, 187], [190, 324]], +3=>[[3, 110]], -1=>[[183, 323], [0, 183]], -2=>[[146, 296], [0, 116]], -3=>[[61, 250]]}
      assert_equal result , validation.get_orfs
    end
=begin
    it "should create plot file" do
      filename = "output"
      validation = OpenReadingFrameValidation.new(:nucleotide, prediction, [prediction], filename)
      validation.run
      assert_equal true, File.exist?("#{filename}_orfs.json")
      File.delete("#{filename}_orfs.jpg")
    end
=end
  end
end
