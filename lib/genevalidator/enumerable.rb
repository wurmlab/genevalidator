  # module GeneValidator
  # extention of the enumerable module (i.e new methods fo vectors)
  module Enumerable
    def sum
      inject(0) { |accum, i| accum + i }
    end

    def mean
      sum / length.to_f
    end

    def median
      sorted = sort
      len    = sorted.length
      (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
    end

    def mode
      freq = inject(Hash.new(0)) { |h, v| h[v] += 1; h }
      sort_by { |v| freq[v] }.last
    end

    def sample_variance
      m   = mean
      sum = inject(0) { |accum, i| accum + (i - m)**2 }
      sum / (length - 1).to_f
    end

    def standard_deviation
      Math.sqrt(sample_variance)
    end
  end
  # end

  # module Enumerable
  #   include GeneValidator::Enumerable
  # end
# end