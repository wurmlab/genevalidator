require 'genevalidator/sequences'
require 'genevalidator/exceptions'
require 'genevalidator/tabular_parser'
require 'bio-blastxmlparser'
require 'net/http'
require 'open-uri'
require 'uri'
require 'io/console'
require 'yaml'

module Get_raw_sequences

  ##
  # Obtains raw_sequences from BLAST XML file...
  def self.run(raw_seq_file, db, blast_out_file, blast_tabular_options = nil)
    puts "Obtaining raw sequences from BLAST database..."
    index_file = "#{raw_seq_file}.index"
    if blast_tabular_options
      write_an_index_file_from_tabular(index_file, blast_out_file, blast_tabular_options)
    else
      write_an_index_file_from_xml(index_file, blast_out_file)
    end
    cmd = "blastdbcmd -entry_batch #{index_file} -db #{db} -outfmt '%f' -out #{raw_seq_file}"
    %x[#{cmd}]
  end

  private

  def self.write_an_index_file_from_xml(index_file, blast_xml_file)
    n = Bio::BlastXMLParser::XmlIterator.new(blast_xml_file).to_enum
    file = File.open(index_file, 'w+')
    n.each do |iter|
      iter.each do | hit |
        file.puts hit.hit_id
      end
    end
  rescue IOError => e
    #some error occur, dir not writable etc. (ensures that file always closes)
  ensure
    file.close unless file == nil
  end

  def self.write_an_index_file_from_tabular(index_file, blast_tabular_file, format)
    table_formats = format.split(/[ ,]/)
    hit_id_idx    = table_formats.index("sseqid")
    assert_table_has_correct_no_of_collumns(blast_tabular_file, table_formats)
    file = File.open(index_file, 'w+')
    CSV.foreach(blast_tabular_file, { :col_sep => "\t" }) do |row|
      file.puts "#{row[hit_id_idx]}"
    end
  rescue IOError => e
    #some error occur, dir not writable etc. (ensures that file always closes)
  ensure
    file.close unless file == nil 
  end

  def self.assert_table_has_correct_no_of_collumns(blast_tabular_file, table_formats)
    CSV.foreach(blast_tabular_file, { :col_sep => "\t" }) do |row|
      unless row.length == table_formats.length
        puts '*** Error: The BLAST tabular file cannot be parsed. This is' +
             ' could possibly be due to an incorrect blast_tabular_options' +
             ' argument ("-o", "--blast_tabular_options") being supplied.' +
             ' Please correct this and try again.'
        exit 1
      end
      break
    end
  end
end
