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

module GeneValidator
  class ValidateOutput < Minitest::Test
    filename         = 'test/test_files/test_validations'
    filename_fasta   = "#{filename}.fasta"
    filename_xml     = "#{filename}.xml"
    filename_xml_raw = "#{filename_xml}.raw_seq"
    FileUtils.rm_rf("#{filename_fasta}.html") rescue Error

    opt = {
      input_fasta_file: filename_fasta,
      validations: ['all'],
      blast_xml_file: filename_xml,
      db: 'swissprot -remote',
      num_threads: 1,
      raw_sequences: filename_xml_raw
    }

    val      = GeneValidator::Validation.new(opt)
    output   = File.open(filename_xml, 'rb').read
    iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(output).to_enum
    hits     = BlastUtils.parse_next_query_xml(iterator, :nucleotide)

    prediction              = Sequence.new
    prediction.definition   = ''
    prediction.identifier   = ''
    prediction.type         = :nucleotide
    prediction.raw_sequence = 'ATGGCTCTCTGGATCCGGTCGCTGCCTCTCCTGGCCCTTCTTGCT' \
                              'CTTTCTGGCCCTGGGATCAGCCACGCAGCTGCCAACCAGCACCTC' \
                              'TGTGGCTCCCACTTGGTTGAGGCTCTCTACCTGGTGTGTGGGGAG' \
                              'CGGGGTTTCTTCTACTCCCCCAAAACACGGCGGGACGTTGAGCAG' \
                              'CCTCTAGTGAACGGTCCCCTGCATGGCGAGGTGGGAGAGCTGCCG' \
                              'TTCCAGCATGAGGAATACCAGAAAGTCAAGCGAGGCATCGTTGAG' \
                              'CAATGCTGTGAAAACCCGTGCTCCCTCTACCAACTGGAAAACTAC' \
                              'TGCAACTAG'

    prediction.length_protein = 108

    validations = val.do_validations(prediction, hits, 1).validations

    describe 'Test validations 1' do
      it 'should check the number of hits' do
        assert_equal(499, hits.length)
      end

      it 'should validate length by clusterization' do
        lcv = validations.select { |v| v.class == LengthClusterValidationOutput }[0]
        assert_equal([23, 135], lcv.limits)
        assert_equal(108, lcv.query_length)
        assert_equal(:yes, lcv.result)
      end

      it 'should validate length by rank' do
        lrv = validations.select { |v| v.class == LengthRankValidationOutput }[0]
        assert_equal('', lrv.msg)
        assert_equal(108, lrv.query_length)
        assert_equal(499, lrv.no_of_hits)
        assert_equal(107, lrv.median)
        assert_equal(107, lrv.mean)
        assert_equal(23, lrv.smallest_hit)
        assert_equal(526, lrv.largest_hit)
        assert_equal(230, lrv.extreme_hits)
        assert_equal(46.0, lrv.percentage.round(4))
        assert_equal(:yes, lrv.result)
      end

      it 'should validate blast reading frame' do
        rfv = validations.select { |v| v.class == BlastRFValidationOutput }[0]
        assert_equal({ 1 => 500 }, rfv.frames_histo)
        assert_equal(500, rfv.total_hsp)
        assert_equal(:yes, rfv.result)
      end

      it 'should validate gene merge' do
        gmv = validations.select { |v| v.class == GeneMergeValidationOutput }[0]
        assert_equal(-0.4059, gmv.slope.round(4))
        assert_equal(false, gmv.unimodality)
        assert_equal(0.4, gmv.threshold_down)
        assert_equal(1.2, gmv.threshold_up)
        assert_equal(:no, gmv.result)
      end

      it 'should validate duplication' do
        dv = validations.select { |v| v.class == DuplicationValidationOutput }[0]
        assert_equal(1, dv.pvalue.round(4))
        assert_equal(1.0, dv.average)
        assert_equal(:yes, dv.result)
      end

      it 'should validate alignment' do
        av = validations.select { |v| v.class == AlignmentValidationOutput }[0]
        assert_equal('0%', av.gaps)
        assert_equal('1%', av.extra_seq)
        assert_equal('100%', av.consensus)
        assert_equal(:yes, av.result)
      end

      it 'should validate open reading frames' do
        ov = validations.select { |v| v.class == ORFValidationOutput }[0]
        expected_orf = { 1 => { frame: 1, orf_start: 1, orf_end: 105, coverage: 100, translated_length: 106 },
                         2 => { frame: 2, orf_start: 1, orf_end: 59, coverage: 58, translated_length: 105 },
                         3 => { frame: 2, orf_start: 64, orf_end: 105, coverage: 42, translated_length: 105 },
                         4 => { frame: 3, orf_start: 1, orf_end: 33, coverage: 33, translated_length: 105 },
                         5 => { frame: -1, orf_start: 1, orf_end: 44, coverage: 43, translated_length: 106 },
                         6 => { frame: -1, orf_start: 48, orf_end: 106, coverage: 57, translated_length: 106 },
                         7 => { frame: -2, orf_start: 10, orf_end: 56, coverage: 46, translated_length: 105 },
                         8 => { frame: -2, orf_start: 70, orf_end: 105, coverage: 36, translated_length: 105 },
                         9 => { frame: -3, orf_start: 25, orf_end: 84, coverage: 58, translated_length: 105 } }
        assert_equal(expected_orf, ov.orfs)
        assert_equal(100.0, ov.coverage.round(4))
        assert_equal(1, ov.mainORFFrame)
        assert_equal(:yes, ov.result)
      end
    end

    FileUtils.rm_rf('#{filename_fasta}.html')
  end
end
