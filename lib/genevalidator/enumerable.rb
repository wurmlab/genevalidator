
# extention of the enumerable module (i.e new methods fo vectors)
module Enumerable

  def sum
    self.inject(0){|accum, i| accum + i }
  end

  def mean
    self.sum / self.length.to_f
  end

  def median
    sorted = self.sort
    len    = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end

  def mode
    freq = self.inject(Hash.new(0)) { |h,v| h[v] += 1; h }
    self.sort_by { |v| freq[v] }.last
  end

  def sample_variance
    m   = self.mean
    sum = self.inject(0){|accum, i| accum + (i - m) ** 2 }
    sum / (self.length - 1).to_f
  end

  def standard_deviation
    Math.sqrt(self.sample_variance)
  end

end

class Numeric
  def to_scientific_notation
    self.to_s.sub(/(\d*\.\d*)e?([+-]\d*)?/) do
      s = '%.3f' % Regexp.last_match[1]
      s << " x 10<sup>#{Regexp.last_match[2]}</sup>" if Regexp.last_match[2]
      s
    end
  end
end

