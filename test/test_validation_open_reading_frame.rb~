require "rubygems"
require "test/unit"
require "shoulda"
require './validation_open_reading_frame'
require './sequences'

class TestORFValidation < Test::Unit::TestCase

  context "ORF Validation" do

    prediction = Sequence.new
    prediction.raw_sequence = 
       "ATGGCTCTCTGGATCCGGTCGCTGCCTCTCCTGGCCCTTCTTGCTCTTTCTGGCCCTGGGATCAGCCACG\
CAGCTGCCAACCAGCACCTCTGTGGCTCCCACTTGGTTGAGGCTCTCTACCTGGTGTGTGGGGAGCGGGG\
TTTCTTCTACTCCCCCAAAACACGGCGGGACGTTGAGCAGCCTCTAGTGAACGGTCCCCTGCATGGCGAG\
GTGGGAGAGCTGCCGTTCCAGCATGAGGAATACCAGAAAGTCAAGCGAGGCATCGTTGAGCAATGCTGTG\
AAAACCCGTGCTCCCTCTACCAACTGGAAAACTACTGCAACTAG"      
   
    should "find ORFs between two STOP codons " do
      validation = OpenReadingFrameValidation.new(prediction, "", false, ["ATG"], ["TAG", "TAA", "TGA"])
      result = {"+1"=>[[0, 324]], "+2"=>[[202, 324]], "+3"=>[], "-1"=>[], "-2"=>[[146, 263]], "-3"=>[]}
      assert_equal result, validation.get_orfs
    end

    should "find ORFs between a START and a STOP codon" do
      validation = OpenReadingFrameValidation.new(prediction, "", false, [], ["TAG", "TAA", "TGA"])
      result = {"+1"=>[[1, 324]], "+2"=>[[2, 187], [190, 324]], "+3"=>[[3, 110]], "-1"=>[[183, 323], [0, 183]], "-2"=>[[146, 296], [0, 116]], "-3"=>[[61, 250]]}
      assert_equal result , validation.get_orfs
    end

  end
end
