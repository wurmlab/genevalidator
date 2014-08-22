require 'genevalidator/enumerable'

class TestEnumerable < Minitest::Test

  include Enumerable

  describe "Enumerable Module" do

    it "test1 " do

      v = [1, 2, 3, 4, 5, 6]
      assert_equal v.mean, 3.5
      assert_equal v.median, 3.5
      assert_equal v.standard_deviation.round(6), 1.870829

    end
  end
end
