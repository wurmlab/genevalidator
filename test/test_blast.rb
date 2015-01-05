require_relative 'test_helper'
require 'minitest/autorun'
require 'fileutils'
require 'validation'
require 'genevalidator/blast'
require 'genevalidator/tabular_parser'

class TestBlastClass < Minitest::Test

  describe "Test Blast Class" do

    it "should detect nucleotide seq type" do

      filename_mrna = "test/test_files/file_mrna.txt"
      file_mrna = File.open(filename_mrna, "w+")
      file_mrna.puts(">seq1")
      query_mrna = "ATGGCTAAATTACAGAGGAAGAGAAGCAAGGCTCTTGGGTCATCTCTAGAGATGTCCCAGATAATGGATG\
CAGGAACAAACAAAATTAAAAGAAGAATAAGAGATTTAGAGAGGTTATTAAAAAAGAAGAAAGATATACT\
TCCATCCACAGTAATAATAGAAAAGGAAAGAAATTTGCAAGCTTTACGGTTGGAATTGCAGAATAATGAA\
CTCAAGAATAAGATTAAAGCCAACGCTAAAAAATATCATATGGTGAGATTCTTTGAAAAAAAAAAAGCAT\
TGAGAAAATATAACAGATTATTGAAGAAAATAAAAGAATCTGGCGCAGATGATAAAGATTTACAACAAAA\
GTTGAGAGCCACTAAAATTGAATTATGTTACGTGATAAATTTTCCCAAAACTGAAAAGTATATTGCACTA\
TATCCGAATGATACACCATCTACAGACCCAAAGGCGTAG"
      file_mrna.puts(query_mrna)
      file_mrna.close

      FileUtils.rm_rf("#{filename_mrna}.html") rescue Error
    
      default_opt = {
        validations: ["all"],
        blast_tabular_file: nil,
        blast_tabular_options: nil, 
        blast_xml_file: nil,
        db: 'swissprot -remote',
        raw: nil,
        num_threads: 1
      }

      b = Validation.new(filename_mrna, default_opt)

      File.delete(filename_mrna)
      FileUtils.rm_rf("#{filename_mrna}.html")
      assert_equal(:nucleotide, b.type,)
    end

    it "should detect protein type" do
      filename_prot = "test/test_files/file_prot.txt"
      file_prot = File.open(filename_prot, "w+")
      file_prot.puts(">seq2")
      query_prot = "MPSKKQYNLVHNDEYDTRIPLHSEEAFHRGIVFHAKFIGSMEVPRPTSRVEIVAAMRRIRYEFKAKGI\
KKKKVTLEVSVDGLKVTLRKKKKKQQQWMDENKIYLMHHPIYRIFYVSHDSHDLKIFSYIARDGSSNTFKCNVFKSSKKKKQQQWM\
DENKIYLMHHPIYRIFYVSHDSHDLKIFSYIARDGSSNTFKCNVFKSSKKSQAMRVVRTVGQAFEVCHKLSLNNATEERDRGEKER\
EREHGENHRDVYEDQDEIPNVQSQPSPSSVHKDISLLGDTEDSAPEQTTVPCLLRSHEVPATTASTSPIRQSPSGTVTSDCGGLLV\
GGELTALKHEIQLLRERLEQQSQQTRAAVAHARLLQDQLAAETAARVEAQARTHQLLMQNKELLEHISALVGHLREQERISSGHVT\
SQSQLPGSAAIQQTTTVPDLSNLGQSLSYPGNLSTIGIQGNSNTDQLQFQAQLLERLHNISPYQPQRSPYNTPSPYTMGPSLLVPP\
NNIPTNSAQLSPSHSMSLRVSQSNSFSSSPIMTHKLDNYVGNTENTEYKSTFIKPIPCTNERNVNHEAVGKQDRNNLHEEIPPIVL\
DPPPQGKRSETTPKHVPTKENLNGQISSKNVQKNLATILRTTGPPPSRTTSARLPSRNDLMSEVQRTTWARHTTK"
      file_prot.puts(query_prot)
      file_prot.close

      FileUtils.rm_rf("#{filename_prot}.html") rescue Error

      default_opt = {
        validations: ["all"],
        blast_tabular_file: nil,
        blast_tabular_options: nil, 
        blast_xml_file: nil,
        db: 'swissprot -remote',
        raw: nil,
        num_threads: 1
      }

      b = Validation.new(filename_prot, default_opt)

      File.delete(filename_prot)
      FileUtils.rm_rf("#{filename_prot}.html")
      assert_equal(:protein, b.type)

      end

    it "should raise error when input types are mixed in the fasta" do
      mixed = false
      filename_prot = "test/test_files/mixed_type.fasta"
      begin
        original_stderr = $stderr
        $stderr.reopen("/dev/null", "w")

        FileUtils.rm_rf("#{filename_prot}.html") rescue Error
 
        default_opt = {
          validations: ["all"],
          blast_tabular_file: nil,
          blast_tabular_options: nil, 
          blast_xml_file: nil,
          db: 'swissprot -remote',
          raw: nil,
          num_threads: 1
        }

        b = Validation.new(filename_prot, default_opt)
      rescue SystemExit => e
        mixed = true
      end
        $stderr = original_stderr
        assert_equal(true, mixed)
    end

    it "should parse xml input" do
      filename_prot = "test/test_files/output.xml"
      output = File.open(filename_prot, "rb").read
      iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(output).to_enum
      hits = BlastUtils.parse_next_query_xml(iterator, :protein)
      assert_equal(500, hits.length)
      assert_equal(870, hits[19].length_protein)
      assert_equal("XP_004524940", hits[19].accession_no)
      assert_equal(3, hits[19].hsp_list.length)
      assert_equal(703, hits[19].hsp_list[2].hit_from)
    end

    it "should parse tabular -6 input with default tabular format" do
      filename_prot = "test/test_files/ncbi_mrna.tab.20"
      output = File.open(filename_prot, "rb").read
      iterator_tab = TabularParser.new(filename_prot, nil, :protein)
      hits = iterator_tab.next
      assert_equal(20, hits.length)
      assert_equal(1, hits[0].hsp_list.length)
      assert_equal(111, hits[0].hsp_list[0].hit_to)
      assert(hits[0].hsp_list[0].hit_from.is_a? Fixnum)

      assert_equal(100, hits[0].hsp_list[0].pidentity)
      assert(hits[0].hsp_list[0].pidentity.is_a? Float)

      assert_equal(2.0e-44, hits[0].hsp_list[0].hsp_evalue)
      assert(hits[0].hsp_list[0].hsp_evalue.is_a? Float)
    end

    it "should parse tabular -6 input with tabular format as argument" do
      filename_prot = "test/test_files/output.tab.6"
      output = File.open(filename_prot, "rb").read
      iterator_tab = TabularParser.new(filename_prot, "qseqid sseqid sacc slen qstart qend sstart send pident length qframe evalue", :protein)
      hits = iterator_tab.next
      assert_equal(4, hits.length)
      assert_equal(199, hits[0].length_protein)
      assert_equal("EFZ19000", hits[0].accession_no)
      assert_equal(3, hits[0].hsp_list.length)
      assert_equal(100, hits[0].hsp_list[2].hit_to)
    end

    it "should parse tabular -6 input with mixed columns" do
      filename_prot = "test/test_files/output.tab.6.mixed"
      output = File.open(filename_prot, "rb").read
      iterator_tab = TabularParser.new(filename_prot, "qend sstart send pident length qframe evalue qseqid sseqid sacc slen qstart", :protein)
      hits = iterator_tab.next
      assert_equal(4, hits.length)
      assert_equal(199, hits[0].length_protein)
      assert_equal("EFZ19000", hits[0].accession_no)
      assert_equal(3, hits[0].hsp_list.length)
      assert_equal(100, hits[0].hsp_list[2].hit_to)
    end

    it "should parse tabular -7 input" do
      filename_prot = "test/test_files/output.tab.7"
      output = File.open(filename_prot, "rb").read
      iterator_tab = TabularParser.new(filename_prot, "qseqid sseqid sacc slen qstart qend sstart send length qframe evalue", :protein)
      hits = iterator_tab.next
      assert_equal(4, hits.length)
      assert_equal(199, hits[0].length_protein)
      assert_equal("EFZ19000", hits[0].accession_no)
      assert_equal(3, hits[0].hsp_list.length)
      assert_equal(100, hits[0].hsp_list[2].hit_to)
      end

    it "should remove identical matches among protein sequences" do
      filename_prot = "test/test_files/output.tab.6"
      output = File.open(filename_prot, "rb").read
      filename_fasta = "test/test_files/test_validations.fasta"

      FileUtils.rm_rf("#{filename_fasta}.html") rescue Error
      
      default_opt = {
        validations: ["all"],
        blast_tabular_file: nil,
        blast_tabular_options: nil, 
        blast_xml_file: nil,
        db: 'swissprot -remote',
        raw: nil,
        num_threads: 1
      }

      b = Validation.new(filename_fasta, default_opt) # just use a valida filename to create the object
      prediction = Sequence.new
      prediction.length_protein = 1808

      iterator_tab = TabularParser.new(filename_prot, "qseqid sseqid sacc slen qstart qend sstart send pident length qframe evalue", :protein)
      iterator_tab.next
      hits = iterator_tab.next

      # before removal
      assert_equal(2, hits.length)
      assert_equal(100, hits[0].hsp_list[0].pidentity)
      assert_in_delta(99.23, hits[0].hsp_list[1].pidentity, 0.01)
      assert_in_delta(90, hits[1].hsp_list[0].pidentity, 0.01)
      hits = b.remove_identical_hits(prediction, hits)

      # after removal of identical hits
      assert_equal(1, hits.length)
      assert_in_delta(90, hits[0].hsp_list[0].pidentity, 0.01)
      FileUtils.rm_rf("#{filename_fasta}.html")
    end

    it "should remove identical matches among nucleotide sequences with tabular input" do
      filename_prot = "test/test_files/ncbi_mrna.tab.20"
      output = File.open(filename_prot, "rb").read

      filename_fasta = "test/test_files/test_validations.fasta"

      FileUtils.rm_rf("#{filename_fasta}.html") rescue Error

      default_opt = {
        validations: ["all"],
        blast_tabular_file: nil,
        blast_tabular_options: nil, 
        blast_xml_file: nil,
        db: 'swissprot -remote',
        raw: nil,
        num_threads: 1
      }

      b = Validation.new(filename_fasta, default_opt) # just use a valida filename to create the object

      prediction = Sequence.new
      prediction.length_protein = 219/3

      iterator_tab = TabularParser.new(filename_prot, nil, :nucleotide)
      hits = iterator_tab.next

      assert_equal(20, hits.length)

      hits = b.remove_identical_hits(prediction, hits)

      assert_equal(13, hits.length)
      assert_in_delta(98.61, hits[0].hsp_list[0].pidentity, 0.01)
      FileUtils.rm_rf("#{filename_fasta}.html")
    end

    it "should remove identical matches among nucleotide sequences with xml input" do
      filename_prot = "test/test_files/ncbi_mrna.xml.20"
      output = File.open(filename_prot, "rb").read

      filename_fasta = "test/test_files/test_validations.fasta"

      FileUtils.rm_rf("#{filename_fasta}.html") rescue Error
      
      default_opt = {
        validations: ["all"],
        blast_tabular_file: nil,
        blast_tabular_options: nil, 
        blast_xml_file: nil,
        db: 'swissprot -remote',
        raw: nil,
        num_threads: 1
      }

      b = Validation.new(filename_fasta, default_opt) # just use a valida filename to create the object

      prediction = Sequence.new
      prediction.length_protein = 219/3

      iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(output).to_enum
      hits = BlastUtils.parse_next_query_xml(iterator, :protein)

      assert_equal(20, hits.length)

      hits = b.remove_identical_hits(prediction, hits)

      assert_equal(13, hits.length)
      assert_in_delta(98.61, hits[0].hsp_list[0].pidentity, 0.01)
      FileUtils.rm_rf("#{filename_fasta}.html")
    end

    it "should return error when using a nonexisting input file" do
      original_stderr = $stderr
      $stderr.reopen("/dev/null", "w")
      error = false
      begin
        default_opt = {
          validations: ["all"],
          blast_tabular_file: nil,
          blast_tabular_options: nil, 
          blast_xml_file: nil,
          db: 'swissprot -remote',
          raw: nil,
          num_threads: 1
        }

        filename_xml = "test/test_files/gost.txt"
        b = Validation.new(filename_xml, default_opt)
        output = File.open(filename_xml, "rb").read
        b.parse_output(output)
      rescue SystemExit => e
        error = true
      end
      $stderr = original_stderr
      assert_equal(true, error)
    end
  end
end
