require 'rake/testtask'

task :default => [:test]

desc "Unit tests for the majority of class methods"
task :test do
  Rake::TestTask.new do |t|
    t.libs << 'test'
  end
end

desc "Computes some statistics for no of positive / false positive/negative results"
task :output do
  fname = ENV["FILE"] || "data/one_direction_gene_merge/one_direction_gene_merge_proteins"
  type = ENV["TYPE"] || "protein"  
  exec("ruby test_output/test_output.rb #{fname} #{type}")
end


