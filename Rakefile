require 'rake/testtask'

task default: [:build, :doc]

desc 'Builds gem'
task :build do
  exec("gem build genevalidator.gemspec && gem install ./genevalidator-1.6.1.gem ")
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
