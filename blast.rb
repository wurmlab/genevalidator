#!/usr/bin/env ruby

require './clustering'
require './sequences'
require './blastQuery'
require 'bio-blastxmlparser'
require 'net/http'
require 'open-uri'
require 'uri'
require 'io/console'

class ClasspathError < Exception
end

class Blast

  #query sequence type
  attr_reader :type
  #query sequence fasta file
  attr_reader :fasta_file
  #Enumerator that iterates through the hits from the blast xml output
  attr_reader :blast_xml_iterator
  #current number of the querry processed
  attr_reader :idx
  #number of the sequence from the file to start with
  attr_reader :start_idx

  ################################
  def initialize(fasta_file, type, start_idx=0)
    @type = type
    @fasta_file = fasta_file
    @idx = 0
    @start_idx = start_idx
    R.echo "enable = nil, stderr = nil" #redirect the cosole messages of R
    #R.eval "x11()"  # othetwise I get SIGPIPE

    puts "\nDepending on your input and your computational resources, this may take a while. Please wait...\n\n"
    printf "%5s | %20s | %50s | %20s | %20s\n","Query", "Query Name", "Length Validation", "Reading Frame Validation", "Gene Merge Validation"

  end

  #################################################
  #calls blast according to the type of the sequence
  def blast

    fasta_content = IO.binread(@fasta_file);
    positions = fasta_content.enum_for(:scan, /(>[^>]+)/).map{ Regexp.last_match.begin(0)}
    positions.push(fasta_content.length)
    fasta_content = nil # free memory of variable fasta_content

    #file seek for each query
    positions[0..positions.length-2].each_with_index do |pos, i|
      
      if (i+1) >= @start_idx
        query = IO.binread(@fasta_file, positions[i+1] - positions[i], positions[i]);
        #puts query

        #call blast with the default parameters
        if type == 'protein'
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
  end

  ####################################
  #call blast from standard input with specific parameters
  #return blast's xml output as a string
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

    rescue TypeError
      $stderr.print "Type error. Possible cause: one of the arguments of 'call_blast_from_file' method has not the proper type\n"
      exit
    rescue ClasspathError
      $stderr.print "BLAST error. Possible cause: Did you add BLAST path to CLASSPATH?\n" 
      exit 
    end
  end


  ####################################
  #call blast from file with specific parameters
  #return blast's xml output as a string
  def call_blast_from_file(command, filename, gapopen, gapextend)
    begin  
      raise TypeError unless command.is_a? String and filename.is_a? String

      evalue = "1e-5"

      #output = 5 (XML Blast output)
      cmd = "#{command} -query #{filename} -db nr -remote -evalue #{evalue} -outfmt 5 -gapopen #{gapopen} -gapextend #{gapextend} "
      puts "Executing \"#{cmd}\"..."
      puts "This may take a while..."
      output = %x[#{cmd} 2>/dev/null]

      if output == ""
        raise ClasspathError.new      
      end

      return output

    rescue TypeError
      $stderr.print "Type error. Possible cause: one of the arguments of 'call_blast_from_file' method has not the proper type\n"
      exit
    rescue ClasspathError
      $stderr.print "BLAST error. Did you add BLAST path to CLASSPATH?\n"
      exit
    end
  end

  ##########################################################################
  #parse the xml blast output given as string parameter (optional parameter)
  #initializes the class blast xml iterator
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

        query = BlastQuery.new(hits, prediction,"#{@fasta_file}_#{@idx}", @idx)
        rez_lv = query.length_validation
        rez_rfv = query.reading_frame_validation
        rez_merge = query.gene_merge_validation
        printf "%5d |\'%-20s\'| %50s | %20s | %20s|\n",
              @idx,
              prediction.definition[0, [prediction.definition.length-1,20].min],
              rez_lv, rez_rfv, rez_merge
      end

      rescue QueryError
        $stderr.print "Type error. Possible cause: blast did not find any relevant output for this query.\n"
      rescue StopIteration
        #@idx = @idx - 1
        return
    end while 1

  end

  #####################################################
  #parse the next query from the blast xml output query
  #output1: an array of Sequence hits
  #output2: Sequence object for the predicted sequence
  def parse_next_query(iterator)
    begin
      raise TypeError unless iterator.is_a? Enumerator

      hits = Array.new
      predicted_seq = Sequence.new
      iter = iterator.next

      #puts "#################################################"
      #puts "Parsing query #{iter.field('Iteration_iter-num')}"
      predicted_seq.xml_length = iter.field("Iteration_query-len").to_i
      predicted_seq.definition = iter.field("Iteration_query-def")

      iter.each do | hit |
 
        hsp = hit.hsps.first
        hsp.field("Hsp_bit-score")
        seq = Sequence.new

        seq.object_type = "ref"
        seq.seq_type = @type
        seq.database = iter.field("BlastOutput_db")
        seq.id = hit.hit_id
  
        seq.definition = hit.hit_def
      
        species_regex = hit.hit_def.scan(/\[([^\]\[]+)\]$/)
        if species_regex[0] == nil
          seq.species = "Unknown" 
        else
    	  seq.species = species_regex[0][0]
        end
	    
        seq.accession_no = hit.accession
        seq.e_value = hsp.evalue
      
        seq.xml_length = hit.len.to_i
        seq.hit_from = hsp.hit_from.to_i
        seq.hit_to = hsp.hit_to.to_i

        seq.match_query_from = hsp.query_from.to_i
        seq.match_query_to = hsp.query_to.to_i

        seq.query_reading_frame = hsp.query_frame.to_i

        #get gene by accession number
        if @type == "protein"
          seq.raw_sequence = ""#get_sequence_by_accession_no(seq.accession_no, "protein")
        else
          seq.raw_sequence = ""#get_sequence_by_accession_no(seq.accession_no, "nucleotide")
        end
        seq.fasta_length = 0#seq.raw_sequence.length

        align = Alignment.new
        align.query_seq = hsp.qseq
        align.hit_seq = hsp.hseq
        align.bit_score = hsp.bit_score
        align.score = hsp.score

        regex = align.hit_seq.gsub(/[+ -]/, '+' => '.', ' ' => '.', '-' => '')
        #puts "----\n#{regex}\n----"

        #seq.alignment_start_offset = seq.raw_sequence.index(/#{regex}/)
        seq.alignment = align

        hits.push(seq)
        #seq.print
        #puts "getting sequence #{seq.accession_no}..."
      end     
    
      #@ref_seq_list = hits	
      return [hits, predicted_seq]

    rescue TypeError 
      $stderr.print "Type error. Possible cause: you didn't call 'parse_output' method first!\n" 
      exit
    rescue StopIteration
      nil
    end
  end

  ###################################################
  #get gene by accession number from a givem database
  #input 1: accno = accession number (string)
  #input 2: db = database (string)
  #output: the nucleotide sequence corresponding to the accno
  def get_sequence_by_accession_no(accno,db)

    uri = "http://www.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=#{db}&retmax=1&usehistory=y&term=#{accno}/"
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

    seq

  end

end

##########
#Main body
#Test certain methods of Blast class

=begin
b = Blast.new("ana","protein")
puts b.get_sequence_by_accession_no("EF100000","nucleotide")
file = File.open("/home/monique/GSoC2013/data/output_prot1_predicted.xml", "rb").read
b.parse_output(file)
=end


