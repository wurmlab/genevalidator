require 'rake/testtask'

task :default => [:build]

desc "Installs the ruby gem"
task :build do
  exec("gem build genevalidator.gemspec && gem install ./GeneValidator-0.1.gem")
end

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

desc "Generates documentation"
task :doc do
  exec("yardoc 'lib/**/*.rb'")
end

