require 'rake/testtask'

task default: [:build, :doc]

desc 'Builds and installs'
task install: [:build] do
  require_relative 'lib/genevalidator/version'
  sh "gem install ./genevalidator-#{GeneValidator::VERSION}.gem"
end

desc 'Builds gem'
task :build => [:test] do
  sh 'gem build genevalidator.gemspec'
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
