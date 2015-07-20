require 'bio'
require 'bio-blastxmlparser'
require 'forwardable'

require 'genevalidator/exceptions'
require 'genevalidator/hsp'
require 'genevalidator/sequences'
require 'genevalidator/output'

module GeneValidator
  # Contains methods that run BLAST and methods that analyse sequences
  class BlastUtils
    class << self
      extend Forwardable
      def_delegators GeneValidator, :opt, :config

      EVALUE = 1e-5

      ##
      # Calls blast from standard input with specific parameters
      # Params:
      # +blast_type+: blast command in String format (e.g 'blast(x/p)')
      # +query+: String containing the the query in fasta format
      # +db+: database
      # +num_threads+: The number of threads to run BLAST with.
      # Output:
      # String with the blast xml output
      def run_blast(query, db = opt[:db], seq_type = config[:type],
                    num_threads = opt[:num_threads])

        blast_type = (seq_type == :protein) ? 'blastp' : 'blastx'
        # -num_threads is not supported on remote databases
        threads = (db !~ /remote/) ? "-num_threads #{num_threads}" : ''

        blastcmd = "#{blast_type} -db '#{db}' -evalue #{EVALUE} -outfmt 5" \
                   " #{threads}"

        cmd = "echo \"#{query}\" | #{blastcmd}"
        `#{cmd} 2>&1 /dev/null`
      end

      ##
      # Runs BLAST on an input file
      # Params:
      # +blast_type+: blast command in String format (e.g 'blastx' or 'blastp')
      # +opt+: Hash made of :input_fasta_file :blast_xml_file, :db, :num_threads
      # +gapopen+: gapopen blast parameter
      # +gapextend+: gapextend blast parameter
      # +nr_hits+: max number of hits
      # Output:
      # XML file
      def run_blast_on_input_file(input_file = opt[:input_fasta_file],
                                  db = opt[:db], seq_type = config[:type],
                                  num_threads = opt[:num_threads])
        return if opt[:blast_xml_file] || opt[:blast_tabular_file]

        puts 'Running BLAST on input file. This might take a while.'
        puts 'This will generate a BLAST xml file that can then be'
        puts 'provided to GeneValidator with the "-x", "--blast_xml_file" argument'
	puts ''

        opt[:blast_xml_file] = opt[:input_fasta_file] + '.blast_xml'

        blast_type = (seq_type == :protein) ? 'blastp' : 'blastx'
        # -num_threads is not supported on remote databases
        threads = (opt[:db] !~ /remote/) ? "-num_threads #{num_threads}" : ''

        blastcmd = "#{blast_type} -query '#{input_file}'" \
                   " -out '#{opt[:blast_xml_file]}' -db #{db} " \
                   " -evalue #{EVALUE} -outfmt 5 #{threads}"

        `#{blastcmd} 2>&1 /dev/null`

        return unless File.zero?(opt[:blast_xml_file])
        $stderr.puts 'Blast failed to run on the input file.' 
        if opt[:db] !~ /remote/
          $stderr.puts 'Please ensure that the BLAST database exists and try again'
        else
          $stderr.puts 'You are using BLAST with a remote database. Please ensure' 
          $stderr.puts 'that you have internet access and try again.'
        end
        exit 1
      end

      ##
      # Parses the next query from the blast xml output query
      # Params:
      # +iterator+: blast xml iterator for hits
      # +type+: the type of the sequence: :nucleotide or :protein
      # Outputs:
      # Array of +Sequence+ objects corresponding to the list of hits
      def parse_next(iterator, type = config[:type])
        hits = []
        iter = iterator.next

        # parse blast the xml output and get the hits
        # hits obtained are proteins! (we use only blastp and blastx)
        iter.each do |hit|
          seq = Sequence.new

          seq.length_protein = hit.len.to_i
          seq.type           = :protein
          seq.identifier     = hit.hit_id
          seq.definition     = hit.hit_def
          seq.accession_no = hit.accession

          # get all high-scoring segment pairs (hsp)
          hsps = []

          hit.hsps.each do |hsp|
            current_hsp            = Hsp.new
            current_hsp.hsp_evalue = format('%.0e', hsp.evalue)

            current_hsp.hit_from         = hsp.hit_from.to_i
            current_hsp.hit_to           = hsp.hit_to.to_i
            current_hsp.match_query_from = hsp.query_from.to_i
            current_hsp.match_query_to   = hsp.query_to.to_i

            if type == :nucleotide
              current_hsp.match_query_from /= 3
              current_hsp.match_query_to /= 3
              current_hsp.match_query_from += 1
              current_hsp.match_query_to += 1
            end

            current_hsp.query_reading_frame = hsp.query_frame.to_i

            current_hsp.hit_alignment = hsp.hseq.to_s
            if guess_sequence_type(current_hsp.hit_alignment) != :protein
              fail SequenceTypeError
            end

            current_hsp.query_alignment = hsp.qseq.to_s
            if guess_sequence_type(current_hsp.query_alignment) != :protein
              fail SequenceTypeError
            end
            current_hsp.align_len = hsp.align_len.to_i
            current_hsp.identity  = hsp.identity.to_i
            current_hsp.pidentity = (100 * hsp.identity / (hsp.align_len + 0.0)).round(2)

            hsps.push(current_hsp)
          end

          seq.hsp_list = hsps
          hits.push(seq)
        end

        hits
      rescue SequenceTypeError => e
        $stderr.puts e
        exit 1
      rescue StopIteration
        nil
      end

      ##
      # Method copied from sequenceserver/sequencehelpers.rb
      # Splits input at putative fasta definition lines (like ">adsfadsf");
      # then guesses sequence type for each sequence.
      # If not enough sequence to determine, returns nil.
      # If 2 kinds of sequence mixed together, raises ArgumentError
      # Otherwise, returns :nucleotide or :protein
      # Params:
      # +sequence_string+: String to validate
      # Output:
      # nil, :nucleotide or :protein
      def type_of_sequences(fasta_format_string)
        # the first sequence does not need to have a fasta definition line
        sequences = fasta_format_string.split(/^>.*$/).delete_if(&:empty?)
        # get all sequence types
        sequence_types = sequences.collect { |seq| guess_sequence_type(seq) }.uniq.compact

        return nil if sequence_types.empty?
        return sequence_types.first if sequence_types.length == 1
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
        # removing non-letter and ambiguous characters
        cleaned_sequence = sequence_string.gsub(/[^A-Z]|[NX]/i, '')
        return nil if cleaned_sequence.length < 10 # conservative

        type = Bio::Sequence.new(cleaned_sequence).guess(0.9)
        (type == Bio::Sequence::NA) ? :nucleotide : :protein
      end

      ##
      #
      def guess_sequence_type_from_input_file(file = opt[:input_fasta_file])
        lines = File.foreach(file).first(10)
        seqs = ''
        lines.each do |l|
          seqs += l.chomp unless l[0] == '>'
        end
        guess_sequence_type(seqs)
      end
    end
  end
end
