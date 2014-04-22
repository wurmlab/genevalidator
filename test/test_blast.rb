require "rubygems"
require "shoulda"
require 'minitest'
require 'minitest/autorun'
require 'genevalidator/validation'
require 'genevalidator/blast'
require 'genevalidator/tabular_parser'

class TestBlastClass < MiniTest::Unit::TestCase

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

      begin
        FileUtils.rm_rf("#{filename_mrna}.html")
      rescue Error
      end

      b = Validation.new(filename_mrna)

      File.delete(filename_mrna)      
      assert_equal b.type, :nucleotide      
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

      begin
        FileUtils.rm_rf("#{filename_prot}.html")
      rescue Error
      end
 
      b = Validation.new(filename_prot)

      File.delete(filename_prot)
      assert_equal b.type, :protein

      end

    it "should raise error when input types are mixed in the fasta" do
      mixed = false
      filename_prot = "test/test_files/mixed_type.fasta"
      begin
        original_stderr = $stderr
        $stderr.reopen("/dev/null", "w")

        begin
          FileUtils.rm_rf("#{filename_prot}.html")
        rescue Error
        end

        b = Validation.new(filename_prot)
      rescue SystemExit => e
        mixed = true
      end
        $stderr = original_stderr
        assert_equal mixed, true
    end

    it "should parse xml input" do
      filename_prot = "test/test_files/output.xml"
      output = File.open(filename_prot, "rb").read
      iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(output).to_enum
      hits = BlastUtils.parse_next_query_xml(iterator, :protein)
      assert_equal hits.length, 500
      assert_equal hits[19].length_protein, 870
      assert_equal hits[19].accession_no, "XP_004524940"
      assert_equal hits[19].hsp_list.length, 3      
      assert_equal hits[19].hsp_list[2].hit_from, 703
    end

    it "should parse tabular -6 input with default tabular format" do
      filename_prot = "test/test_files/ncbi_mrna.tab.20"
      output = File.open(filename_prot, "rb").read
      iterator_tab = TabularParser.new(filename_prot, nil, :protein)
      hits = iterator_tab.next
      assert_equal hits.length, 20
      assert_equal hits[0].hsp_list.length, 1
      assert_equal hits[0].hsp_list[0].hit_to, 111
      assert hits[0].hsp_list[0].hit_from.is_a? Fixnum

      assert_equal hits[0].hsp_list[0].pidentity, 100
      assert hits[0].hsp_list[0].pidentity.is_a? Float
      
      assert_equal hits[0].hsp_list[0].hsp_evalue, 2.0e-44
      assert hits[0].hsp_list[0].hsp_evalue.is_a? Float
    end

    it "should parse tabular -6 input with tabular format as argument" do
      filename_prot = "test/test_files/output.tab.6"
      output = File.open(filename_prot, "rb").read
      iterator_tab = TabularParser.new(filename_prot, "qseqid sseqid sacc slen qstart qend sstart send pident length qframe evalue", :protein)
      hits = iterator_tab.next
      assert_equal hits.length, 4
      assert_equal hits[0].length_protein, 199
      assert_equal hits[0].accession_no, "EFZ19000"
      assert_equal hits[0].hsp_list.length, 3
      assert_equal hits[0].hsp_list[2].hit_to, 100
    end

    it "should parse tabular -6 input with mixed columns" do
      filename_prot = "test/test_files/output.tab.6.mixed"
      output = File.open(filename_prot, "rb").read
      iterator_tab = TabularParser.new(filename_prot, "qend sstart send pident length qframe evalue qseqid sseqid sacc slen qstart", :protein)
      hits = iterator_tab.next
      assert_equal hits.length, 4
      assert_equal hits[0].length_protein, 199
      assert_equal hits[0].accession_no, "EFZ19000"
      assert_equal hits[0].hsp_list.length, 3
      assert_equal hits[0].hsp_list[2].hit_to, 100
    end

    it "should parse tabular -7 input" do
      filename_prot = "test/test_files/output.tab.7"
      output = File.open(filename_prot, "rb").read
      iterator_tab = TabularParser.new(filename_prot, "qseqid sseqid sacc slen qstart qend sstart send length qframe evalue", :protein)
      hits = iterator_tab.next
      assert_equal hits.length, 4
      assert_equal hits[0].length_protein, 199
      assert_equal hits[0].accession_no, "EFZ19000"
      assert_equal hits[0].hsp_list.length, 3
      assert_equal hits[0].hsp_list[2].hit_to, 100
      end
