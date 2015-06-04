require_relative 'test_helper'
require 'minitest/autorun'
require 'yaml'
require 'fileutils'
require 'genevalidator'

module GeneValidator
  # Test if GV produces the same output with XML and tabular input
  class ValidateOutput < Minitest::Test
    prot_dir    = 'test/test_files/all_validations_prot'
    prot_input  = File.join(prot_dir, 'prot.fa')
    prot_xml    = File.join(prot_dir, 'prot.blast_xml')
    prot_tab    = File.join(prot_dir, 'prot.blast_tab6')
    prot_raw    = File.join(prot_dir, 'prot.raw_seq')

    mrna_dir    = 'test/test_files/all_validations_mrna'
    mrna_input  = File.join(mrna_dir, 'mrna.fa')
    mrna_xml    = File.join(mrna_dir, 'mrna.blast_xml')
    mrna_tab    = File.join(mrna_dir, 'mrna.blast_tab6')
    mrna_raw    = File.join(mrna_dir, 'mrna.raw_seq')

    tab_options = 'qseqid sseqid sacc slen qstart qend sstart send length' \
                  ' qframe pident nident evalue qseq sseq'
    database    = 'swissprot -remote'
    threads     = '1'

    # Unwanted Output Files
    prot_xml_out           = "#{prot_xml}.out"
    prot_tab_out           = "#{prot_tab}.out"
    prot_output_dir        = "#{prot_input}.html"
    mrna_xml_out           = "#{mrna_xml}.out"
    mrna_tab_out           = "#{mrna_tab}.out"
    mrna_output_dir        = "#{mrna_input}.html"

    describe 'Protein dataset' do
      it 'xml and tabular inputs give the same output' do
        original_stdout = $stdout.clone
        $stdout.reopen(prot_xml_out, 'w')

        FileUtils.rm_rf(prot_output_dir) rescue Errno::ENOENT
        opts = {
          validations: %w(lenc lenr frame merge dup orf align),
          db: database,
          num_threads: threads,
          fast: false,
          input_fasta_file: prot_input,
          blast_xml_file: prot_xml,
          raw_sequences: prot_raw,
          test: true
        }

        GeneValidator.init(opts, 1, false)
        GeneValidator.run
        $stdout.reopen original_stdout
        $stdout.reopen(prot_tab_out, 'w')

        FileUtils.rm_rf(prot_output_dir) rescue Errno::ENOENT

        opts1 = {
          validations: %w(lenc lenr frame merge dup orf align),
          db: database,
          num_threads: threads,
          fast: false,
          input_fasta_file: prot_input,
          blast_tabular_file: prot_tab,
          blast_tabular_options: tab_options,
          raw_sequences: prot_raw,
          test: true
        }

        GeneValidator.init(opts1, 1, false)
        GeneValidator.run
        $stdout.reopen original_stdout

        diff = FileUtils.compare_file(prot_xml_out, prot_tab_out)

        File.delete(prot_xml_out)
        File.delete(prot_tab_out)
        FileUtils.rm_rf(prot_output_dir)

        assert_equal(true, diff)
      end
    end

    describe 'mRNA dataset' do
      it 'xml and tabular inputs give the same output' do
        original_stdout = $stdout.clone
        $stdout.reopen(mrna_xml_out, 'w')

        FileUtils.rm_rf(mrna_output_dir) rescue Errno::ENOENT

        opts = {
          validations: %w(lenc lenr frame merge dup orf align),
          db: database,
          num_threads: threads,
          fast: false,
          input_fasta_file: mrna_input,
          blast_xml_file: mrna_xml,
          raw_sequences: mrna_raw,
          test: true
        }

        GeneValidator.init(opts, 1, false)
        GeneValidator.run
        $stdout.reopen original_stdout
        $stdout.reopen(mrna_tab_out, 'w')

        FileUtils.rm_rf(mrna_output_dir) rescue Errno::ENOENT

        opts1 = {
          validations: %w(lenc lenr frame merge dup orf align),
          db: database,
          num_threads: threads,
          fast: false,
          input_fasta_file: mrna_input,
          blast_tabular_file: mrna_tab,
          blast_tabular_options: tab_options,
          raw_sequences: mrna_raw,
          test: true
        }

        GeneValidator.init(opts1, 1, false)
        GeneValidator.run
        $stdout.reopen original_stdout

        diff = FileUtils.compare_file(mrna_xml_out, mrna_tab_out)

        File.delete(mrna_xml_out)
        File.delete(mrna_tab_out)
        FileUtils.rm_rf(mrna_output_dir)

        assert_equal(true, diff)
      end
    end
  end
end
