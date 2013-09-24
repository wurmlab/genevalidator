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

desc "Generates documentation"
task :doc do
  exec("yardoc 'lib/**/*.rb'")
end