=begin
    it "should remove identical matches among protein sequences" do
      filename_prot = "test/test_files/output.tab.6"
      output = File.open(filename_prot, "rb").read
      filename_fasta = "test/test_files/test_validations.fasta"

      begin
        FileUtils.rm_rf("#{filename_fasta}.html")
      rescue Error
      end

      b = Validation.new(filename_fasta) # just use a valida filename to create the object
      prediction = Sequence.new
      prediction.length_protein = 1808

      iterator_tab = TabularParser.new(filename_prot, "qseqid sseqid sacc slen qstart qend sstart send pident length qframe evalue", :protein)
      iterator_tab.next
      hits = iterator_tab.next

      # before removal
      assert_equal hits.length, 2
      assert_equal hits[0].hsp_list[0].pidentity, 100
      assert_in_delta hits[0].hsp_list[1].pidentity, 99.23, 0.01
      assert_in_delta hits[1].hsp_list[0].pidentity, 90, 0.01 
      hits = b.remove_identical_hits(prediction, hits)

      # after removal
      assert_equal hits.length, 1
      assert_in_delta hits[0].hsp_list[0].pidentity, 90, 0.01
    end

    it "should remove identical matches among nucleotide sequences with tabular input" do
      filename_prot = "test/test_files/ncbi_mrna.tab.20"
      output = File.open(filename_prot, "rb").read

      filename_fasta = "test/test_files/test_validations.fasta"

      begin
        FileUtils.rm_rf("#{filename_fasta}.html")
      rescue Error
      end

      b = Validation.new(filename_fasta) # just use a valida filename to create the object

      prediction = Sequence.new
      prediction.length_protein = 219/3

      iterator_tab = TabularParser.new(filename_prot, nil, :nucleotide)
      hits = iterator_tab.next

      assert_equal hits.length, 20

      hits = b.remove_identical_hits(prediction, hits)
 
      assert_equal hits.length, 13
      assert_in_delta hits[0].hsp_list[0].pidentity, 98.61, 0.01
    end

    it "should remove identical matches among nucleotide sequences with xml input" do
      filename_prot = "test/test_files/ncbi_mrna.xml.20"
      output = File.open(filename_prot, "rb").read

      filename_fasta = "test/test_files/test_validations.fasta"

      begin
        FileUtils.rm_rf("#{filename_fasta}.html")
      rescue Error
      end

      b = Validation.new(filename_fasta) # just use a valida filename to create the object

      prediction = Sequence.new
      prediction.length_protein = 219/3

      iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(output).to_enum
      hits = BlastUtils.parse_next_query_xml(iterator, :protein)

      assert_equal hits.length, 20

      hits = b.remove_identical_hits(prediction, hits)

      assert_equal hits.length, 13
      assert_in_delta hits[0].hsp_list[0].pidentity, 98.61, 0.01
    end
=end
    it "should return error when using a nonexisting input file" do
      original_stderr = $stderr
      $stderr.reopen("/dev/null", "w")
      error = false
      begin
        filename_xml = "test/test_files/gost.txt"
        b = Validation.new(filename_xml)
        output = File.open(filename_xml, "rb").read
        b.parse_output(output)
      rescue SystemExit => e
        error = true
      end
      $stderr = original_stderr
      assert_equal error, true

    end
  end
end
