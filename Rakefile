lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'genevalidator/version'
require 'rake/testtask'

task :default => [:build]

desc "Installs the ruby gem"
task :build do
  exec("gem build GeneValidator.gemspec && gem install ./GeneValidator-#{GeneValidator::VERSION}.gem")
end

desc "Unit tests for the majority of class methods"
task :test do
  Rake::TestTask.new do |t|
    t.libs << 'test'
  end
end

desc "GeneValidationValidator"
task :test_output do
  Rake::TestTask.new do |t|
    t.libs << "test/big_test"
    t.test_files = FileList['test/big_test/*.rb']
  end
end

desc "Generates documentation"
task :doc do
  exec("yardoc 'lib/**/*.rb'")
end

