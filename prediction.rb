require 'optparse'
require 'clustering.rb'

# Argument validation

options = {}
opt_parser = OptionParser.new do |opt|
	opt.banner = "Usage: TYPE [SKIP_BLAST] FILE"
	opt.separator  ""
	opt.separator  "File: filename of the FASTA file containing the predicted sequences"
	opt.separator  ""
	opt.separator  "Options"

	opt.on("-t","--type TYPE","type of the predicted sequences: protein/mRNA") do |type|
		if type.to_s.downcase == 'protein' or type.to_s.downcase == 'mrna'
			options[:type] = type
    		else 
       			$stderr.print "Error: type may be protein or mRNA." + "\n"
       			exit
    		end
	end

        opt.on("-skip_blast","--skip_blast","skip blast-ing part and provide a blast xml output as input to this script") do
                options[:skip_blast] = true
	end

	opt.on("-h","--help","help") do
		puts opt_parser
	end

end
begin
	opt_parser.parse!(ARGV)
	unless options[:type]
    		$stderr.puts "Error: you must specify --type option." + "\n"
  		exit
	end 
	unless ARGV.length == 1
		$stderr.puts "Error: you must specify a single input file." + "\n"
		exit
	end 
rescue OptionParser::ParseError
	$stderr.print "Error: " + $! + "\n"
	exit
end

class Blast

    ERROR_LINE = /\(CArgException.*\)\s(.*)/

    # command string to be executed
    attr_reader :command

    # result of executing command
    attr_reader :result

    # errors as [status, message]
    attr_reader :error

    def initialize
      @method = ""#method
      @databases = ""#databases
    end

    def blast(command, filename, gapopen, gapextend)
        # we don't know what to do if the arguments ain't String
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
	output = %x[#{cmd} 2>/dev/null]
	output2 = output

	contents = output.scan(/<\bHit_len\b>(\d+)<\/\bHit_len\b>/)
	contents = contents.map{ |x| x[0].to_i }.sort{|a,b| a<=>b}

	query_len = output2.scan(/<\bIteration_query-len\b>(\d+)<\/\bIteration_query-len\b>/)

	clusters = hierarchical_clustering(contents)
	max_density = 0;
	max_density_cluster = 0;
	clusters.each_with_index{|item, i|
        	if item.density > max_density
                	max_density = item.density
	                max_density_cluster = i;
        	end
	}

	puts "Predicted sequence length: #{query_len}"
	puts "Maximum sequence length: #{contents.max}"
	puts "Number of sequences: #{contents.length}"
	puts "\nMost dense cluster:"

	clusters[max_density_cluster].print_cluster

    end
end

# Main body

unless options[:skip_blast]

	b = Blast.new
	if options[:type].to_s.downcase == 'protein'
		puts "This is a protein"
		b.blast("blastp", ARGV[0],11,1)
	else 
		puts "This is a transcript"
		b.blast("blastn", ARGV[0],5,2)
	end
	exit
end


# Skip the blast-ing part and provide a xml blast output file as argument to this ruby script

file = File.open(ARGV[0], "rb")

contents = file.read.scan(/<\bHit_len\b>(\d+)<\/\bHit_len\b>/)
contents = contents.map{ |x| x[0].to_i }.sort{|a,b| a<=>b}
 
clusters = hierarchical_clustering(contents)
max_density = 0;
max_density_cluster = 0;
clusters.each_with_index{|item, i|
        if item.density > max_density
                max_density = item.density
                max_density_cluster = i;
        end
}

file = File.open(ARGV[0], "rb")
query_len = file.read.scan(/<\bIteration_query-len\b>(\d+)<\/\bIteration_query-len\b>/)

puts "Predicted sequence length: #{query_len}"
puts "Maximum sequence length: #{contents.max}"
puts "Number of sequences: #{contents.length}"
puts "\nMost dense cluster:"
clusters[max_density_cluster].print_cluster



