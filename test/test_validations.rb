require_relative 'test_helper'
require 'minitest/autorun'
require 'yaml'
require 'fileutils'

require 'genevalidator'
require 'genevalidator/blast'
require 'genevalidator/validation_length_cluster'
require 'genevalidator/validation_length_rank'
require 'genevalidator/validation_blast_reading_frame'
require 'genevalidator/validation_gene_merge'
require 'genevalidator/validation_duplication'
require 'genevalidator/validation_open_reading_frame'
require 'genevalidator/validation_alignment'
require 'genevalidator/validation'

module GeneValidator
  # Class that initalises a separate Validate.new() instance for each query.
  class Validate
    # Extend Validate Class with an alternative validate method that
    # doesn't produce the output and returns the output instance
    def validate_without_output(prediction, hits, current_idx)
      hits = remove_identical_hits(prediction, hits)
      vals = create_validation_tests(prediction, hits)
      check_validations(vals)
      vals.each(&:run)
      @run_output = Output.new(current_idx, hits.length, prediction.definition)
      @run_output.validations = vals.map(&:validation_report)
      check_validations_output(vals)
      @run_output
    end
  end

  # Test the output produced by the validations
  class ValidateOutput < Minitest::Test
    filename_fasta   = 'test/test_files/test_sequences.fasta'
    filename_xml     = "#{filename_fasta}.blast_xml"
    filename_xml_raw = "#{filename_fasta}.blast_xml.raw_seq"

    opt = {
      input_fasta_file: filename_fasta,
      validations: ['all'],
      db: 'swissprot -remote',
      raw_sequences: filename_xml_raw,
      num_threads: 1,
      min_blast_hits: 5,
      force_rewrite: true,
      test: true
    }
    GeneValidator.init(opt)
    val      = GeneValidator::Validate.new
    xml      = File.open(filename_xml, 'rb').read
    iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(xml).to_enum

    describe 'Detailed Validation of normal Insulin Query' do
      hits = BlastUtils.parse_next(iterator, :nucleotide)
      prediction              = Query.new
      prediction.definition   = ''
      prediction.identifier   = ''
      prediction.type         = :nucleotide
      prediction.raw_sequence = 'ATGGCTCTCTGGATCCGGTCGCTGCCTCTCCTGGCCCTTCTTGC' \
                                'TCTTTCTGGCCCTGGGATCAGCCACGCAGCTGCCAACCAGCACC' \
                                'TCTGTGGCTCCCACTTGGTTGAGGCTCTCTACCTGGTGTGTGGG' \
                                'GAGCGGGGTTTCTTCTACTCCCCCAAAACACGGCGGGACGTTGA' \
                                'GCAGCCTCTAGTGAACGGTCCCCTGCATGGCGAGGTGGGAGAGC' \
                                'TGCCGTTCCAGCATGAGGAATACCAGAAAGTCAAGCGAGGCATC' \
                                'GTTGAGCAATGCTGTGAAAACCCGTGCTCCCTCTACCAACTGGA' \
                                'AAACTACTGCAACTAG'

      prediction.length_protein = 108
      vals = val.validate_without_output(prediction, hits, 1).validations

      lcv = vals.select { |v| v.class == LengthClusterValidationOutput }[0]
      lrv = vals.select { |v| v.class == LengthRankValidationOutput }[0]
      rfv = vals.select { |v| v.class == BlastRFValidationOutput }[0]
      gmv = vals.select { |v| v.class == GeneMergeValidationOutput }[0]
      dv  = vals.select { |v| v.class == DuplicationValidationOutput }[0]
      av  = vals.select { |v| v.class == AlignmentValidationOutput }[0]
      ov  = vals.select { |v| v.class == ORFValidationOutput }[0]

      it 'should check the number of hits' do
        assert_equal(499, hits.length)
      end

      it 'should validate length by clusterization' do
        assert_equal([81, 159], lcv.limits)
        assert_equal(108, lcv.query_length)
        assert_equal(:yes, lcv.result)
      end

      it 'should validate length by rank' do
        assert_equal('', lrv.msg)
        assert_equal(108, lrv.query_length)
        assert_equal(499, lrv.no_of_hits)
        assert_equal(105, lrv.median)
        assert_equal(92, lrv.mean)
        assert_equal(23, lrv.smallest_hit)
        assert_equal(526, lrv.largest_hit)
        assert_equal(161, lrv.extreme_hits)
        assert_equal(32.0, lrv.percentage.round(4))
        assert_equal(:yes, lrv.result)
      end

      it 'should validate gene merge' do
        assert_equal(-0.6, gmv.slope.round(4))
        assert_equal(false, gmv.unimodality)
        assert_equal(0.4, gmv.threshold_down)
        assert_equal(1.2, gmv.threshold_up)
        assert_equal(:no, gmv.result)
      end

      it 'should validate duplication' do
        assert_equal(1, dv.pvalue.round(4))
        assert_equal(1.0, dv.average)
        assert_equal(:yes, dv.result)
      end

      it 'should validate blast reading frame' do
        assert_equal({ 1 => 500 }, rfv.frames)
        assert_equal(500, rfv.total_hsp)
        assert_equal(:yes, rfv.result)
      end

      it 'should validate open reading frames' do
        expected_orf = { 1 => { frame: 1, orf_start: 1, orf_end: 105,
                                coverage: 100, translated_length: 106 },
                         2 => { frame: 2, orf_start: 1, orf_end: 59,
                                coverage: 58, translated_length: 105 },
                         3 => { frame: 2, orf_start: 64, orf_end: 105,
                                coverage: 42, translated_length: 105 },
                         4 => { frame: 3, orf_start: 1, orf_end: 33,
                                coverage: 33, translated_length: 105 },
                         5 => { frame: -1, orf_start: 1, orf_end: 44,
                                coverage: 43, translated_length: 106 },
                         6 => { frame: -1, orf_start: 48, orf_end: 106,
                                coverage: 57, translated_length: 106 },
                         7 => { frame: -2, orf_start: 10, orf_end: 56,
                                coverage: 46, translated_length: 105 },
                         8 => { frame: -2, orf_start: 70, orf_end: 105,
                                coverage: 36, translated_length: 105 },
                         9 => { frame: -3, orf_start: 25, orf_end: 84,
                                coverage: 58, translated_length: 105 } }
        assert_equal(expected_orf, ov.orfs)
        assert_equal(100.0, ov.coverage.round(4))
        assert_equal(1, ov.mainORFFrame)
        assert_equal(:yes, ov.result)
      end

      it 'should validate alignment' do
        assert_equal('0%', av.gaps)
        assert_equal('1%', av.extra_seq)
        assert_equal('94%', av.consensus)
        assert_equal(:yes, av.result)
      end
    end

    describe 'Validate a trancated sequence' do
      hits = BlastUtils.parse_next(iterator, :nucleotide)
      prediction              = Query.new
      prediction.definition   = ''
      prediction.identifier   = ''
      prediction.type         = :nucleotide
      prediction.raw_sequence = 'ATGGCTCTCTGGATCCGGTCGCTGCCTCTCCTGGCCCTTCTTGC' \
                                'TCTTTCTGGCCCTGGGATCAGCCACGCAGCTGCCAACCAGCACC' \
                                'TCTGTGGCTCCCACTTGGTTGAGGCTCTCTACCTGGTGTGTGGG' \
                                'GAGCGGGG'
      prediction.length_protein = 46

      vals = val.validate_without_output(prediction, hits, 1).validations

      lcv = vals.select { |v| v.class == LengthClusterValidationOutput }[0]
      lrv = vals.select { |v| v.class == LengthRankValidationOutput }[0]
      rfv = vals.select { |v| v.class == BlastRFValidationOutput }[0]
      gmv = vals.select { |v| v.class == GeneMergeValidationOutput }[0]
      dv  = vals.select { |v| v.class == DuplicationValidationOutput }[0]
      av  = vals.select { |v| v.class == AlignmentValidationOutput }[0]
      ov  = vals.select { |v| v.class == ORFValidationOutput }[0]

      it 'should validate as expected' do
        assert_equal(:no, lcv.result)
        assert_equal(:no, lrv.result)
        assert_equal(:no, gmv.result)
        assert_equal(:yes, dv.result)
        assert_equal(:yes, rfv.result)
        assert_equal(:yes, ov.result)
        assert_equal(:no, av.result)
      end
    end

    describe 'Validate a duplicated sequence' do
      hits = BlastUtils.parse_next(iterator, :nucleotide)
      prediction              = Query.new
      prediction.definition   = ''
      prediction.identifier   = ''
      prediction.type         = :nucleotide
      prediction.raw_sequence = 'ATGGCTCTCTGGATCCGGTCGCTGCCTCTCCTGGCCCTTCTTGC' \
                                'TCTTTCTGGCCCTGGGATCAGCCACGCAGCTGCCAACCAGCACC' \
                                'TCTGTGGCTCCCACTTGGTTGAGGCTCTCTACCTGGTGTGTGGG' \
                                'GAGCGGGGTTTCTTCTACTCCCCCAAAACACGGCGGGACGTTGA' \
                                'GCAGCCTCTAGTGAACGGTCCCCTGCATGGCGAGGTGGGAGAGC' \
                                'TGCCGTTCCAGCATGAGGAATACCAGAAAGTCAAGCGAGGCATC' \
                                'GTTGAGCAATGCTGTGAAAACCCGTGCTCCCTCTACCAACTGGA' \
                                'AAACTACTGCAACTAGGCCCTGGGATCAGCCACGCAGCTGCCAA' \
                                'CCAGCACCTCTGTGGCTCCCACTTGGTTGAGGCTCTCTACCTGG' \
                                'TGTGTGGGGAGCGGGGTTTCTTCTACTCCCCCAAAACACGGCGG' \
                                'GACGTTGAGCAGCCTCTAGTGAACGGTCCCCTGCATGGCGAGGT' \
                                'GGGAGAGCTGCCGTTCCAGCATGAGGAATACCAGAAAGTCAAGC' \
                                'GAGGCATCGTTGAGCAATGCTGTGAAAACCCGTGCTCCCTCTAC' \
                                'CAACTGGAAAACTACTGCAACTAG'
      prediction.length_protein = 46

      vals = val.validate_without_output(prediction, hits, 1).validations

      lcv = vals.select { |v| v.class == LengthClusterValidationOutput }[0]
      lrv = vals.select { |v| v.class == LengthRankValidationOutput }[0]
      rfv = vals.select { |v| v.class == BlastRFValidationOutput }[0]
      gmv = vals.select { |v| v.class == GeneMergeValidationOutput }[0]
      dv  = vals.select { |v| v.class == DuplicationValidationOutput }[0]
      av  = vals.select { |v| v.class == AlignmentValidationOutput }[0]
      ov  = vals.select { |v| v.class == ORFValidationOutput }[0]

      it 'should validate as expected' do
        assert_equal(:no, lcv.result)
        assert_equal(:no, lrv.result)
        assert_equal(:no, gmv.result)
        assert_equal(:no, dv.result)
        assert_equal(:no, rfv.result)
        assert_equal(:no, ov.result)
        assert_equal(:no, av.result)
      end
    end

    describe 'Validate a merged sequence' do
      hits = BlastUtils.parse_next(iterator, :nucleotide)

      prediction              = Query.new
      prediction.definition   = ''
      prediction.identifier   = ''
      prediction.type         = :nucleotide
      prediction.raw_sequence = 'ATGGCTCTCTGGATCCGGTCGCTGCCTCTCCTGGCCCTTCTTGC' \
                                'TCTTTCTGGCCCTGGGATCAGCCACGCAGCTGCCAACCAGCACC' \
                                'TCTGTGGCTCCCACTTGGTTGAGGCTCTCTACCTGGTGTGTGGG' \
                                'GAGCGGGGTTTCTTCTACTCCCCCAAAACACGGCGGGACGTTGA' \
                                'GTTTCAATGAATATAGTCTCATAGTACCTAGTAGCTCAGCTCTA' \
                                'ATTTATTCTTTTCCTCTTGGCTGAGGTAGGGTGCTGCTGGCCCC' \
                                'CCTGGCCCTCCTGGTCCAAGTGGTGAGGAAGGCAAGAGAGGCAG' \
                                'CAATGGTGGGTCGACTACCTGTGTGCACAGGATGCCTGACACCA' \
                                'TGCTGCCCGCCTGCTTCCTCGGCCTACTGGCCTTCTCCTCCGCG' \
                                'TGCTACTTCCAGAACTGCCCGAGGGGCGGCAAGAGGGCCATGTC' \
                                'CGACCTGGAGCTGAGACAGTGCCTCCCCTGCGGCCCCGGGGGCA' \
                                'AAGGCCGCTGCTTCGGGCCCAGCATCTGCTGCGCGGACGAGC'
      prediction.length_protein = 175

      vals = val.validate_without_output(prediction, hits, 1).validations

      lcv = vals.select { |v| v.class == LengthClusterValidationOutput }[0]
      lrv = vals.select { |v| v.class == LengthRankValidationOutput }[0]
      rfv = vals.select { |v| v.class == BlastRFValidationOutput }[0]
      gmv = vals.select { |v| v.class == GeneMergeValidationOutput }[0]
      dv  = vals.select { |v| v.class == DuplicationValidationOutput }[0]
      av  = vals.select { |v| v.class == AlignmentValidationOutput }[0]
      ov  = vals.select { |v| v.class == ORFValidationOutput }[0]

      it 'should validate length cluster validation' do
        assert_equal(:no, lcv.result)
        assert_equal(:no, lrv.result)
        assert_equal(:yes, gmv.result)
        assert_equal(:yes, dv.result)
        assert_equal(:yes, rfv.result)
        assert_equal(:no, ov.result)
        assert_equal(:no, av.result)
      end
    end

    describe 'Validate a sequence with a frameshift' do
      hits = BlastUtils.parse_next(iterator, :nucleotide)

      prediction              = Query.new
      prediction.definition   = ''
      prediction.identifier   = ''
      prediction.type         = :nucleotide
      prediction.raw_sequence = 'AGCCCACTGAAAAAACATCCGTGAGGGAATGATTAAGCAGCATC' \
                                'AAAATGTTTATTGAAATTCATTTCTTTAGTAATCTGGTGGCATC' \
                                'TAATTGCCTTGGCCATGGTTTTCTAGGGTTTCCCTGGAGCAGAT' \
                                'GGTAGGGTTGGGCCAATCGGTCCAGCCGGTAATAGAGGTGAACC' \
                                'TGGCAACATTGGATTCCCTGGACCAAAAGGTCCCACTGTAAGTA' \
                                'CACCTTCAGGGTGAGCCTGGCAAACCTGGTGAAAAAGGCAATGT' \
                                'CGGTCTTGCTGGCCCACGGGTACGTGGGGCAAACCAGGCGAAAG' \
                                'GGGTCTCCATGGTGAATTTGGTGTCCCTGGTCCTGCTGGCCCAA' \
                                'GGGGCTTCAACAGGGCAATCCTGGAAATGATGGTCCTCCAGGCC' \
                                'GTGATGGTGCTCCTGGCTTCAAGGTAGACTTGTTCACAGGGTGA' \
                                'GCGTGGTGCTCCTGGTAACCCAGGTCCCGGTCCTTCTGGAAAGC' \
                                'CTGGAAACCGTGGTGATCCTGTAAGTTGTGTTCCAGGGTCCTGT' \
                                'TGGTCCTGTTGGTCCTGCTGGTGCTTTTGGCCCAAGAGGTCTCG' \
                                'CTGTAAGTCTGGATTAACACTTTTCATGGGTGTCTTAACAGAAT' \
                                'ACACATAAATATATCAGGGGCCACCTGTGGCAATGCAGAACACT' \
                                'TAATTCATTCTTTGTCAGTAATATCTAATTCAGGCCTTCTCTGG' \
                                'CATGTATATCCTTTCCTAGGGCCCACAAGGTCCACGTGGTGAGA' \
                                'AAGGTGAACATGGTGATAAGGGACATAGAGGTCTGCCTGGCCTG' \
                                'AAGGGACACAATGGGTTGCAGGGTCTTCCTGGTCTTGCTGTAAG' \
                                'TAAATGATTTTCAGTAATTTTTTTGGTATAAGATCCAAACACTC' \
                                'GGTCTCCACATAATAGAGATGAGAAAACAGTCTCTTATTTTAAA' \
                                'GGCTTTACTGGAAACCCTAAGAGACAATACAAGAGACTACTATA' \
                                'GGTTATACCTTTAAATAACTTTTTTACTCACTTTCCTCCCACAT' \
                                'TTTATATCCCAACTCCACTAATGCCAGTTGCCCAAGATTTCAGT' \
                                'TCTCTGAACCCAAATATGTCTGCTGATCCCCTCTTGAATCATGT' \
                                'TAATACAATGTGTGGCATTGCATTTTTTAATGATGCATTTCTTT' \
                                'TCCCAATAGGGCCAACATGGTGATCAAGGTCCTCCTGGTAACAA' \
                                'CGGTCCAGCTGGCCCAAGGGTATGTGAATTCAAGAGTATATGCA' \
                                'AATAATTCTCCTATTCCTTTTATGGAATATATTTGTACACTGTC' \
                                'CTTTGTATGAANNNNNNATTTGTAGTGTTCCCTACTGTTGTTAA' \
                                'ACTGTTCAAGTTTTCTTCTAGGGTCCTCATGGTCCTTCTGGTCC' \
                                'TCATGGTAAGGATGGTCGCAATGGTCTCCCTGGACCCATTGGCC' \
                                'CTGCTGGTGTACGTGGATCTCATGGTAGCCAAGGCCCTGCTGTG' \
                                'AGTACTTATGGCCAGCCAGTATAAGCACAAAGGTTTGGTAGTTC' \
                                'CACACAGTGTATCTTCTGCTTCAGTTCACAGGAGTTACCACAGA' \
                                'GCAGGTCCATAGGTCCTTCCTCAGATTATTGTTGAGGGTTCTAA' \
                                'GACTTCAGAAGGACAACGCATGTGTGGAAATAGTCAGCTGAAAG' \
                                'TATCATAAATGTGATAGAATACTAATTGTCTTTTGCTTTTGAAA' \
                                'AACTTTAGGGCCCTCCTGGCCCTCCTGGTCCCCCCGGCCCCCCT' \
                                'GGTCCCAATGGTGGCGGATATGAAGTTGGCTTTGATGCAGAATA' \
                                'CTACCGGGCTGATCAGCCTTCTCTCAGACCCAAGGATTATGAAG' \
                                'TTGATGCCACTCTGAAAACATTGAACAACCAAATTGAGACCCTG' \
                                'CTGACCCCAGAAGGCTCCAAAAAGAATCCGGCTCGCACCTGCCG' \
                                'TGACCTCAGACTTAGCCACCCAGAATGGAGCAGCGGTACGTGGT' \
                                'GCCAGATGTTTCCTCTTTCTGGCTCAGCATAGTTATTTTCAGCT' \
                                'TATTAGCTTTCTTTTGGTCCGCGAGGCGCCTCTCGTCCTCAAGG' \
                                'GTTTCTCCTGGATTGCGCCTAACCACGGCTGTACTGCAGATGCC' \
                                'ATTAGAGCATACTGTGACTTTGCTACTGGTGAGACTTGCATCCA' \
                                'TGCTAGCCTTGAAATAATTCCGACTAAGACATGGTATGTCAGCA' \
                                'AGAACCCCAAGGACAAAAAGCACATATGGTTCGGTGAAACTATC' \
                                'AATGGTGGTACTCAGGTATGTGATGCATTGGAGGATGATTGTTT' \
                                'CCTACAGTGCTTTTTAAGAATTTGCTACCTCTCAGTGAGCTTAA' \
                                'CTCATTTTTTAATCTCTTAGAGGAGAAATACAAAATGGGGCCAT' \
                                'TTCTAACGGAATCCTGTCTGGAATATGCTACTTTAGTACAAAGA' \
                                'CAGTCCAGAAACAGAGAAAGTAATGAAATAATTTTTGCAATCTT' \
                                'TTAAATTGGGATTTATTTTTGACATATTGTGCTAGTTCAAAGGA' \
                                'ATTGATATTTTTATTACACTGAAACTTGAAATTACTAGTATGTT' \
                                'AGATATTGTTAC'
      prediction.length_protein = 840

      vals = val.validate_without_output(prediction, hits, 1).validations

      lcv = vals.select { |v| v.class == LengthClusterValidationOutput }[0]
      lrv = vals.select { |v| v.class == LengthRankValidationOutput }[0]
      rfv = vals.select { |v| v.class == BlastRFValidationOutput }[0]
      gmv = vals.select { |v| v.class == GeneMergeValidationOutput }[0]
      dv  = vals.select { |v| v.class == DuplicationValidationOutput }[0]
      av  = vals.select { |v| v.class == AlignmentValidationOutput }[0]
      ov  = vals.select { |v| v.class == ORFValidationOutput }[0]

      it 'should validate length cluster validation' do
        assert_equal(:no, lcv.result)
        assert_equal(:no, lrv.result)
        assert_equal(:no, gmv.result)
        assert_equal(:yes, dv.result)
        assert_equal(:no, rfv.result)
        assert_equal(:no, ov.result)
        assert_equal(:no, av.result)
      end
    end
  end
end
