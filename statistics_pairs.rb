require 'genevalidator/validation_length_cluster'
require 'genevalidator/validation_length_rank'
require 'genevalidator/validation_blast_reading_frame'
require 'genevalidator/validation_gene_merge'
require 'genevalidator/validation_duplication'
require 'genevalidator/validation_open_reading_frame'
require 'genevalidator/validation_alignment'
require 'yaml'
require 'rinruby'
require 'io/console'

puts "USE: ruby statistics.rb YAML_FILE_v1 YAML_FILE_v2 FASTA_v1 FASTA_v2"

if(ARGV.length != 4)
  exit!
end

queries_v1 = YAML.load_file(ARGV[0])
queries_v2 = YAML.load_file(ARGV[1])

# index the fasta files

R.echo "enable = nil, stderr = nil"

file=File.new("#{ARGV[0]}_pair_scores.csv",'w')

header = "Id\tScore_Difference\tLen_cluster_v1\tLen_cluster_v2\tLen_rank_v1\tLen_rank_v2\tLen_rank_dif\tMerge_v1\tMerge_v2\tMerge_dif\tDup_v1\tDup_v2\tDup_dif\tMA_gaps_v1\tMA_gaps_v2\tMA_gaps_dif\tMA_extra_v1\tMA_extra_v2\tMA_extra_dif\tMA_conserv_v1\tMA_conserv_v2\tMA_conserv_dif"

file.write "#{header}\n"

no_queries = queries_v1.values.length

scores = []

# create a list of indeces for each file
def create_list_of_indeces(filename)

  content = File.open(filename, "rb").read.gsub(/ .*/, "")
  File.open(filename, 'w+') { |file| file.write(content)}

  #index the fasta file
  keys = content.scan(/>(.*)\n/).flatten
  values = content.enum_for(:scan, /(>[^>]+)/).map{ Regexp.last_match.begin(0)}

  # make an index hash
  index_hash = Hash.new
  keys.each_with_index do |k, i|          
    start = values[i]
    if i == values.length - 1
      endf = content.length - 1
    else
      endf = values[i+1]
    end
    index_hash[k] = [start, endf]
  end

  return index_hash

end

def get_score (validations)
    successes = validations.map{|v| v.result ==
      v.expected}.count(true)

    fails = validations.map{|v| v.validation != :unapplicable and
      v.validation != :error and
      v.result != v.expected}.count(true)

    lcv = validations.select{|v| v.class == LengthClusterValidationOutput}
    lrv = validations.select{|v| v.class == LengthRankValidationOutput}

    if lcv.length == 1 and lrv.length == 1
      score_lcv = (lcv[0].result == lcv[0].expected)
      score_lrv = (lrv[0].result == lrv[0].expected)
      # if both are true this should be counted as a single success
      if score_lcv == true and score_lrv == true
        successes = successes - 1
      else
      # if both are false this will be a fail
        if score_lcv == false and score_lrv == false
          fails = fails - 1
        else
          successes = successes - 0.5
          fails = fails - 0.5
        end
      end
    end

    overall_score = (successes*100/(successes + fails + 0.0)).round(0)
    return overall_score
end

fasta1 = ARGV[2]
fasta2 = ARGV[3]
hash_fasta1 = create_list_of_indeces(ARGV[2])
hash_fasta2 = create_list_of_indeces(ARGV[3])

#find queries in common
common = 0;
better = 0
worse = 0
curated = 0

