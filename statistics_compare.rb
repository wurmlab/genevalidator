
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

def write_statistics(file, cond, queries, no_queries, hash_true, skip_nee = false)

  cond = File.basename(cond)

  queries.values[0..no_queries].each do |validations|

    if skip_nee
      nee = validations.map{|v| (v.message == "Not enough evidence") or (v.message == "")}.count(true)
      if nee == validations.length
        next
      end
    end

    validations.map do |v|
      if v.validation != :unapplicable and v.result == v.expected
        if hash_true[v.short_header] == nil
          hash_true[v.short_header] = 1
        else
          hash_true[v.short_header] = hash_true[v.short_header] + 1
        end
      end
    end

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

    file.write cond[0,20]
    file.write "\t"
    file.write overall_score

    validations.map do |v| 
      if v.validation != :unapplicable
        file.write("\t#{v.result == v.expected}")
      end
    end
    file.write "\n"
  end
  
end

puts "USE: ruby statistics.rb YAML_FILE1 YAML_FILE2 [NEE]"

qqueries = YAML.load_file(ARGV[0])
if ARGV[1] != nil
  qqueries2 = YAML.load_file(ARGV[1])
  title = "#{qqueries.length}q from  #{File.basename(ARGV[0])[0..20]}&\n #{qqueries2.length}q from #{File.basename(ARGV[1])[0..20]}"
else
  title = "#{qqueries.length}q from  #{File.basename(ARGV[0])[0..20]}"
end

hash1_true_validations = {}
hash2_true_validations = {}

R.echo "enable = nil, stderr = nil"

file_csv=File.new("#{ARGV[0]}_individual_scores.csv",'w')

header = "Cond \t Score"
qqueries.values[0].map do |v| 
  if v.validation != :unapplicable
    header<<"\t#{v.class.to_s}"
  end
end
file_csv.write "#{header}\n"

nee = false

if ARGV[2] != nil
  nee = true
end

hash1_true_validations = {}
hash2_true_validations = {}

write_statistics(file_csv, ARGV[0], qqueries, qqueries.values.length, hash1_true_validations, nee)
if ARGV[1] != nil
  write_statistics(file_csv, ARGV[1], qqueries2, qqueries2.values.length, hash2_true_validations, nee)
end

R.eval "df = read.csv('#{ARGV[0]}_individual_scores.csv', sep='\\t')"
puts "> df = read.csv('#{ARGV[0]}_individual_scores.csv', sep='\\t')"

R.eval "library('ggplot2')"
R.eval "ggplot(df, aes(x=Score, fill=Cond)) + geom_histogram(binwidth=10, alpha=.5, position='identity') + ggtitle('#{qqueries.length}q from  #{title}')"
puts "> ggplot(df, aes(x=Score, fill=Cond)) + geom_histogram(binwidth=10, alpha=.5, position='identity') + ggtitle('#{qqueries.length}q from  #{title}')"

R.eval "dev.copy(png,'#{ARGV[0]}_score.png')"
R.eval "dev.off()"
puts "> dev.copy(png,'#{ARGV[0]}_score.png')"

##########################
# plot for each validation
##########################

levels = "c("
time = "factor(c("
percentage = "c("
smth = "factor(c("

hash1_true_validations.each do |k, v|
  levels = levels + "'" + k.to_s + "'" + ","
  time = time + "'" + k.to_s + "'" + ","
  percentage = percentage + v.to_s + ","
  smth = smth + "'#{File.basename(ARGV[0])[0..20]}',"
end

if ARGV[1] != nil
  hash2_true_validations.each do |k, v|
    time = time + "'" + k.to_s + "'" + ","
    percentage = percentage + v.to_s + ","
    smth = smth + "'#{File.basename(ARGV[1])[0..20]}',"
  end
end  

levels = levels[0..levels.length-2] + ")"
time = time[0..time.length-2] + "))";
percentage = percentage[0..percentage.length-2] + ")"
smth = smth[0..smth.length-2] + "))"

R.eval "df = data.frame(file = #{smth}, correct_validations = #{time}, no_queries = #{percentage})"
puts "> df = data.frame(file = #{smth}, correct_validations = #{time}, no_queries = #{percentage})"

R.eval "ggplot(data=df, aes(x=correct_validations, y=no_queries, fill=file)) + geom_bar(stat='identity', position=position_dodge())"
puts "> ggplot(data=df, aes(x=correct_validations, y=no_queries, fill=file)) + geom_bar(stat='identity', position=position_dodge())"

R.eval "dev.copy(png,'#{ARGV[0]}_validations.png')"
R.eval "dev.off()"
puts "> dev.copy(png,'#{ARGV[0]}_validations.png')"



