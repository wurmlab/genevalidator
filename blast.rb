#!/usr/bin/env ruby

require './clustering'
require './sequences'
require 'bio-blastxmlparser'
require 'net/http'
require 'open-uri'
require 'uri'
require 'gnuplot.rb'
require 'rinruby.rb'

class Blast

  # blast command: blastn or blastp
  attr_reader :command
  # result of executing command
  attr_reader :result
  #blast output
  attr_reader :xml_output
  #query sequence type
  attr_reader :type
  #query sequence fasta file
  attr_reader :fasta_file
  #predicted sequence
  #attr_reader :predicted_seq
  #array list with the reference sequences
  #attr_reader :ref_seq_list
  #array of clusters for clusterization by sequence length
  #attr_reader :clusters
  #attr_reader :most_dense_cluster_idx
  #Enumerator that iterates through the hits from the blast xml output
  attr_writer :blast_xml_iterator

  ################################
  def initialize(fasta_file, type)
    @type = type
    @fasta_file = fasta_file
    R.echo "enable = nil, stderr = nil" #redirect the cosole messages of R
    R.eval "x11()"  # othetwise I get SIGPIPE
  end

  #################################################
  #calls blast according to the type of the sequence
  def blast
    #call blast with the default parameters
    if type == 'protein'
      advanced_blast("blastp", @fasta_file, 11, 1)
    else
      advanced_blast("blastx", @fasta_file, 11, 1)
    end
  end

  ####################################
  #calls blast with specific parameters
  #return blast's xml output as a string
  def advanced_blast(command, filename, gapopen, gapextend)
    
    raise TypeError unless command.is_a? String and filename.is_a? String

    evalue = "1e-5"

    #blast output format:
    #0 = pairwise,
    #1 = query-anchored showing identities,
    #2 = query-anchored no identities,
    #3 = flat query-anchored, show identities,
    #4 = flat query-anchored, no identities,
    #5 = XML Blast output,
    #6 = tabular,
    #7 = tabular with comment lines,
    #8 = Text ASN.1,
    #9 = Binary ASN.1,
    #10 = Comma-separated values,
    #11 = BLAST archive format

    cmd = "#{command} -query #{filename} -db nr -remote -evalue #{evalue} -outfmt 5 -gapopen #{gapopen} -gapextend #{gapextend} "
    puts "Executing \"#{cmd}\"..."
    puts "This may take a while..."
    output = %x[#{cmd} 2>/dev/null]

    if output == ""
      $stderr.print "BLAST error. Did you add BLAST path to CLASSPATH?\n"
      exit
    end

    @xml_output = output
    output
  end

  ##########################################################################
  #parse the xml blast output given as string parameter (optional parameter)
  #initializes the class blast xml iterator
  def parse_output(output = nil)

    if output == nil
      output = @xml_output
    end

    xml = Bio::BlastXMLParser::NokogiriBlastXml.new(output).to_enum
    @blast_xml_iterator = xml

  end

  #####################################################
  #parse the next query from the blast xml output query
  #return an array of sequences
  def parse_next_query
  begin
    raise TypeError unless @blast_xml_iterator.is_a? Enumerator

    hits = Array.new
    predicted_seq = Sequence.new

    iter = @blast_xml_iterator.next

    puts "#################################################"
    puts "Parsing query #{iter.field('Iteration_iter-num')}"
    predicted_seq.xml_length = iter.field("Iteration_query-len").to_i

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

  ##################################################
  #clusterization by length from a list of sequences
  #input 1: lst = array of Sequence objects
  #input 2: predicted_seq = Sequence objetc
  #input 3: debug = true to display debug information, false by default (optional argument)
  #output 1: array of Cluster objects
  #output 2: the index of the most dense cluster
  def clusterization_by_length(lst, predicted_seq, debug = false)
  begin
    if lst == nil
      lst = @ref_seq_list
    end

    raise TypeError unless lst[0].is_a? Sequence and predicted_seq.is_a? Sequence

    contents = lst.map{ |x| x.xml_length.to_i }.sort{|a,b| a<=>b}

    clusters = hierarchical_clustering(contents, debug)
    max_density = 0;
    max_density_cluster_idx = 0;
    clusters.each_with_index do |item, i|
      if item.density > max_density
        max_density = item.density
        max_density_cluster_idx = i;
      end
    end

    @clusters = clusters;      

    puts "Predicted sequence length: #{predicted_seq.xml_length}"
    puts "Maximum sequence length: #{contents.max}"
    puts "Number of sequences: #{contents.length}"
    limits = clusters[max_density_cluster_idx].get_limits
    puts "Most dense custer interval [#{limits[0]},#{limits[1]}]"
    #clusters[max_density_cluster].print

    return [clusters, max_density_cluster_idx]

  rescue TypeError
    $stderr.print "Type error. Possible cause: one of the arguments of 'clusterization_by_length' method has not the proper type.\n"
    exit
  
  end
  end


  #############################################################################
  #plots a histogram of the length distribution given a list of Cluster objects
  #input 1: array of Cluster objects
  #input 2: length of the predicted sequence (number)
  #input 3: index from the clusters array of the most_dense_cluster_idx
  #input 4: name of the histogram file (optional argument, if missing the histogram will be displayed in a new window)
  def plot_histo_clusters(clusters, predicted_length, most_dense_cluster_idx, output)
  begin
    raise TypeError unless clusters[0].is_a? Cluster and predicted_length.is_a? Fixnum

    lengths = clusters.map{ |c| c.lengths.sort{|a,b| a[0]<=>b[0]}.map{ |x| a = Array.new(x[1],x[0])}.flatten}.flatten
    lengths.push(predicted_length)

    max_freq = clusters.map{ |x| x.lengths.map{|y| y[1]}.max}.max

    #make the plot in a new process
      R.eval "colors = c('orange', 'blue', 'yellow', 'green', 'gray')"

      unless output == nil
        puts "---- #{output}"
        #R.eval "dev.copy(png,'#{output}.png')"
        R.eval "jpeg('#{output}.jpg')"  
      end

      clusters.each_with_index do |cluster, i|
        cluster_lengths = cluster.lengths.sort{|a,b| a[0]<=>b[0]}.map{ |x| a = Array.new(x[1],x[0])}.flatten

        if i == most_dense_cluster_idx
          color = "'red'"
        else
          color = "colors[#{i%5+1}]"
	end

        R.eval "hist(c#{cluster_lengths.to_s.gsub('[','(').gsub(']',')')}, 
                breaks = seq(#{lengths.min-10}, #{lengths.max+10}, 0.1), 
                xlim=c(#{lengths.min-10},#{lengths.max+10}), 
                ylim=c(0,#{max_freq}), 
                col=#{color}, 
                border=#{color},
                main='Histogram for length distribution', xlab='length\nblack = predicted sequence, red = most dense cluster')"
        R.eval "par(new=T)"
      end
      
      R.eval "abline(v=#{predicted_length})" 

      unless output == nil
        R.eval "dev.off()"
      end

  rescue TypeError
    $stderr.print "Type error. Possible cause: one of the arguments of 'plot_histo_clusters' method has not the proper type.\n"
    exit

  end
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


