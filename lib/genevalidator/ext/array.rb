module GeneValidator
  # extention of the Array Class (i.e new methods for vectors)
  module ExtraArrayMethods
    def sum
      inject(0) { |accum, i| accum + i }
    end

    def mean
      sum / length.to_f
    end

    def median(already_sorted = false)
      sorted = already_sorted ? self : sort
      len    = sorted.length
      (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
    end

    def mode
      freq = each_with_object(Hash.new(0)) { |v, h| h[v] += 1; }
      max_by { |v| freq[v] }
    end

    def sample_variance
      m   = mean
      sum = inject(0) { |accum, i| accum + (i - m)**2 }
      sum / (length - 1).to_f
    end

    def standard_deviation
      Math.sqrt(sample_variance)
    end

    def all_quartiles
      return [self[0], self[0], self[0]] if length == 1

      sorted = sort
      len    = sorted.length
      split  = sorted.median_split
      [
        split[0].median(true),
        sorted.median(true),
        split[1].median(true)
      ]
    end

    def median_split
      len    = length
      center = len % 2
      [self[0..len / 2 - 1], self[len / 2 + center..-1]]
    end
  end
end

class Array
  include GeneValidator::ExtraArrayMethods

  def mean
    inject(:+).to_f / length
  end
end
