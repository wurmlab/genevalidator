require "rubygems"
require 'shoulda'
require 'minitest'
require 'minitest/autorun'
#require 'mini_shoulda'

require 'genevalidator/validation_test'
require 'genevalidator/validation_open_reading_frame'
require 'genevalidator/sequences'

class TestORFValidation < MiniTest::Unit::TestCase

  describe "ORF Validation" do

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

  end
end
