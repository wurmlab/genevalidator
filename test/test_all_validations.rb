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

    prot_input_fasta_file  = "test/test_files/all_validations_prot/all_validations_prot.fasta"
    prot_blast_xml_file    = "#{prot_input_fasta_file}.blast_xml"
    prot_blast_xml_raw_seq = "#{prot_input_fasta_file}.blast_xml.raw_seq"

    prot_blast_tab_file    = "#{prot_input_fasta_file}.blast_tab"
    prot_blast_tab_raw_seq = "#{prot_input_fasta_file}.blast_tab.raw_seq"

    mrna_input_fasta_file  = "test/test_files/all_validations_mrna/all_validations_mrna.fasta"
    mrna_blast_xml_file    = "#{mrna_input_fasta_file}.blast_xml"
    mrna_blast_xml_raw_seq = "#{mrna_input_fasta_file}.blast_xml.raw_seq"

    mrna_blast_tab_file    = "#{mrna_input_fasta_file}.blast_tab"
    mrna_blast_tab_raw_seq = "#{mrna_input_fasta_file}.blast_tab.raw_seq"

    tab_options            = "qseqid sseqid sacc slen qstart qend sstart send length qframe pident evalue"
    validations            = ["lenc", "lenr", "frame", "merge", "dup", "orf", "align"]

    database               = "SwissProt", #'swissprot -remote'
    threads                = "8" # "1"

    # Unwanted Output Files 
    prot_xml_out           = "#{prot_blast_xml_file}.out"
    prot_tab_out           = "#{mrna_blast_tab_file}.out"
    mrna_xml_out           = "#{mrna_blast_xml_file}.out"
    mrna_tab_out           = "#{mrna_blast_tab_file}.out"
    prot_output_dir        = "#{prot_input_fasta_file}.html"
    mrna_output_dir        = "#{mrna_input_fasta_file}.html"
    prot_yaml              = "#{prot_input_fasta_file}.yaml"
    mrna_yaml              = "#{mrna_input_fasta_file}.yaml"

    # TODO: FIXME
    # THE PROBLEM: Validation_alignment produces different results each time it is run...
    # find out when this problem was introduced and find a solution...

    # describe 'Protein dataset' do
    #   it 'xml and tabular inputs give the same output' do

    #     original_stdout = $stdout.clone
    #     $stdout.reopen(prot_xml_out, 'w')

    #     FileUtils.rm_rf(prot_output_dir) rescue Error

    #     opts = {
    #       validations: validations,
    #       db: database,
    #       num_threads: threads,
    #       fast: false,
    #       input_fasta_file: prot_input_fasta_file,
    #       blast_xml_file: prot_blast_xml_file,
    #       raw_sequences: prot_blast_xml_raw_seq
    #     }

    #     (GeneValidator::Validation.new(opts, 1, false, false)).run
    #     $stdout.reopen original_stdout
    #     $stdout.reopen(prot_tab_out, 'w')

    #     FileUtils.rm_rf(prot_output_dir) rescue Error

    #     opts1 = {
    #       validations: validations,
    #       db: database,
    #       num_threads: threads,
    #       fast: false,
    #       input_fasta_file: prot_input_fasta_file,
    #       blast_tabular_file: prot_blast_tab_file,
    #       blast_tabular_options: tab_options,
    #       raw_sequences: prot_blast_tab_raw_seq
    #     }

    #     (GeneValidator::Validation.new(opts1, 1, false, false)).run
    #     $stdout.reopen original_stdout

    #     diff = FileUtils.compare_file(prot_xml_out, prot_tab_out)

    #     File.delete(prot_xml_out)
    #     File.delete(prot_tab_out)
    #     File.delete(prot_input_fasta_file)
    #     FileUtils.rm_rf(prot_output_dir)

    #     assert_equal(true, diff)
    #   end
    # end

    # describe 'mRNA dataset' do
    #   it 'xml and tabular inputs give the same output' do

    #     original_stdout = $stdout.clone
    #     $stdout.reopen(mrna_xml_out, 'w')

    #     FileUtils.rm_rf(mrna_output_dir) rescue Error

    #     opts = {
    #       validations: validations,
    #       db: database,
    #       num_threads: threads,
    #       fast: false,
    #       input_fasta_file: mrna_input_fasta_file,
    #       blast_xml_file: mrna_blast_xml_file ,
    #       raw_sequences: mrna_blast_xml_raw_seq
    #     }

    #     (GeneValidator::Validation.new(opts, 1, false, false)).run
    #     $stdout.reopen original_stdout
    #     $stdout.reopen(mrna_tab_out, 'w')

    #     FileUtils.rm_rf(mrna_output_dir) rescue Error

    #     opts1 = {
    #       validations: validations,
    #       db: database,
    #       num_threads: threads,
    #       fast: false,
    #       input_fasta_file: mrna_input_fasta_file,
    #       blast_tabular_file: mrna_blast_tab_file,
    #       blast_tabular_options: tab_options,
    #       raw_sequences: mrna_blast_tab_raw_seq
    #     }

    #     (GeneValidator::Validation.new(opts1, 1, false, false)).run
    #     $stdout.reopen original_stdout

    #     diff = FileUtils.compare_file(mrna_xml_out, mrna_tab_out)

    #     File.delete(mrna_xml_out)
    #     File.delete(mrna_tab_out)
    #     File.delete(mrna_yaml)

    #     FileUtils.rm_rf(mrna_output_dir)

    #     assert_equal(true, diff)
    #   end
    # end
  end
end
