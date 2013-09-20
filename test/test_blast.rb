require "rubygems"
require "shoulda"
require 'mini_shoulda'
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
 
      b = Validation.new(filename_prot)

      File.delete(filename_prot)
      assert_equal b.type, :protein

    end

    it "should raise error when input types are mixedin the fasta" do
      mixed = false
      filename_prot = "test/test_files/mixed_type.fasta"
      begin
        original_stderr = $stderr
        $stderr.reopen("/dev/null", "w")
        b = Validation.new(filename_prot)
      rescue SystemExit => e
        mixed = true
      end
        $stderr = original_stderr
        assert_equal mixed, true
    end


    it "should parse xml input" do
      filename_prot = "test/test_files/output.xml"
      b = Validation.new(filename_prot)
      output = File.open(filename_prot, "rb").read
      iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(output).to_enum
      hits = BlastUtils.parse_next_query_xml(iterator, b.type)
      assert_equal hits.length, 500
      assert_equal hits[19].length_protein, 870
      assert_equal hits[19].accession_no, "XP_004524940"
      assert_equal hits[19].hsp_list.length, 3      
      assert_equal hits[19].hsp_list[2].hit_from, 703
    end

    it "should parse tabular -6 input" do
      filename_prot = "test/test_files/output.tab.6"
      b = Validation.new(filename_prot)
      output = File.open(filename_prot, "rb").read
      iterator_tab = TabularParser.new(output, "qseqid sseqid sacc slen qstart qend sstart send pident length qframe evalue", b.type)
      hits = iterator_tab.next
      assert_equal hits.length, 4
      assert_equal hits[0].length_protein, 199
      assert_equal hits[0].accession_no, "EFZ19000"
      assert_equal hits[0].hsp_list.length, 3
      assert_equal hits[0].hsp_list[2].hit_to, 100
    end

    it "should raiseexception if tabular columns do not correspond to -t argument" do
      error = false
      original_stderr = $stderr
      $stderr.reopen("/dev/null", "w")

      begin
        filename_prot = "test/test_files/output.tab.6"
        b = Validation.new(filename_prot)
        output = File.open(filename_prot, "rb").read
        iterator_tab = TabularParser.new(output, "qseqid sseqid sacc slen qstart qend sstart send pident length qframe", b.type)
        hits = iterator_tab.next
      rescue SystemExit => e
        error = true
      end
      $stderr = original_stderr
      assert_equal error, true

    end

    it "should parse tabular -7 input" do
      filename_prot = "test/test_files/output.tab.7"
      b = Validation.new(filename_prot)
      output = File.open(filename_prot, "rb").read
      iterator_tab = TabularParser.new(output, "qseqid sseqid sacc slen qstart qend sstart send length qframe evalue", b.type)
      hits = iterator_tab.next
      assert_equal hits.length, 4
      assert_equal hits[0].length_protein, 199
      assert_equal hits[0].accession_no, "EFZ19000"
      assert_equal hits[0].hsp_list.length, 3
      assert_equal hits[0].hsp_list[2].hit_to, 100
    end

    it "should remove identical matches among protein sequences" do
      filename_prot = "test/test_files/output.tab.6"
      b = Validation.new(filename_prot)
      output = File.open(filename_prot, "rb").read

      prediction = Sequence.new
      prediction.length_protein = 1808

      iterator_tab = TabularParser.new(output, "qseqid sseqid sacc slen qstart qend sstart send pident length qframe evalue", b.type)
      iterator_tab.next
      hits = iterator_tab.next
      # before removal
      assert_equal hits.length, 2
      assert_equal hits[0].hsp_list[0].pidentity, 100
      assert_equal hits[0].hsp_list[1].pidentity, 99
      assert_equal hits[1].hsp_list[0].pidentity, 90
      hits = b.remove_identical_hits(prediction, hits)
      # after removal
      assert_equal hits.length, 1
      assert_equal hits[0].hsp_list[0].pidentity, 90
    end

    it "should remove identical matches among nucleotide sequences" do
      filename_prot = "test/test_files/ncbi_mrna.xml"
      b = Validation.new(filename_prot)
      output = File.open(filename_prot, "rb").read

      prediction = Sequence.new
      prediction.length_protein = 258

      iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(output).to_enum
      hits = BlastUtils.parse_next_query_xml(iterator, b.type)
      hits = b.remove_identical_hits(prediction, hits)

      assert_equal hits.length, 2
      assert_in_delta hits[0].hsp_list[0].pidentity, 98.83, 0.01
    end

    it "should return error when parsing a random blast input file" do
      original_stderr = $stderr
      $stderr.reopen("/dev/null", "w")
      error = false
      begin
        filename_prot = "test/test_files/error.txt"
        b = Validation.new(filename_prot)
        output = File.open(filename_prot, "rb").read
        b.parse_xml_output(output)
      rescue SystemExit => e
        error = true
      end
      $stderr = original_stderr
      assert_equal error, true

    end 
  
  end
end
