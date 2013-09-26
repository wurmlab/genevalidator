require 'genevalidator/blast'
require 'genevalidator/exceptions'

class Hsp

  attr_accessor :hit_from #references from the unaligned hit sequence
  attr_accessor :hit_to
  attr_accessor :match_query_from # references from the unaligned query sequence
  attr_accessor :match_query_to
  attr_accessor :query_reading_frame
  attr_accessor :hit_alignment
  attr_accessor :query_alignment
  attr_accessor :middles # conserved residues are with letters, positive (mis)matches with +, mismatches and gaps are with space

  attr_accessor :bit_score
  attr_accessor :hsp_score
  attr_accessor :hsp_evalue
  attr_accessor :identity # number of conserved residues
  attr_accessor :pidentity # percentage of identical matches
  attr_accessor :positive # positive score for the (mis)match
  attr_accessor :gaps
  attr_accessor :align_len

  def initialize
    query_alignment = nil
    hit_alignment = nil
  end

  ##
  # Initializes the corresponding attribute of the hsp
  # with respect to the column name of the tabular blast output
  def init_tabular_attribute(column, value, type=:protein)
    case column
      when "qstart"
        if type == :nucleotide
          @match_query_from = (value.to_i/3)+1
        else
          @match_query_from = value.to_i
        end
      when "qend"
        if type == :nucleotide
          @match_query_to = (value.to_i/3) + 1
        else
          @match_query_to = value.to_i
        end
      when "qframe"
        @query_reading_frame = value.to_i
      when "sstart"
        @hit_from = value.to_i
      when "send"
        @hit_to = value.to_i
      when "qseq"
        @query_alignment = value
        seq_type = BlastUtils.guess_sequence_type(value)
        if seq_type != nil and seq_type != :protein
          raise SequenceTypeError
        end
      when "sseq"
        @hit_alignment = value
        seq_type = BlastUtils.guess_sequence_type(value)
        if seq_type != nil and seq_type != :protein
          raise SequenceTypeError
        end
      when "length"
        @align_len = value.to_i
      when "pident"
        @pidentity = value.to_f
      when "evalue"
        @hsp_evalue = value.to_f
    end
  end
end
