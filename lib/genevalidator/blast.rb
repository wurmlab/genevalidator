#!/usr/bin/env ruby

require 'genevalidator/clusterization'
require 'genevalidator/sequences'
require 'genevalidator/validation'
require 'genevalidator/output'
require 'bio-blastxmlparser'
require 'rinruby'
require 'net/http'
require 'open-uri'
require 'uri'
require 'io/console'
require 'yaml'

class ClasspathError < Exception
end

class SequenceTypeError < Exception
end

class Blast

  #query sequence type: can be :nucleotide or :protein
  attr_reader :type
  #query sequence fasta file
  attr_reader :fasta_file
  #current number of the querry processed
  attr_reader :idx
  #number of the sequence from the file to start with
  attr_reader :start_idx
  #output format
  attr_reader :outfmt
  #array of indexes for the start offsets of each query in the fasta file
  attr_reader :query_offset_lst

  def initialize(fasta_file, type, outfmt, xml_file, start_idx = 1)
    begin

      puts "\nDepending on your input and your computational resources, this may take a while. Please wait...\n\n"

      if type == "protein"
        @type = :protein
      else 
        @type = :nucleotide
      end

      @fasta_file = fasta_file
      @xml_file = xml_file
      @idx = 0
      @start_idx = start_idx
      @outfmt = outfmt

      fasta_content = IO.binread(@fasta_file);

      # type validation: the type of the sequence in the FASTA correspond to the one declared by the user
      if @type != type_of_sequences(fasta_content)
        raise SequenceTypeError.new
      end

      # create a list of index of the queries in the FASTA
      @query_offset_lst = fasta_content.enum_for(:scan, /(>[^>]+)/).map{ Regexp.last_match.begin(0)}
      @query_offset_lst.push(fasta_content.length)
      fasta_content = nil # free memory for variable fasta_content

      #redirect the cosole messages of R
      R.echo "enable = nil, stderr = nil"

      printf "No | Description | No_Hits | Valid_Length(Cluster) | Valid_Length(Rank) | Valid_Reading_Frame | Gene_Merge(slope) | Duplication | No_ORFs\n"

    rescue SequenceTypeError => error
      $stderr.print "Sequence Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: input file is not FASTA or the --type parameter is incorrect.\n"      
      exit
    end
  end

  ##
  # Calls blast according to the type of the sequence
  def blast
    begin

      if @xml_file == nil
 
        #file seek for each query
        @query_offset_lst[0..@query_offset_lst.length-2].each_with_index do |pos, i|
      
          if (i+1) >= @start_idx
            query = IO.binread(@fasta_file, @query_offset_lst[i+1] - @query_offset_lst[i], @query_offset_lst[i]);

            #call blast with the default parameters
            if type == :protein
              output = call_blast_from_stdin("blastp", query, 11, 1)
            else
              output = call_blast_from_stdin("blastx", query, 11, 1)
            end

            #save output in a file
            xml_file = "#{@fasta_file}_#{i+1}.xml"
            File.open(xml_file , "w") do |f| f.write(output) end

            #parse output
            parse_xml_output(output)   
          else
            @idx = @idx + 1
          end
        end
      else
        file = File.open(@xml_file, "rb").read
        parse_xml_output(file)      
      end

    rescue SystemCallError => error
      $stderr.print "Load error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: input file is not valid\n"      
      exit
    end
  end

  ##
  # Calls blast from standard input with specific parameters
  # Params:
  # +command+: blast command in String format (e.g 'blastx' or 'blastp')
  # +query+: String containing the the query in fasta format
  # +gapopen+: gapopen blast parameter
  # +gapextend+: gapextend blast parameter
  # Output:
  # String with the blast xml output
  def call_blast_from_stdin(command, query, gapopen, gapextend)
    begin
      raise TypeError unless command.is_a? String and query.is_a? String

      evalue = "1e-5"

      #output format = 5 (XML Blast output)
      blast_cmd = "#{command} -db nr -remote -evalue #{evalue} -outfmt 5 -gapopen #{gapopen} -gapextend #{gapextend}"
      cmd = "echo \"#{query}\" | #{blast_cmd}"
      #puts "Executing \"#{blast_cmd}\"... This may take a while..."
      output = %x[#{cmd} 2>/dev/null]

      if output == ""
        raise ClasspathError.new
      end

      return output

    rescue TypeError => error
      $stderr.print "Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: one of the arguments of 'call_blast_from_file' method has not the proper type\n"
      exit
    rescue ClasspathError => error
      $stderr.print "BLAST error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: Did you add BLAST path to CLASSPATH?\n" 
      exit 
    end
  end

  ##
  # Calls blast from file with specific parameters
  # Param:
  # +command+: blast command in String format (e.g 'blastx' or 'blastp')
  # +filename+: name of the FAST file
  # +query+: +String+ containing the the query in fasta format
  # +gapopen+: gapopen blast parameter
  # +gapextend+: gapextend blast parameter
  # Output:
  # String with the blast xml output
  def call_blast_from_file(command, filename, gapopen, gapextend)
    begin  
      raise TypeError unless command.is_a? String and filename.is_a? String

      evalue = "1e-5"

      #output = 5 (XML Blast output)
      cmd = "#{command} -query #{filename} -db nr -remote -evalue #{evalue} -outfmt 5 -gapopen #{gapopen} -gapextend #{gapextend} "
      puts "Executing \"#{cmd}\"..."
      puts "This may take a while..."
      output = %x[#{cmd}          if xml_file == nil
            file = File.open(xml_file, "rb").read
            b.parse_xml_output(file)
          end 2>/dev/null]

      if output == ""
        raise ClasspathError.new      
      end

      return output

    rescue TypeError => error
      $stderr.print "Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: one of the arguments of 'call_blast_from_file' method has not the proper type\n"      
      exit
    rescue ClasspathError =>error
      $stderr.print "BLAST error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Did you add BLAST path to CLASSPATH?\n"      
      exit
    end
  end

  ##
  # Parses the xml blast output 
  # Param:
  # +output+: +String+ with the blast output in xml format
  def parse_xml_output(output)

    iterator = Bio::BlastXMLParser::NokogiriBlastXml.new(output).to_enum

    begin
      @idx = @idx + 1      
      if @idx < @start_idx  
        iter = iterator.next 
      else     
        sequences = parse_next_query(iterator) #returns [hits, predicted_seq]
        if sequences == nil          
          @idx = @idx -1
          break
        end

        hits = sequences[0]
        prediction = sequences[1]
        # get the @idx-th sequence  from the fasta file
        i = @idx-1
       
        ### add exception
        query = IO.binread(@fasta_file, @query_offset_lst[i+1] - @query_offset_lst[i], @query_offset_lst[i])
        prediction.raw_sequence = query.scan(/[^\n]*\n([ATGCatgc\n]*)/)[0][0].gsub("\n","")      
        #file seek for each query
        
        # do validations

        v = Validation.new(hits, prediction, @type, @fasta_file, @idx, @start_idx)
        query_output = v.validate_all
        query_output.print_output_console

        if @outfmt == :html
          query_output.generate_html
        end

        #if @outfmt == :yaml
          query_output.print_output_file_yaml
        #end
      end

      rescue NoMethodError => error
        $stderr.print "NoMethod error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: input file is not in blast xml format.\n"        
        exit
      rescue StopIteration
        return
    end while 1

  end

  ##
  # Parses the next query from the blast xml output query
  # Params:
  # +iterator+: blast xml iterator for hits
  # Outputs:
  # output1: an array of +Sequence+ ojbects for hits
  # output2: +Sequence+ object for the predicted sequence
  def parse_next_query(iterator)
    begin
      raise TypeError unless iterator.is_a? Enumerator

      hits = Array.new
      predicted_seq = Sequence.new
      iter = iterator.next

      #puts "#################################################"
      #puts "Parsing query #{iter.field('Iteration_iter-num')}"

      # get info about the query
      predicted_seq.xml_length = iter.field("Iteration_query-len").to_i
      if @type == :nucleotide
        predicted_seq.xml_length /= 3
      end
      predicted_seq.definition = iter.field("Iteration_query-def")

      # parse blast the xml output and get the hits
      iter.each do | hit | 
        
        seq = Sequence.new

        seq.xml_length = hit.len.to_i        
        seq.object_type = "ref"
        seq.seq_type = @type
        seq.database = iter.field("BlastOutput_db")
        seq.id = hit.hit_id
        seq.definition = hit.hit_def
        seq.accession_no = hit.accession

        species_regex = hit.hit_def.scan(/\[([^\]\[]+)\]$/)
        if species_regex[0] == nil
          seq.species = "Unknown"
        else
          seq.species = species_regex[0][0]
        end

        #get gene by accession number
        if @type == :protein
          seq.raw_sequence = ""#get_sequence_by_accession_no(seq.accession_no, "protein")
        else
          seq.raw_sequence = ""#get_sequence_by_accession_no(seq.accession_no, "nucleotide")
        end
        seq.fasta_length = 0#seq.raw_sequence.length

        # get all high-scoring segment pairs (hsp)
        hsps = []
        hit.hsps.each do |hsp|
          current_hsp = Hsp.new
          current_hsp.bit_score = hsp.bit_score.to_i
          current_hsp.hsp_score = hsp.score.to_i
          current_hsp.hsp_evalue = hsp.evalue.to_i
          
          current_hsp.hit_from = hsp.hit_from.to_i
          current_hsp.hit_to = hsp.hit_to.to_i
          current_hsp.match_query_from = hsp.query_from.to_i
          current_hsp.match_query_to = hsp.query_to.to_i

          if @type == :nucleotide
            current_hsp.match_query_from /= 3 
            current_hsp.match_query_to /= 3             
          end


          current_hsp.query_reading_frame = hsp.query_frame.to_i

          current_hsp.hit_alignment = hsp.hseq.to_s
          current_hsp.query_alignment = hsp.qseq.to_s
          current_hsp.middles = hsp.midline.to_s

          current_hsp.identity = hsp.identity.to_i
          current_hsp.positive = hsp.positive.to_i
          current_hsp.gaps = hsp.gaps.to_i
          current_hsp.align_len = hsp.align_len.to_i

          hsps.push(current_hsp)
          #regex = current_hsp.hseq.gsub(/[+ -]/, '+' => '.', ' ' => '.', '-' => '')
          #seq.alignment_start_offset = seq.raw_sequence.index(/#{regex}/)
        end

        seq.hsp_list = hsps
        hits.push(seq)
        #puts "getting sequence #{seq.accession_no}..."
      end     
    
      return [hits, predicted_seq]

    rescue TypeError => error
      $stderr.print "Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: you didn't call 'parse_output' method first!\n"       
      exit
    rescue StopIteration
      nil
    end
  end

  ##
  # Gets gene by accession number from a givem database
  # Params:
  # +accno+: accession number as String
  # +db+: database as String
  # Output:
  # String with the nucleotide sequence corresponding to the accno
  def get_sequence_by_accession_no(accno,db)

    uri = "http://www.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=#{db}&retmax=1&usehistory=y&term=#{accno}/"
    puts uri
    result = Net::HTTP.get(URI.parse(uri))

    result2 = result
    queryKey = result2.scan(/<\bQueryKey\b>([\w\W\d]+)<\/\bQueryKey\b>/)[0][0]
    webEnv = result.scan(/<\bWebEnv\b>([\w\W\d]+)<\/\bWebEnv\b>/)[0][0]

    uri = "http://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?rettype=fasta&retmode=text&retstart=0&retmax=1&db=#{db}&query_key=#{queryKey}&WebEnv=#{webEnv}"

    result = Net::HTTP.get(URI.parse(uri))

    #parse FASTA output
    rec=result
    nl = rec.index("\n")
    header = rec[0..nl-1]
    seq = rec[nl+1..-1]
    seq.gsub!(/\n/,'')
  end
 
  ##
  # Copied from sequenceserver/sequencehelpers.rb
  # Params:
  # sequence_string: String of which we mfind the composition
  # Output:
  # a Hash
  def composition(sequence_string)
    count = Hash.new(0)
    sequence_string.scan(/./) do |x|
      count[x] += 1
    end
    count
  end

  ##
  # Strips all non-letter characters. guestimates sequence based on that.
  # If less than 10 useable characters... returns nil
  # If more than 90% ACGTU returns :nucleotide. else returns :protein
  # Params:
  # +sequence_string+: String to validate
  # Output:
  # nil, :nucleotide or :protein
  def guess_sequence_type(sequence_string)
    cleaned_sequence = sequence_string.gsub(/[^A-Z]/i, '') # removing non-letter characters
    cleaned_sequence.gsub!(/[NX]/i, '') # removing ambiguous characters

    return nil if cleaned_sequence.length < 10 # conservative

    composition = composition(cleaned_sequence)
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
  # Splits input at putative fasta definition lines (like ">adsfadsf"), guesses sequence type for each sequence.
  # If not enough sequence to determine, returns nil.
  # If 2 kinds of sequence mixed together, raises ArgumentError
  # Otherwise, returns :nucleotide or :protein
  # Params:
  # +sequence_string+: String to validate
  # Output:
  # nil, :nucleotide or :protein
  def type_of_sequences(fasta_format_string)
    # the first sequence does not need to have a fasta definition line
    sequences = fasta_format_string.split(/^>.*$/).delete_if { |seq| seq.empty? }

    # get all sequence types
    sequence_types = sequences.collect { |seq| guess_sequence_type(seq) }.uniq.compact

    return nil if sequence_types.empty?

    if sequence_types.length == 1
      return sequence_types.first # there is only one (but yes its an array)
    else
      raise ArgumentError, "Insufficient info to determine sequence type. Cleaned queries are: #{ sequences.to_s }"
    end
  end

end


