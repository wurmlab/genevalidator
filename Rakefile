require 'rake/testtask'

task default: [:build]

desc 'Installs the ruby gem'
task :build do
  lib = File.expand_path('../lib', __FILE__)
  $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
  require 'genevalidator/version'
  exec("gem build genevalidator.gemspec && gem install ./genevalidator-#{GeneValidator::VERSION}.gem")
end

desc 'Unit tests for the majority of class methods'
task :test do
  Rake::TestTask.new do |t|
    t.libs.push 'lib'
    t.test_files = FileList['test/*.rb']
    t.verbose = true
  end
end

desc 'Generates documentation'
task :doc do
  exec("yardoc 'lib/**/*.rb'")
end
