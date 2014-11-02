require 'minitest/autorun'
require 'genevalidator/sequences'
require 'genevalidator/hsp'

class TestSequenceClass < Minitest::Test

  describe "Test Sequence Class" do

    it "should get sequence by accession for mrna" do
      seq_mrna = Sequence.new
      seq_mrna.get_sequence_by_accession_no("EF100000","nucleotide", 'swissprot -remote')
      assert_equal("AGAGTTTGAT", seq_mrna.raw_sequence[0..9])
      assert_equal("GCCCGTCAAG", seq_mrna.raw_sequence[seq_mrna.raw_sequence.length-10..seq_mrna.raw_sequence.length-1])
    end

    it "should get sequence by accession for protein" do
      seq_prot = Sequence.new
      seq_prot.get_sequence_by_accession_no("F8WCM5","protein", 'swissprot -remote')
      assert_equal("MALWMRLLPL", seq_prot.raw_sequence[0..9])
      assert_equal("WPRRPQRSQN", seq_prot.raw_sequence[seq_prot.raw_sequence.length-10..seq_prot.raw_sequence.length-1])
    end

    it "should initialize seq tabular attributes" do
      value = "definition"
      no = 123
      seq = Sequence.new

      seq.init_tabular_attribute("sseqid", value)
      seq.init_tabular_attribute("sacc", value)
      seq.init_tabular_attribute("slen", no)
      seq.init_tabular_attribute("qseqid", value)

      assert_equal(value, seq.identifier)
      assert_equal(value, seq.accession_no)
      assert_equal(no, seq.length_protein)
      assert(seq.length_protein.is_a? Fixnum)
    end

    it "should initialize hsp tabular attributes" do
      value = 123
      seq = Hsp.new
      seq.init_tabular_attribute("qstart",value)
      seq.init_tabular_attribute("qend",value)
      seq.init_tabular_attribute("qframe",value)
      seq.init_tabular_attribute("sstart",value)
      seq.init_tabular_attribute("send",value)
      seq.init_tabular_attribute("length",value)

      protein = true
      filename_prot = "test/test_files/mixed_type.fasta"
      begin
        original_stderr = $stderr
        $stderr.reopen("/dev/null", "w")

        string2 = "ATGCTGATCGACTATGCAAT"
        seq.init_tabular_attribute("qseq",string2)
        seq.init_tabular_attribute("sseq",string2)
      rescue SequenceTypeError => e
        protein = false
      end
      $stderr = original_stderr
      assert_equal(false, protein)
      string = "IEDLRHSLIEDLRHS"
      seq.init_tabular_attribute("qseq",string)
      seq.init_tabular_attribute("sseq",string)

      fl = 1.253436
      seq.init_tabular_attribute("evalue",fl)

      assert_equal(value, seq.match_query_from)
      assert(seq.match_query_from.is_a? Fixnum)

      assert_equal(value, seq.match_query_to)
      assert(seq.match_query_to.is_a? Fixnum)

      assert_equal(value, seq.query_reading_frame)
      assert(seq.query_reading_frame.is_a? Fixnum)

      assert_equal(value, seq.hit_from)
      assert(seq.hit_from.is_a? Fixnum)

      assert_equal(value, seq.hit_to)
      assert(seq.hit_to.is_a? Fixnum)

      assert_equal(string, seq.query_alignment)
      assert_equal(string, seq.hit_alignment)
      assert_equal(fl, seq.hsp_evalue)
      assert(seq.hsp_evalue.is_a? Float)
    end

  end
end
