require "rubygems"
require "test/unit"
require "shoulda"
require "yaml"
require 'genevalidator/clusterization'
require 'genevalidator/output'

class ValidateOutput < Test::Unit::TestCase

  context "Validate Output" do

    yml = YAML.load_file 'test_reference.yml'
    yml.each_pair { |key, value|
      puts "#{key} = #{value}"
    }

    should "make clusterization " do
      hc = HierarchicalClusterization.new(vec)
      assert_equal 2, hc.hierarchical_clusterization(2, 1, vec).length
    end

  end
end
