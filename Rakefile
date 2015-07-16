require 'rake/testtask'

task default: [:build, :doc]

desc 'Builds gem'
task :build do
  lib = File.expand_path('../lib', __FILE__)
  $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
  require 'genevalidator/version'
  sh "gem build genevalidator.gemspec && gem install ./genevalidator-#{GeneValidator::VERSION}.gem"
end

desc 'Runs tests'
task :test do
  Rake::TestTask.new do |t|
    t.libs.push 'lib'
    t.test_files = FileList['test/*.rb']
    t.verbose = true
  end
end

desc 'Generates documentation'
task :doc do
  sh "yardoc 'lib/**/*.rb'"
end
