require 'bio'
require 'bio-blastxmlparser'
require 'forwardable'

require 'genevalidator/exceptions'
require 'genevalidator/hsp'
require 'genevalidator/output'
require 'genevalidator/query'

module GeneValidator
  # Contains methods that run BLAST and methods that analyse sequences
  class BlastUtils
    class << self
      extend Forwardable
      def_delegators GeneValidator, :opt, :config, :dirs

      EVALUE = 1e-5

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
                                  num_threads = opt[:num_threads],
                                  blast_options = opt[:blast_options])
        return if opt[:blast_xml_file] || opt[:blast_tabular_file]
        remote = opt[:db].match?(/remote/) ? true : false
        warn '==> Running BLAST. This may take a while.' unless remote
        warn_if_remote_database(opt)
        fname = File.basename(input_file) + '.blast_xml'
        opt[:blast_xml_file] = File.join(dirs[:tmp_dir], fname)

        blast_type = seq_type == :protein ? 'blastp' : 'blastx'
        # -num_threads is not supported on remote databases
        threads = remote ? '' : "-num_threads #{num_threads}"

        blastcmd = "#{blast_type} -query '#{input_file}'" \
                   " -out '#{opt[:blast_xml_file]}' -db #{db} " \
                   " -evalue #{EVALUE} -outfmt 5 #{threads} #{blast_options}"

        `#{blastcmd} >/dev/null 2>&1`
        return unless File.zero?(opt[:blast_xml_file])
        warn 'Blast failed to run on the input file.'
        if remote
          warn 'You are using BLAST with a remote database. Please'
          warn 'ensure that you have internet access and try again.'
        else
          warn 'Please ensure that the BLAST database exists and try again.'
        end
      end

      ##
      # Parses the next query from the blast xml output query
      # Params:
      # +iterator+: blast xml iterator for hits
      # +type+: the type of the sequence: :nucleotide or :protein
      # Outputs:
      # Array of +Sequence+ objects corresponding to the list of hits
      def parse_next(iterator)
        iter = iterator.next

        # parse blast the xml output and get the hits
        # hits obtained are proteins! (we use only blastp and blastx)
        hits = []
        iter.each do |hit|
          seq                = Query.new
          seq.length_protein = hit.len.to_i
          seq.type           = :protein
          seq.identifier     = hit.hit_id
          seq.definition     = hit.hit_def
          seq.accession_no   = hit.accession
          seq.hsp_list       = hit.hsps.map { |hsp| Hsp.new(xml_input: hsp) }

          hits << seq
        end
        hits
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
        sequence_types = sequences.collect { |seq| guess_sequence_type(seq) }
                                  .uniq.compact

        return nil if sequence_types.empty?
        sequence_types.first if sequence_types.length == 1
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
        type == Bio::Sequence::NA ? :nucleotide : :protein
      end

      ##
      #
      def guess_sequence_type_from_input_file(file = opt[:input_fasta_file])
        lines = File.foreach(file).first(10)
        seqs = ''
        lines.each { |l| seqs += l.chomp unless l[0] == '>' }
        guess_sequence_type(seqs)
      end

      def warn_if_remote_database(opt)
        return if opt[:db] !~ /remote/
        warn '' # a blank line
        warn '==> BLAST search and subsequent analysis will be done on a remote'
        warn '    database. Please use a local database for larger analysis.'
        warn '' # a blank line
      end
    end
  end
end
