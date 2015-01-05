require 'genevalidator/sequences'
require 'genevalidator/exceptions'
require 'bio-blastxmlparser'
require 'net/http'
require 'open-uri'
require 'uri'
require 'io/console'
require 'yaml'

module GetRawSequences

  class <<self
    ##
    # Obtains raw_sequences from BLAST output file...
    def run(opt)
      @opt = opt
      
      if opt[:blast_xml_file]
        @blast_file  = opt[:blast_xml_file]
      else
        @blast_file = opt[:blast_tabular_file]
      end

      raw_seq_file = @blast_file + '.raw_seq' 
      index_file   = @blast_file + '.index'
      
      if opt[:db] =~ /remote/
        write_an_raw_seq_file(raw_seq_file, 'remote')
      else
        write_an_index_file(index_file, 'local')
        obtain_raw_seqs_from_local_db(index_file, raw_seq_file)
      end
      raw_seq_file
    end

    private

    def write_an_index_file(output_file ,db_type)
      file = File.open(output_file, 'w+')
      iterate_xml(file, db_type) if @blast_file == @opt[:blast_xml_file]
      iterate_tabular(file, db_type) if @blast_file == @opt[:blast_tabular_file]
    rescue IOError => e
      #some error occur, dir not writable etc. (ensures that file always closes)
    ensure
      file.close unless file.nil?
    end
    
    alias :write_an_raw_seq_file :write_an_index_file

    def iterate_xml(file, db_type)
      n = Bio::BlastXMLParser::XmlIterator.new(@opt[:blast_xml_file]).to_enum
      n.each do |iter|
        iter.each do | hit |
          if db_type == 'remote'
            file.puts obtain_raw_seqs_from_remote_db(hit.accession)
          else
            file.puts hit.hit_id
          end
        end
      end
    end

    def iterate_tabular(file, db_type)
      table_formats = @opt[:blast_tabular_options].split(/[ ,]/)
      assert_table_has_correct_no_of_collumns(table_formats)
      CSV.foreach(@opt[:blast_tabular_file], { :col_sep => "\t" }) do |row|
        next if row[0] =~ /^#/ # Skip commented lines
        if db_type == 'remote'
          accno_idx = table_formats.index("sacc")
          file.puts obtain_raw_seqs_from_remote_db(row[accno_idx])
        else
          hit_id_idx = table_formats.index("sseqid")
          file.puts row[hit_id_idx]
        end
      end
    end

    def obtain_raw_seqs_from_local_db(index_file, raw_seq_file)
      cmd = "blastdbcmd -entry_batch #{index_file} -db #{@opt[:db]} -outfmt" +
            " '%f' -out #{raw_seq_file}"
      %x[#{cmd}]
    end
    
    def obtain_raw_seqs_from_remote_db(accession)
      uri      = "http://www.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?" +
                 "db=protein&retmax=1&usehistory=y&term=#{accession}/"
      result   = Net::HTTP.get(URI.parse(uri))
      result2  = result
      queryKey = result2.scan(/<\bQueryKey\b>([\w\W\d]+)<\/\bQueryKey\b>/)[0][0]
      webEnv   = result.scan(/<\bWebEnv\b>([\w\W\d]+)<\/\bWebEnv\b>/)[0][0]

      uri      = "http://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?" +
                 "rettype=fasta&retmode=text&retstart=0&retmax=1&db=protein&" +
                 "query_key=#{queryKey}&WebEnv=#{webEnv}"
      result   = Net::HTTP.get(URI.parse(uri))
      raw_seqs = result[0..result.length-2]
      unless  raw_seqs.downcase.index(/error/) == nil
        raise Exception
      end
      raw_seqs
    end

    def assert_table_has_correct_no_of_collumns(table_formats)
      CSV.foreach(@opt[:blast_tabular_file], { :col_sep => "\t" }) do |row|
        next if row[0] =~ /^#/ # Skip commented lines
        unless row.length == table_formats.length
          puts '*** Error: The BLAST tabular file cannot be parsed. This is' +
               ' could possibly be due to an incorrect blast_tabular_options' +
               ' argument ("-o", "--blast_tabular_options") being supplied.' +
               ' Please correct this and try again.'
          exit 1
        end
        break # break after checking the first column
      end
    end
  end
end
