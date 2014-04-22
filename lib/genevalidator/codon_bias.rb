class CodonBias

  attr_accessor :aa_short_code
  attr_accessor :aa_code
  attr_accessor :aa_name
  attr_accessor :codons # array of possible codons
  attr_accessor :bias

  def initialize(aa_short_code, aa_code, aa_name, codons)
    @aa_short_code = aa_short_code.upcase
    @aa_code = aa_code.upcase
    @aa_name = aa_name.capitalize
    @codons = codons.map{|codon| codon.upcase}
    @bias = {}
  end

  def add_amino_acid(codon)
    if codons.include?(codon)
      bias[codon.upcase] = bias[codon.upcase] + 1
    end
  end

  def get_percentage(codon)
    unless codons.include?(codon)
      return nil
    end

    total_count = 0
    codons.each do |codon|
      total_count = total_count + bias[codon]
    end
    return bias[codon] / (total_count + 0.0)
  end

end
