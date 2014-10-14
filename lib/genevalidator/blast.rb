#!/usr/bin/env ruby

require 'genevalidator/sequences'
require 'genevalidator/hsp'
require 'genevalidator/output'
require 'genevalidator/exceptions'
require 'bio-blastxmlparser'
require 'net/http'
require 'open-uri'
require 'uri'
require 'io/console'
require 'yaml'

class BlastUtils

  ##
  # Calls blast from standard input with specific parameters
  # Params:
  # +command+: blast command in String format (e.g 'blastx' or 'blastp')
  # +query+: String containing the the query in fasta format
  # +gapopen+: gapopen blast parameter
  # +gapextend+: gapextend blast parameter
  # +db+: database
  # +nr_hits+: max number of hits
  # Output:
  # String with the blast xml output
  def self.call_blast_from_stdin(blastpath, blast_type, query, db, gapopen=11, gapextend=1, nr_hits=200)
    begin
      if blastpath == nil 
        command = blast_type
      else
        command = File.join(blastpath, blast_type)
      end
      raise TypeError unless command.is_a? String and query.is_a? String

      evalue = "1e-5"
      
      #output format = 5 (XML Blast output)
      blast_cmd = "#{command} -db #{db} -evalue #{evalue} -outfmt 5 -max_target_seqs #{nr_hits} -gapopen #{gapopen} -gapextend #{gapextend}"
      cmd       = "echo \"#{query}\" | #{blast_cmd}"
      output    = %x[#{cmd} 2>/dev/null]

      if output == ""
        raise ClasspathError.new
      end

      return output

    rescue TypeError => error
      $stderr.print "Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. "<<
        "Possible cause: one of the arguments of 'call_blast_from_stdin' method has not the proper type\n"
      exit!
    rescue ClasspathError => error
      $stderr.print "BLAST error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. "<<
        "Possible cause: BLAST installation path is not in the LOAD PATH or BLAST database is not accessible.\n" 
      exit! 
    end
  end

  # NOTE: The below method isn't currently being used...

  ##
  # Calls blast from file with specific parameters
  # Param:
  # +command+: blast command in String format (e.g 'blastx' or 'blastp')
  # +filename+: name of the FAST file
  # +query+: +String+ containing the the query in fasta format
  # +gapopen+: gapopen blast parameter
  # +gapextend+: gapextend blast parameter
  # +db+: database
  # Output:
  # String with the blast xml output
  def self.call_blast_from_file(command, filename, gapopen, gapextend, db="nr -remote")
    begin  
      raise TypeError unless command.is_a? String and filename.is_a? String

      evalue = "1e-5"

      #output = 5 (XML Blast output)
      cmd = "#{command} -query #{filename} -db #{db} -evalue #{evalue} -outfmt 5 -gapopen #{gapopen} -gapextend #{gapextend} "
      puts "Executing \"#{cmd}\"..."
      puts "This may take a while..."
      output = %x[#{cmd}          if xml_file == nil
            file = File.open(xml_file, "rb").read
            b.parse_xml_output(file)
          end 2>/dev/null]

      if output.empty?
        raise ClasspathError.new      
      end

      return output

    rescue TypeError => error
      $stderr.print "Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. "<<
        "Possible cause: one of the arguments of 'call_blast_from_file' method has not the proper type\n"      
      exit
    rescue ClasspathError =>error
      $stderr.print "BLAST error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. "<<
        "Did you add BLAST path to LOADPATH?\n"      
      exit
    end
  end

  ##
  # Parses the next query from the blast xml output query
  # Params:
  # +iterator+: blast xml iterator for hits
  # +type+: the type of the sequence: :nucleotide or :protein
  # Outputs:
  # Array of +Sequence+ objects corresponding to the list of hits
  def self.parse_next_query_xml(iterator, type)
    begin
      raise TypeError unless iterator.is_a? Enumerator

      hits = Array.new
      predicted_seq = Sequence.new
      iter = iterator.next

      # parse blast the xml output and get the hits
      # hits obtained are proteins! (we use only blastp and blastx)
      iter.each do | hit | 
        
        seq = Sequence.new

        seq.length_protein = hit.len.to_i        
        seq.type           = :protein
        seq.identifier     = hit.hit_id
        seq.definition     = hit.hit_def
        #puts seq.identifier
        seq.accession_no = hit.accession

        # get all high-scoring segment pairs (hsp)
        hsps = []

        hit.hsps.each do |hsp|
          current_hsp            = Hsp.new
          current_hsp.hsp_evalue = hsp.evalue.to_i
          
          current_hsp.hit_from         = hsp.hit_from.to_i
          current_hsp.hit_to           = hsp.hit_to.to_i
          current_hsp.match_query_from = hsp.query_from.to_i
          current_hsp.match_query_to   = hsp.query_to.to_i

          if type == :nucleotide
            current_hsp.match_query_from =  (current_hsp.match_query_from / 3) + 1 
            current_hsp.match_query_to   =  (current_hsp.match_query_to / 3) + 1             
          end

          current_hsp.query_reading_frame = hsp.query_frame.to_i

          current_hsp.hit_alignment = hsp.hseq.to_s
          if BlastUtils.guess_sequence_type(current_hsp.hit_alignment) != :protein
            raise SequenceTypeError
          end

          current_hsp.query_alignment = hsp.qseq.to_s
          if BlastUtils.guess_sequence_type(current_hsp.query_alignment) != :protein
            raise SequenceTypeError
          end
          current_hsp.align_len = hsp.align_len.to_i
          current_hsp.identity  = hsp.identity.to_i          
          current_hsp.pidentity = 100 * hsp.identity / (hsp.align_len + 0.0)  

          hsps.push(current_hsp)
        end

        seq.hsp_list = hsps
        hits.push(seq)
      end     
    
      return hits

    rescue TypeError => error
      $stderr.print "Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. "<<
        "Possible cause: you didn't call parse method first!\n"       
      exit!
    rescue SequenceTypeError => error
      $stderr.print "Sequence Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. "<<
        "Possible cause: the blast output was not obtained against a protein database.\n"
      exit!
    rescue StopIteration
      nil
    end
  end

  ##
  # Method copied from sequenceserver/sequencehelpers.rb
  # Params:
  # sequence_string: String of which we mfind the composition
  # Output:
  # a Hash
  def self.composition(sequence_string)
    count = Hash.new(0)
    sequence_string.scan(/./) do |x|
      count[x] += 1
    end
    count
  end

  ##
  # Method copied from sequenceserver/sequencehelpers.rb
  # Strips all non-letter characters. guestimates sequence based on that.
  # If less than 10 useable characters... returns nil
  # If more than 90% ACGTU returns :nucleotide. else returns :protein
  # Params:
  # +sequence_string+: String to validate
  # Output:
  # nil, :nucleotide or :protein
  def self.guess_sequence_type(sequence_string)
    cleaned_sequence = sequence_string.gsub(/[^A-Z]/i, '') # removing non-letter characters
    cleaned_sequence.gsub!(/[NX]/i, '') # removing ambiguous characters

    return nil if cleaned_sequence.length < 10 # conservative

    composition = BlastUtils.composition(cleaned_sequence)
    composition_NAs = composition.select { |character, count|character.match(/[ACGTU]/i) } # only putative NAs
    putative_NA_counts = composition_NAs.collect { |key_value_array| key_value_array[1] } # only count, not char
    putative_NA_sum = putative_NA_counts.inject { |sum, n| sum + n } # count of all putative NA
    putative_NA_sum = 0 if putative_NA_sum.nil?


    if putative_NA_sum > (0.9 * cleaned_sequence.length)
      return :nucleotide
    else
      return :protein
    end
  end

  ##
  # Method copied from sequenceserver/sequencehelpers.rb
  # Splits input at putative fasta definition lines (like ">adsfadsf"), guesses sequence type for each sequence.
  # If not enough sequence to determine, returns nil.
  # If 2 kinds of sequence mixed together, raises ArgumentError
  # Otherwise, returns :nucleotide or :protein
  # Params:
  # +sequence_string+: String to validate
  # Output:
  # nil, :nucleotide or :protein
  def self.type_of_sequences(fasta_format_string)
    # the first sequence does not need to have a fasta definition line
    sequences = fasta_format_string.split(/^>.*$/).delete_if { |seq| seq.empty? }

    # get all sequence types
    sequence_types = sequences.collect { |seq| BlastUtils.guess_sequence_type(seq) }.uniq.compact

    return nil if sequence_types.empty?

    if sequence_types.length == 1
      return sequence_types.first # there is only one (but yes its an array)
    else
      raise SequenceTypeError
    end
  end

end