queries_v1.each do |key,validations_v1|

    to_print = false

    if queries_v2[key] == nil
      puts "#{key} was not found"   
    else

      common += 1

      # get the fasta sequences
      
      idx = hash_fasta1[key]
      query = IO.binread(fasta1, idx[1] - idx[0], idx[0])
      parse_query   = query.scan(/>([^\n]*)\n([A-Za-z\n]*)/)[0]
      sequence_v1 = parse_query[1].gsub("\n","")

      idx = hash_fasta2[key]
      query = IO.binread(fasta2, idx[1] - idx[0], idx[0])
      parse_query   = query.scan(/>([^\n]*)\n([A-Za-z\n]*)/)[0]
      sequence_v2 = parse_query[1].gsub("\n","")

      if sequence_v1 != sequence_v2
        puts "#{key} was curated"
        curated += 1
        to_print = true
      else
        next
      end

      if validations_v1[0].result == :warning or queries_v2[key][0].result == :warning
        next
      end
      overall_score_v1 = get_score(validations_v1)
      overall_score_v2 = get_score(queries_v2[key])

      if overall_score_v1 < overall_score_v2
        puts "#{key}: #{overall_score_v1} #{overall_score_v2}"  
        better += 1
      else
        if overall_score_v1 > overall_score_v2
          puts "!!! #{key}: #{overall_score_v1} #{overall_score_v2}"
          worse += 1
        end
      end
      dif = overall_score_v2 - overall_score_v1
      #unless dif == 0
        to_print = true
        file.write "#{key}\t"
        file.write "#{dif}"  
        if queries_v1[key][0].result != :warning and queries_v2[key][0].result != :warning and queries_v1[key][0].result != :error and queries_v2[key][0].result != :error 
          file.write "\t#{queries_v1[key][0].result}"
          file.write "\t#{queries_v2[key][0].result}"
        else
          file.write "\t-\t-"
        end

        if queries_v1[key][1].result != :warning and queries_v2[key][1].result != :warning and queries_v1[key][1].result != :error and queries_v2[key][1].result != :error
          file.write "\t#{queries_v1[key][1].percentage}"
          file.write "\t#{queries_v2[key][1].percentage}"
          file.write "\t#{(queries_v2[key][1].percentage - queries_v1[key][1].percentage).round(2)}"
        else
          file.write "\t-\t-"
        end

        if queries_v1[key][3].result != :warning and queries_v2[key][3].result != :warning and queries_v1[key][3].result != :error and queries_v2[key][3].result != :error
          file.write "\t#{queries_v1[key][3].slope.round(2)}"
          file.write "\t#{queries_v2[key][3].slope.round(2)}"
          file.write "\t#{(queries_v2[key][3].slope - queries_v1[key][3].slope).round(2)}"
        else
          file.write "\t-\t-"
        end

        if queries_v1[key][4].result != :warning and queries_v2[key][4].result != :warning and queries_v1[key][4].result != :error and queries_v2[key][4].result != :error
          file.write "\t#{queries_v1[key][4].pvalue.round(2)}"
          file.write "\t#{queries_v2[key][4].pvalue.round(2)}"
          file.write "\t#{(queries_v2[key][4].pvalue - queries_v1[key][4].pvalue).round(2)}"
        else
          file.write "\t-\t-"
        end

        if queries_v1[key][6].result != :warning and queries_v2[key][6].result != :warning and queries_v1[key][6].result != :error and queries_v2[key][6].result != :error
          file.write "\t#{queries_v1[key][6].gaps.round(2)}"
          file.write "\t#{queries_v2[key][6].gaps.round(2)}"
          file.write "\t#{(queries_v2[key][6].gaps - queries_v1[key][6].gaps).round(2)}"
          file.write "\t#{queries_v1[key][6].extra_seq.round(2)}"
          file.write "\t#{queries_v2[key][6].extra_seq.round(2)}"
          file.write "\t#{(queries_v2[key][6].extra_seq - queries_v1[key][6].extra_seq).round(2)}"
          file.write "\t#{queries_v1[key][6].consensus.round(2)}"
          file.write "\t#{queries_v2[key][6].consensus.round(2)}"
          file.write "\t#{(queries_v2[key][6].consensus - queries_v1[key][6].consensus).round(2)}"
        else
          file.write "\t-\t-\t-\t-\t-\t-"
        end

        file.write "\n"
      #end

      if to_print
        evaluation_v1 = "v1: "
        validations_v1.each{|v| evaluation_v1 << "#{v.print}|"}
        evaluation_v2 = "v2: "
        queries_v2[key].each{|v| evaluation_v2 << "#{v.print}|"}

        puts evaluation_v1
        puts evaluation_v2
        puts ""
      end 
    end
