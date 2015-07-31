#!/usr/bin/env ruby

def install_from_source
  system 'rake install'
end

def test_with(fa, db)
  # Only FASTA.
  run "rm -r #{fa}.html",
      "genevalidator -d #{db} #{fa}"

  # With BLAST XML.
  run "rm -r #{fa}.html",
      "genevalidator -d #{db} #{fa} -x #{fa}.blast_xml"

  # With BLAST TSV.
  run "rm -r #{fa}.html",
      "genevalidator -d #{db} #{fa} -x #{fa}.blast_tabular"

  # With BLAST XML and hit sequences.
  run "rm -r #{fa}.html",
      "genevalidator -d #{db} #{fa} -x #{fa}.blast_xml -r #{fa}.blast_xml.raw_seq"

  # With BLAST TSV and hit sequences.
  run "rm -r #{fa}.html",
      "genevalidator -d #{db} #{fa} -x #{fa}.blast_tabular -r #{fa}.blast_tabular.raw_seq"


  # Retrieving hit sequences given BLAST XML.
  run "genevalidator -d #{db} -e #{fa}.blast_xml"

  # Retrieving hit sequences given BLAST TSV.
  run "genevalidator -d #{db} -e #{fa}.blast_tabular"
end

def run(*cmds)
  puts "Will run:"
  puts cmds.join("\n")
  print "Proceed? [Y/n/q]: "

  input = gets.chomp.downcase
  input = 'y' if input.empty?

  case input
  when 'y'; cmds.each { |cmd| system(cmd) or exit }
  when 'n'; return
  when 'q'; exit
  else
    puts "\nInvalid input.\n"
    run(*cmds)
  end
end

db = ENV['db'] || 'swissprot -remote'
%w(data/protein_data.fasta data/mrna_data.fasta).each { |fa| test_with fa, db }
