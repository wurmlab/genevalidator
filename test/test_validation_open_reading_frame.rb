require_relative 'test_helper'
require 'minitest/autorun'

require 'genevalidator/validation_test'
require 'genevalidator/validation_open_reading_frame'
require 'genevalidator/sequences'
require 'genevalidator'

module GeneValidator
  # Classs to test the ORF validation
  class TestORFValidation < Minitest::Test
    describe 'ORF Validation' do
      it 'should find ORFs - test 1 ' do
        GeneValidator.config = {}
        GeneValidator.config[:type] = :nucleotide
        prediction = Sequence.new
        prediction.raw_sequence = 'ATGGCTCTCTGGATCCGGTCGCTGCCTCTCCTGGCCCTTCTT' \
                                  'GCTCTTTCTGGCCCTGGGATCAGCCACGCAGCTGCCAACCAG' \
                                  'CACCTCTGTGGCTCCCACTTGGTTGAGGCTCTCTACCTGGTG' \
                                  'TGTGGGGAGCGGGGTTTCTTCTACTCCCCCAAAACACGGCGG' \
                                  'GACGTTGAGCAGCCTCTAGTGAACGGTCCCCTGCATGGCGAG' \
                                  'GTGGGAGAGCTGCCGTTCCAGCATGAGGAATACCAGAAAGTC' \
                                  'AAGCGAGGCATCGTTGAGCAATGCTGTGAAAACCCGTGCTCC' \
                                  'CTCTACCAACTGGAAAACTACTGCAACTAG'

        validation = OpenReadingFrameValidation.new(prediction, nil)
        result = { 1 => { frame: 1, orf_start: 1, orf_end: 105, coverage: 100,
                          translated_length: 106 },
                   2 => { frame: 2, orf_start: 1, orf_end: 59, coverage: 58,
                          translated_length: 105 },
                   3 => { frame: 2, orf_start: 64, orf_end: 105, coverage: 42,
                          translated_length: 105 },
                   4 => { frame: 3, orf_start: 1, orf_end: 33, coverage: 33,
                          translated_length: 105 },
                   5 => { frame: -1, orf_start: 1, orf_end: 44, coverage: 43,
                          translated_length: 106 },
                   6 => { frame: -1, orf_start: 48, orf_end: 106, coverage: 57,
                          translated_length: 106 },
                   7 => { frame: -2, orf_start: 10, orf_end: 56, coverage: 46,
                          translated_length: 105 },
                   8 => { frame: -2, orf_start: 70, orf_end: 105, coverage: 36,
                          translated_length: 105 },
                   9 => { frame: -3, orf_start: 25, orf_end: 84, coverage: 58,
                          translated_length: 105 } }
        assert_equal(result, validation.get_orfs)

        validation = OpenReadingFrameValidation.new(prediction, nil)
        result = { 1 => { frame: 1, orf_start: 1, orf_end: 105, coverage: 100,
                          translated_length: 106 },
                   2 => { frame: 2, orf_start: 1, orf_end: 59, coverage: 58,
                          translated_length: 105 },
                   3 => { frame: 2, orf_start: 64, orf_end: 105, coverage: 42,
                          translated_length: 105 },
                   4 => { frame: 3, orf_start: 1, orf_end: 33, coverage: 33,
                          translated_length: 105 },
                   5 => { frame: -1, orf_start: 1, orf_end: 44, coverage: 43,
                          translated_length: 106 },
                   6 => { frame: -1, orf_start: 48, orf_end: 106, coverage: 57,
                          translated_length: 106 },
                   7 => { frame: -2, orf_start: 10, orf_end: 56, coverage: 46,
                          translated_length: 105 },
                   8 => { frame: -2, orf_start: 70, orf_end: 105, coverage: 36,
                          translated_length: 105 },
                   9 => { frame: -3, orf_start: 25, orf_end: 84, coverage: 58,
                          translated_length: 105 } }
        assert_equal(result, validation.get_orfs)
      end

      it 'should find - test 2 ' do
        GeneValidator.config = {}
        GeneValidator.config[:type] = :nucleotide
        prediction = Sequence.new
        prediction.raw_sequence = 'ATGGCTCTCTGGATCCGGTCGCTGCCTCTCCTGGCCCTTCTT' \
                                  'GCTCTTTCTGGCCCTGGGATCAGCCACGCAGCTGCCAACCAG' \
                                  'CACCTCTGTGGCTCCCACTTGGTTGAGGCTCTCTACCTGGTG' \
                                  'TGTGGGGAGCGGGGTTTCTTCTACTCCCCCAAAACACGGCGG' \
                                  'GACGTTGAGCAGCCTCTAGTGAACGGTCCCCTGCATGGCGAG' \
                                  'GTGGGAGAGCTGCCGTTCCAGCATGAGGAATACCAGACAGCA' \
                                  'CCTCTGTGGCTCCCACTTGGTTGAGGCTCTCTACCTGGTGTG' \
                                  'TGGGGAGCGGGGTTTCTTCTACTCCCCCAAAACACGGCGGGA' \
                                  'CGTTGAGCAGCCTCTAGTGAACGGTCCCCTGCATGGCGAGGT' \
                                  'GGGAGAGCTGCCGTTCCAGCATGAGGAATACCAGAAAGTCAA' \
                                  'GCGAGGCATCGTTGAGCAATGCTGTGAAAACCCGTGCTCCCT' \
                                  'CTACCAACTGGAAAACTACTGCAACTAG'

        validation = OpenReadingFrameValidation.new(prediction, nil)
        result = { 1 => { frame: 1, orf_start: 1, orf_end: 88, coverage: 56,
                          translated_length: 160 },
                   2 => { frame: 2, orf_start: 1, orf_end: 58, coverage: 38,
                          translated_length: 160 },
                   3 => { frame: 2, orf_start: 64, orf_end: 159, coverage: 61,
                          translated_length: 160 },
                   4 => { frame: 3, orf_start: 1, orf_end: 32, coverage: 22,
                          translated_length: 159 },
                   5 => { frame: 3, orf_start: 79, orf_end: 113, coverage: 24,
                          translated_length: 159 },
                   6 => { frame: 3, orf_start: 119, orf_end: 159, coverage: 28,
                          translated_length: 159 },
                   7 => { frame: -1, orf_start: 1, orf_end: 43, coverage: 29,
                          translated_length: 160 },
                   8 => { frame: -1, orf_start: 48, orf_end: 139, coverage: 59,
                          translated_length: 160 },
                   9 => { frame: -2, orf_start: 10, orf_end: 55, coverage: 31,
                          translated_length: 160 },
                   10 => { frame: -2, orf_start: 70, orf_end: 98, coverage: 20,
                           translated_length: 160 },
                   11 => { frame: -2, orf_start: 103, orf_end: 160,
                           coverage: 38, translated_length: 160 },
                   12 => { frame: -3, orf_start: 25, orf_end: 110, coverage: 55,
                           translated_length: 159 },
                   13 => { frame: -3, orf_start: 125, orf_end: 159,
                           coverage: 24, translated_length: 159 } }
        assert_equal(result, validation.get_orfs)

        validation = OpenReadingFrameValidation.new(prediction, nil)
        result = { 1 => { frame: 1, orf_start: 1, orf_end: 88, coverage: 56,
                          translated_length: 160 },
                   2 => { frame: 2, orf_start: 1, orf_end: 58, coverage: 38,
                          translated_length: 160 },
                   3 => { frame: 2, orf_start: 64, orf_end: 159, coverage: 61,
                          translated_length: 160 },
                   4 => { frame: 3, orf_start: 1, orf_end: 32, coverage: 22,
                          translated_length: 159 },
                   5 => { frame: 3, orf_start: 79, orf_end: 113, coverage: 24,
                          translated_length: 159 },
                   6 => { frame: 3, orf_start: 119, orf_end: 159, coverage: 28,
                          translated_length: 159 },
                   7 => { frame: -1, orf_start: 1, orf_end: 43, coverage: 29,
                          translated_length: 160 },
                   8 => { frame: -1, orf_start: 48, orf_end: 139, coverage: 59,
                          translated_length: 160 },
                   9 => { frame: -2, orf_start: 10, orf_end: 55, coverage: 31,
                          translated_length: 160 },
                   10 => { frame: -2, orf_start: 70, orf_end: 98, coverage: 20,
                           translated_length: 160 },
                   11 => { frame: -2, orf_start: 103, orf_end: 160,
                           coverage: 38, translated_length: 160 },
                   12 => { frame: -3, orf_start: 25, orf_end: 110, coverage: 55,
                           translated_length: 159 },
                   13 => { frame: -3, orf_start: 125, orf_end: 159,
                           coverage: 24, translated_length: 159 } }
        assert_equal(result, validation.get_orfs)
      end

      it 'should find - test 3 ' do
        GeneValidator.config = {}
        GeneValidator.config[:type] = :nucleotide 
        prediction = Sequence.new
        prediction.raw_sequence = 'GGCGGGGCGGGAGGGCGGCGCGGAGTGCGCCGGCGCGTCGTC' \
                                  'GGGGACGCCGGGTCCAGGATCTTGCTAGGGAACCAGTGTTGT' \
                                  'CGCGTCGTCCCGCCCCCTCGGGGCTTTTGCTCCCGTTAACTG' \
                                  'TCGGCGGGGCAGGCTCCGCAGCGCAGGGCGACATGCCGGTGC' \
                                  'GCTTCAAGGGGCTGAGTGAATACCAGAGAAACTTCCTGTGGA' \
                                  'AAAAGTCCTATTTGTCAGAGTCTTATAATCCCTCAGTGGGAC' \
                                  'AAAAGTACTCATGGGCAGGACTTAGATCGGATCAGTTGGGGA' \
                                  'TCACGAAAGAACCAGGTTTTATTTCAAAAAGAAGAGTTCCCT' \
                                  'ACCATGACCCTCAGATTTCAAAATACCTGGAGTGGAACGGAA' \
                                  'CCGTCAGAAAGAAGGATACGCTTGTCCCACCAGAACCCCAGG' \
                                  'CCTTTGGAACGCCAAAGCCACAAGAGGCTGAGCAAGGAGAAG' \
                                  'ATGCCAATCAAGAAGCAGTTCTCTCACTAGAGGCCTCCAGGG' \
                                  'TTCCCAAGAGAACTCGGTCTCATTCTGCGGACTCGAGAGCTG' \
                                  'AAGGGGTTTCAGACACTGTGGAAAAGCACCAGGGTGTCACGA' \
                                  'GAAGCCATGCGCCAGTTAGCGCGGATGTGGAGCTGAGACCTT' \
                                  'CCAGCAAACAACCTCTCTCCCAGAGCATAGATCCCAGGTTGG' \
                                  'ATAGGCATCTTCGTAAGAAAGCTGGATTGGCCGTTGTTCCCA' \
                                  'CGAATAATGCCTTGAGAAATTCTGAATACCAAAGGCAGTTTG' \
                                  'TTTGGAAGACTTCTAAAGAAAGCGCTCCAGTGTTTGCATCCA' \
                                  'ATCAGGTTTTCCGTAATAAAAGCCAAATTATTCCACAGTTCC' \
                                  'AAGGCAATACATTCACCCACGAGACTGAATACAAGCGAAATT' \
                                  'TCAAGGGTTTAACTCCAGTGAAGGAACCAAAGTCAAGAGAGT' \
                                  'ATTTGAAAGGAAACAGCAGTCTGGAGATGCTGACTCCAGTAA' \
                                  'AGAAGGCAGATGAGCCTTTAGACTTAGAAGTAGACATGGCGT' \
                                  'CGGAAGACTCAGACCAGTCTGTAAAGAAGCCTGCTTCATGGA' \
                                  'GACACCAAAGGCTTGGAAAAGTGAATTCTGAATATAGAGCAA' \
                                  'AGTTCCTGAGCCCAGCCCAGTATTTCTATAAAGCTGGAGCTT' \
                                  'GGACCCGGGTGAAGGAGAACCTGTCAAACCAGGTTAAGGAGC' \
                                  'TCCGAGAAAAGGCCGAATCTTACAGGAAGCGAGTTCAGGGGA' \
                                  'CACATTTTTCTCGGGACCATCTGAACCAGATTATGTCGGACA' \
                                  'GCAACTGCTGTTGGGACGTCTCCTCAGTCACAAGCTCGGAAG' \
                                  'GCACCGTCAGTAGCAACATCCGAGCACTGGATCTTGCTGGAG' \
                                  'ACCTTACAAACCACAGGACCCCCCAGAAACACCCTCCTACCA' \
                                  'AACTAGAAGAAAGAAAAGTTGCCTCGGGAGAGCAGCCCCTGA' \
                                  'AAAACTCCACCAGGAGACTGGAGATGCCAGAGCCTGCCGCCT' \
                                  'CGGTCAGGAGGAAGCTGGCTTGGGATGCTGAGGAGAGCACGA' \
                                  'AGGAAGACACCCAGGAGGAGCCCAGGGCGGAGGAGGACGGGA' \
                                  'GAGAGGAGAGAGGACAGGACAAGCAGACCTGTGCGGTAGAGC' \
                                  'TGGAGAAACCGGACACACAGACACCCAAGGCAGACAGACTGA' \
                                  'CAGAAGGGTCGGAGACATCTTCTGTTTCCTCAGGGAAGGGAG' \
                                  'GCAGGCTTCCTACACCGAGGCTGAGAGAACTCGGTATCCAGC' \
                                  'GGACGCACCATGATCTCACGACGCCAGCTGTTGGTGGCGCAG' \
                                  'TCTTAGTGTCTCCATCTAAAGTGAAGCCACCAGGCCTCGAGC' \
                                  'AGAGGAGGAGAGCGTCCTCCCAAGATGGCTTAGAAACTCTGA' \
                                  'AGAAAGACATTACTAAGAAAGGAAAACCCCGTCCCATGTCTC' \
                                  'TGTTGACTTCTCCGGCTGCTGGCATGAAGACAGTTGATCCCC' \
                                  'TGCCTCTGCGAGAAGACTGTGAAGCCAATGTGCTCAGATTTG' \
                                  'CTGATACTCTTCCTGTTTCGAAAATTTTGGACCGTCAGCCCA' \
                                  'GCACCCCTGGGCAGCTGCCTCCATGTGCCCCGCCTTACTGTC' \
                                  'ATCCGTCCAGCAGGATCCAGGGCCGTCTGCGAGACCCTGAGT' \
                                  'TTCAGCACAACAATGCAGATAGACTGTCTGAGATCTCTGCTC' \
                                  'GCTCTGCAGTTTCCAGCCTCCGGGCTTTCCAGACTCTAGCCC' \
                                  'GAGCTCAGAAAAGAAAGGAGAATTTCTGGGGCAAGCCATAAA' \
                                  'CCTCTCATCTTATCTAGTGACAAGCTGGCTCATCTTTACTCA' \
                                  'CTCAGTGTGTTAAGGTTTTCAGAGGGTTTGGAGTTTCTTCTA' \
                                  'ACACTTCTGACTCAGATAATTTGAATTTTCAGTGGCTCATCT' \
                                  'TAGCCAGAAAATTGCCATGCAGCTGTGTCTAAGTCTGACTCT' \
                                  'TTGAGAGCACCTTTGCACTTGTCTGAGTACAAAGGTGCGGGG' \
                                  'TTGTGTATTTCTTCACACACTCTTGACTTTTGTGTCAGGTCT' \
                                  'CGGGGGTTGCTAGTAGAAGCCTGAAGGTCATCTACAGAATAT' \
                                  'TCTAAAGGGAGAAAATGAAGTCAACATTAAGATCTTCCAACT' \
                                  'TAATTTCCCCTCAGATTGGTCTTAGGCATTTTAATAGCTGTA' \
                                  'GGTGTCATGAAAAGAATCTCACTGTTTTATTAGCGCCTTCTG' \
                                  'TATACACAGGTGCAGTGTTAAGATGATTGGACTTTGAAAAGC' \
                                  'TGGCTGTACATATTTTTCTTATTTATGTAACAAAATTTGCTG' \
                                  'AGAGAATATGTATATTTTTGATCTTTTTATGTATTTTATTTG' \
                                  'TATAATAACTGGCATACATTTGAATAATGTCTAGATTTTGAA' \
                                  'AAATGATTTGTGAAATGGAGAATTAAAATTTTGTAGACATTT' \
                                  'AAAAATGAAAATTAAGTGTGCTTGGCTTCTTCAGGAAGTTAT' \
                                  'CATGTGGAATAAATATCTTCTAGAAGCATTCTATTAGAACTG' \
                                  'CTTAATCAAAAATTATACTACTATTGCAGCTGCTAAATGCAG' \
                                  'TGAAACTGAGTCTACAGTATTTTTTTTTTCACAAATACGAGG' \
                                  'TTTTAAAAACAGATTCATTAAAAAATTTAAACACCAAAAAAA' \
                                  'AAAAA'

        validation = OpenReadingFrameValidation.new(prediction, nil)
        result =
        { 1 => { frame: 1, orf_start: 1, orf_end: 20, coverage: 4,
                 translated_length: 1003 },
          2 => { frame: 1, orf_start: 62, orf_end: 143, coverage: 10,
                 translated_length: 1003 },
          3 => { frame: 1, orf_start: 165, orf_end: 187, coverage: 5,
                 translated_length: 1003 },
          4 => { frame: 1, orf_start: 244, orf_end: 277, coverage: 6,
                 translated_length: 1003 },
          5 => { frame: 1, orf_start: 383, orf_end: 393, coverage: 4,
                 translated_length: 1003 },
          6 => { frame: 1, orf_start: 415, orf_end: 443, coverage: 5,
                 translated_length: 1003 },
          7 => { frame: 1, orf_start: 477, orf_end: 510, coverage: 6,
                 translated_length: 1003 },
          8 => { frame: 1, orf_start: 640, orf_end: 706, coverage: 9,
                 translated_length: 1003 },
          9 => { frame: 1, orf_start: 728, orf_end: 757, coverage: 5,
                 translated_length: 1003 },
          10 => { frame: 1, orf_start: 786, orf_end: 813, coverage: 5,
                  translated_length: 1003 },
          11 => { frame: 2, orf_start: 24, orf_end: 41, coverage: 4,
                  translated_length: 1003 },
          12 => { frame: 2, orf_start: 115, orf_end: 129, coverage: 4,
                  translated_length: 1003 },
          13 => { frame: 2, orf_start: 151, orf_end: 161, coverage: 4,
                  translated_length: 1003 },
          14 => { frame: 2, orf_start: 290, orf_end: 305, coverage: 4,
                  translated_length: 1003 },
          15 => { frame: 2, orf_start: 327, orf_end: 339, coverage: 4,
                  translated_length: 1003 },
          16 => { frame: 2, orf_start: 391, orf_end: 417, coverage: 5,
                  translated_length: 1003 },
          17 => { frame: 2, orf_start: 439, orf_end: 479, coverage: 6,
                  translated_length: 1003 },
          18 => { frame: 2, orf_start: 501, orf_end: 557, coverage: 8,
                  translated_length: 1003 },
          19 => { frame: 2, orf_start: 660, orf_end: 678, coverage: 4,
                  translated_length: 1003 },
          20 => { frame: 2, orf_start: 711, orf_end: 739, coverage: 5,
                  translated_length: 1003 },
          21 => { frame: 2, orf_start: 800, orf_end: 809, coverage: 3,
                  translated_length: 1003 },
          22 => { frame: 2, orf_start: 832, orf_end: 841, coverage: 3,
                  translated_length: 1003 },
          23 => { frame: 2, orf_start: 943, orf_end: 957, coverage: 4,
                  translated_length: 1003 },
          24 => { frame: 2, orf_start: 979, orf_end: 1003, coverage: 5,
                  translated_length: 1003 },
          25 => { frame: 3, orf_start: 1, orf_end: 720, coverage: 73,
                  translated_length: 1003 },
          26 => { frame: 3, orf_start: 749, orf_end: 773, coverage: 5,
                  translated_length: 1003 },
          27 => { frame: 3, orf_start: 842, orf_end: 869, coverage: 5,
                  translated_length: 1003 },
          28 => { frame: 3, orf_start: 891, orf_end: 904, coverage: 4,
                  translated_length: 1003 },
          29 => { frame: 3, orf_start: 982, orf_end: 1003, coverage: 5,
                  translated_length: 1003 },
          30 => { frame: -1, orf_start: 69, orf_end: 81, coverage: 4,
                  translated_length: 1003 },
          31 => { frame: -1, orf_start: 106, orf_end: 115, coverage: 3,
                  translated_length: 1003 },
          32 => { frame: -1, orf_start: 178, orf_end: 219, coverage: 7,
                  translated_length: 1003 },
          33 => { frame: -1, orf_start: 299, orf_end: 391, coverage: 12,
                  translated_length: 1003 },
          34 => { frame: -1, orf_start: 436, orf_end: 447, coverage: 4,
                  translated_length: 1003 },
          35 => { frame: -1, orf_start: 469, orf_end: 540, coverage: 9,
                  translated_length: 1003 },
          36 => { frame: -1, orf_start: 562, orf_end: 575, coverage: 4,
                  translated_length: 1003 },
          37 => { frame: -1, orf_start: 597, orf_end: 617, coverage: 5,
                  translated_length: 1003 },
          38 => { frame: -1, orf_start: 639, orf_end: 655, coverage: 4,
                  translated_length: 1003 },
          39 => { frame: -1, orf_start: 728, orf_end: 818, coverage: 11,
                  translated_length: 1003 },
          40 => { frame: -1, orf_start: 863, orf_end: 885, coverage: 5,
                  translated_length: 1003 },
          41 => { frame: -1, orf_start: 950, orf_end: 963, coverage: 4,
                  translated_length: 1003 },
          42 => { frame: -1, orf_start: 985, orf_end: 1003, coverage: 4,
                  translated_length: 1003 },
          43 => { frame: -2, orf_start: 79, orf_end: 99, coverage: 5,
                  translated_length: 1003 },
          44 => { frame: -2, orf_start: 121, orf_end: 133, coverage: 4,
                  translated_length: 1003 },
          45 => { frame: -2, orf_start: 355, orf_end: 599, coverage: 26,
                  translated_length: 1003 },
          46 => { frame: -2, orf_start: 652, orf_end: 736, coverage: 11,
                  translated_length: 1003 },
          47 => { frame: -2, orf_start: 758, orf_end: 828, coverage: 9,
                  translated_length: 1003 },
          48 => { frame: -2, orf_start: 868, orf_end: 887, coverage: 4,
                  translated_length: 1003 },
          49 => { frame: -2, orf_start: 952, orf_end: 1003, coverage: 8,
                  translated_length: 1003 },
          50 => { frame: -3, orf_start: 1, orf_end: 18, coverage: 4,
                  translated_length: 1003 },
          51 => { frame: -3, orf_start: 90, orf_end: 100, coverage: 4,
                  translated_length: 1003 },
          52 => { frame: -3, orf_start: 208, orf_end: 220, coverage: 4,
                  translated_length: 1003 },
          53 => { frame: -3, orf_start: 279, orf_end: 347, coverage: 9,
                  translated_length: 1003 },
          54 => { frame: -3, orf_start: 369, orf_end: 382, coverage: 4,
                  translated_length: 1003 },
          55 => { frame: -3, orf_start: 461, orf_end: 511, coverage: 7,
                  translated_length: 1003 },
          56 => { frame: -3, orf_start: 533, orf_end: 542, coverage: 3,
                  translated_length: 1003 },
          57 => { frame: -3, orf_start: 635, orf_end: 708, coverage: 10,
                  translated_length: 1003 },
          58 => { frame: -3, orf_start: 768, orf_end: 801, coverage: 6,
                  translated_length: 1003 },
          59 => { frame: -3, orf_start: 830, orf_end: 875, coverage: 7,
                  translated_length: 1003 },
          60 => { frame: -3, orf_start: 933, orf_end: 945, coverage: 4,
                  translated_length: 1003 },
          61 => { frame: -3, orf_start: 967, orf_end: 980, coverage: 4,
                  translated_length: 1003 } }
        assert_equal(result, validation.get_orfs)
      end
    end
  end
end