#    validations.map{ |v| file.write("\t#{v.result == v.expected}") }
end

file.close
puts " commun = #{common}, better=#{better}, worse=#{worse}, curated = #{curated}" 

R.eval "df = read.csv('#{ARGV[0]}_pair_scores.csv', sep='\\t')"
puts "> df = read.csv('#{ARGV[0]}_pair_scores.csv', sep='\\t')"

R.eval "library('ggplot2')"
R.eval "ggplot(df, aes(x=Score_Difference)) + geom_histogram(binwidth=10) + ggtitle('#{File.basename(ARGV[0])[0..20]} vs #{File.basename(ARGV[1])[0..20]}\n curated = #{curated}, better=#{better}, worse=#{worse}')"
puts "> ggplot(df, aes(x=Score_Difference)) + geom_histogram(binwidth=10)"

R.eval "dev.copy(png,'#{ARGV[0]}.png')"
R.eval "dev.off()"
puts "> dev.copy(png,'#{ARGV[0]}.png')"

#########################################################
#### plot score difference for different validations ####
#########################################################

R.eval "ggplot(df, aes(x=Len_rank_dif)) + geom_histogram(binwidth=0.1) + ggtitle('#{File.basename(ARGV[0])[0..20]} vs #{File.basename(ARGV[1])[0..20]}\n Len_rank_dif}')"
puts "> ggplot(df, aes(x=Len_rank_dif)) + geom_histogram(binwidth=0.1)"
R.eval "dev.copy(png,'#{ARGV[0]}_len_rank_dif.png')"
R.eval "dev.off()"
puts "> dev.copy(png,'#{ARGV[0]}_len_rank_dif.png')"

R.eval "ggplot(df, aes(x=Dup_dif)) + geom_histogram(binwidth=0.1) + ggtitle('#{File.basename(ARGV[0])[0..20]} vs #{File.basename(ARGV[1])[0..20]}\n Dup_dif}')"
puts "> ggplot(df, aes(x=Dup_dif)) + geom_histogram(binwidth=0.1)"
R.eval "dev.copy(png,'#{ARGV[0]}_dup_dif.png')"
R.eval "dev.off()"
puts "> dev.copy(png,'#{ARGV[0]}_dup_dif.png')"

R.eval "ggplot(df, aes(x=MA_gaps_dif)) + geom_histogram(binwidth=0.1) + ggtitle('#{File.basename(ARGV[0])[0..20]} vs #{File.basename(ARGV[1])[0..20]}\n MA_gaps_dif}')"
puts "> ggplot(df, aes(x=MA_gaps_dif)) + geom_histogram(binwidth=0.1)"
R.eval "dev.copy(png,'#{ARGV[0]}_ma_gaps_dif.png')"
R.eval "dev.off()"
puts "> dev.copy(png,'#{ARGV[0]}_ma_gaps_dif.png')"

R.eval "ggplot(df, aes(x=MA_extra_dif)) + geom_histogram(binwidth=0.1) + ggtitle('#{File.basename(ARGV[0])[0..20]} vs #{File.basename(ARGV[1])[0..20]}\n MA_extra_dif}')"
puts "> ggplot(df, aes(x=MA_extra_dif)) + geom_histogram(binwidth=0.1)"
R.eval "dev.copy(png,'#{ARGV[0]}_ma_extra_dif.png')"
R.eval "dev.off()"
puts "> dev.copy(png,'#{ARGV[0]}_ma_extra_dif.png')"

R.eval "ggplot(df, aes(x=MA_conserv_dif)) + geom_histogram(binwidth=0.1) + ggtitle('#{File.basename(ARGV[0])[0..20]} vs #{File.basename(ARGV[1])[0..20]}\n MA_conserv_dif}')"
puts "> ggplot(df, aes(x=MA_conserv_dif)) + geom_histogram(binwidth=0.1)"
R.eval "dev.copy(png,'#{ARGV[0]}_ma_conserv_dif.png')"
R.eval "dev.off()"
puts "> dev.copy(png,'#{ARGV[0]}_ma_conserv_dif.png')"


