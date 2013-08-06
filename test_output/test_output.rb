require "rubygems"
require "shoulda"
require 'mini_shoulda'
require 'minitest/autorun'
require "yaml"
require 'genevalidator/blast'

class ValidateOutput < Test::Unit::TestCase

  describe "Validate Output" do  

    def self.update_statistics(ref_value, value, variable)
      ref_value = ref_value.to_s
      value = value.to_s
      if ref_value == 'yes' and value == 'no'
        variable[:false_negatives] += 1
      else
        if ref_value == 'no' and value == 'yes'
          variable[:false_positives] += 1
        else
          variable[:positives] += 1
        end
     end
    end

    filename = ARGV[0]
    type = ARGV[1]
    filename_fasta = "#{filename}.fasta"
    puts filename_fasta
    filename_xml = "#{filename}.xml"

    b = Blast.new(filename_fasta, type, filename_xml)

    filename_yml = "#{filename}.fasta.yaml"
    filename_yml_reference = "test_output/test_reference.yaml"
    yml_ref = YAML.load_file(filename_yml_reference)

    b.blast

    # Statistics: count positives, false positives, false negatives
    length_clusterization = {}
    length_clusterization [:false_positives] = 0
    length_clusterization [:false_negatives] = 0
    length_clusterization [:positives] = 0

    length_rank = {}
    length_rank [:false_positives] = 0
    length_rank [:false_negatives] = 0
    length_rank [:positives] = 0

    gene_merge = {}
    gene_merge [:false_positives] = 0
    gene_merge [:false_negatives] = 0
    gene_merge [:positives] = 0

    duplications = {}
    duplications [:false_positives] = 0
    duplications [:false_negatives] = 0
    duplications [:positives] = 0

    reading_frame = {}
    reading_frame [:false_positives] = 0
    reading_frame [:false_negatives] = 0
    reading_frame [:positives] = 0

    main_orf = {}
    main_orf [:false_positives] = 0
    main_orf [:false_negatives] = 0
    main_orf [:positives] = 0

    yml = YAML.load_file(filename_yml)
            
    yml.each_pair do |key, value|
      # search the key in the reference file
      yml_ref.each do |elem|
        elem.each_pair do |ref_key, ref_value|          
          if ref_key == key

            update_statistics(ref_value['valid_length'], value.length_validation_cluster.validation, length_clusterization)
            update_statistics(ref_value['valid_length'], value.length_validation_rank.validation, length_rank)
            update_statistics(ref_value['valid_rf'], value.reading_frame_validation.validation, reading_frame)
            update_statistics(ref_value['gene_merge'], value.gene_merge_validation.validation, gene_merge)
            update_statistics(ref_value['duplication'], value.duplication.validation, duplications)
            update_statistics(ref_value['main_orf'], value.orf.validation, main_orf)            

            it "should validate length by clusterization for #{key}" do
              assert_equal ref_value['valid_length'], value.length_validation_cluster.validation.to_s
            end

            it "should validate length by rank for #{key}" do
              assert_equal ref_value['valid_length'], value.length_validation_rank.validation.to_s
            end

            it "should validate reading frame from blast output for #{key}" do
              assert_equal ref_value['valid_rf'], value.reading_frame_validation.validation.to_s
            end

            it "should validate gene merge for #{key}" do
              assert_equal ref_value['gene_merge'], value.gene_merge_validation.validation.to_s
            end

            it "should validate sub-sequence duplication for #{key}" do
              assert_equal ref_value['duplication'], value.duplication.validation.to_s
            end

            it "should validate mai ORF for #{key}" do
              assert_equal ref_value['orf'], value.orf.validation.to_s
            end
            break
          end
        end
      end
    end

    puts "Statitics:"
    puts "Length validation by clusterization: 
          #{length_clusterization [:positives]} positives, 
          #{length_clusterization [:false_positives]} false positives, 
          #{length_clusterization [:false_negatives]} false negatives"

    puts "Length validation by rank: 
          #{length_rank [:positives]} positives, 
          #{length_rank [:false_positives]} false positives, 
          #{length_rank [:false_negatives]} false negatives"

    puts "Gene merge validation: 
          #{gene_merge [:positives]} positives, 
          #{gene_merge [:false_positives]} false positives, 
          #{gene_merge [:false_negatives]} false negatives"

    puts "Duplications validation: 
          #{duplications [:positives]} positives, 
          #{duplications [:false_positives]} false positives, 
          #{duplications [:false_negatives]} false negatives"

    puts "Reading frame validation: 
          #{reading_frame [:positives]} positives, 
          #{reading_frame [:false_positives]} false positives, 
          #{reading_frame [:false_negatives]} false negatives"

    puts "Main ORF validation: 
          #{main_orf [:positives]} positives, 
          #{main_orf [:false_positives]} false positives, 
          #{main_orf [:false_negatives]} false negatives"
  end
end  
