require 'optparse'
require 'genevalidator/clusterization'
require 'genevalidator/blast'
require 'genevalidator/sequences'

# Argument validation

options = {}
opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: TYPE [SKIP_BLAST] [START] [OUTFMT] FILE"
  opt.separator  ""
  opt.separator  "File: filename of the FASTA file containing the predicted sequences"
  opt.separator  ""
  opt.separator  "Options"

  opt.on("-t","--type TYPE","type of the predicted sequences: protein/mRNA") do |type|
    if type.to_s.downcase == 'protein' or type.to_s.downcase == 'mrna'
      options[:type] = type
    else 
      $stderr.print "Error: type must be protein or mRNA." + "\n"
      exit
    end
  end

  opt.on("-s","--start [START]", Integer, "starts the validation with a certain sequence in the input file ") do |start|
    if start.is_a? Fixnum
      options[:start] = start     
    else 
      $stderr.print "Error: start must be a natural number." + "\n"
    end
  end

  opt.on("-o","--outfmt [OUTFMT]", "output format ") do |outfmt|
    if outfmt == "html"
      options[:outfmt] = :html    
    else 
      if outfmt == "yaml"
        options[:outfmt] = :yaml
      else
        options[:outfmt] = :console
      end
    end    
  end

  opt.on("-x", "--skip_blast [FILENAME]","skip blast-ing part and provide a blast xml output as input to this script") do |skip|
    options[:skip_blast] = skip
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

  unless options[:skip_blast]
    options[:skip_blast] = nil
  end

  unless ARGV.length == 1
    $stderr.puts "Error: you must specify a single fasta input file instead of #{ARGV.length}." + "\n"
    exit
  end 

  rescue OptionParser::ParseError
    $stderr.print "Error: " + $! + "\n"
    exit
end


# Main body

puts "!!#{options[:skip_blast]}??"
puts "ana are mere"

if options[:start]
  b = Blast.new(ARGV[0], options[:type].to_s.downcase, options[:skip_blast], options[:outfmt], options[:start])
else
  b = Blast.new(ARGV[0], options[:type].to_s.downcase, options[:skip_blast], options[:outfmt])
end

b.blast


