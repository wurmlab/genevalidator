require 'rake/testtask'
GEMSPEC = Gem::Specification::load('genevalidator.gemspec')

task default: [:build]

desc 'Builds and installs'
task install: [:build] do
  sh "gem install #{Rake.original_dir}/genevalidator-#{GEMSPEC.version}.gem"
end

desc 'Runs tests, generates documentation, builds gem (default)'
task build: [:test, :doc] do
  sh "gem build #{Rake.original_dir}/genevalidator.gemspec"
end

desc 'Runs tests'
task :test do
  Rake::TestTask.new do |t|
    t.libs.push 'lib'
    t.test_files = FileList['test/test_*.rb']
    t.verbose = false
    t.warning = false
  end
end

desc 'Generates documentation'
task :doc do
  sh "yardoc 'lib/**/*.rb'"
end

##
#### TRAVELLING RUBY
##

# For Bundler.with_clean_env
require 'bundler/setup'

TMP_DIR = "#{Rake.original_dir}/tmp"
APP_NAME = "#{GEMSPEC.name}-#{GEMSPEC.version}"
PLATFORMS = %w[linux-x86 linux-x86_64 osx]
TRAVELING_RUBY_VERSION = 'traveling-ruby-20150715-2.2.2'
TRAVELING_RUBYGEMS_VERSION = 'traveling-ruby-gems-20150715-2.2.2'
NOKOGIRI_VERSION = 'nokogiri-1.6.6.2'
MAFFT = {
  'version': '7.397',
  'linux-x86': 'https://mafft.cbrc.jp/alignment/software/mafft-7.397-linux.tgz',
  'linux-x86_64': 'https://mafft.cbrc.jp/alignment/software/mafft-7.397-linux.tgz',
  'osx': 'https://mafft.cbrc.jp/alignment/software/mafft-7.397-mac.zip'
}
BLAST = {
  'version': '2.7.1+',
  'linux-x86': 'https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.7.1/ncbi-blast-2.7.1+-x64-linux.tar.gz',
  'linux-x86_64': 'https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.7.1/ncbi-blast-2.7.1+-x64-linux.tar.gz',
  'osx': 'https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.7.1/ncbi-blast-2.7.1+-x64-macosx.tar.gz',
}
JQ = {
  'version': '1.5',
  'linux-x86': 'https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux32',
  'linux-x86_64': 'https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64',
  'osx': 'https://github.com/stedolan/jq/releases/download/jq-1.5/jq-osx-amd64'
}

desc 'Create standalone GeneValidator packages'
task :package do
  rm_rf TMP_DIR
  mkdir TMP_DIR
  task('package:build' => ['package:linux-x86', 'package:linux-x86_64', 'package:osx']).invoke
  rm_rf TMP_DIR
end

# Usage:
# - Complete run
#     rake package
# - Just create directories and don't compress
#     rake package DIR_ONLY=1
namespace :package do
  PLATFORMS.each do |platform|
    task platform => [
      :bundle_install, :reduce_bundle_size,
      "#{TMP_DIR}/#{TRAVELING_RUBY_VERSION}-#{platform}.tar.gz",
      "#{TMP_DIR}/#{TRAVELING_RUBY_VERSION}-#{platform}-#{NOKOGIRI_VERSION}.tar.gz"
    ] do
      package_dir   = "#{Rake.original_dir}/#{APP_NAME}-#{platform}"
      lib_dir       = "#{package_dir}/lib/"
      bin_dir       = "#{package_dir}/bin/"
      exemplar_dir  = "#{package_dir}/exemplar_data/"
      blast_db_dir  = "#{package_dir}/blast_db"
      app_dir       = "#{lib_dir}/app/"
      vendor_dir    = "#{lib_dir}/vendor/"
      ruby_dir      = "#{lib_dir}/ruby/"
      pack_dir      = "#{lib_dir}/packages/"
      nokogiri_path = "#{TMP_DIR}/#{TRAVELING_RUBY_VERSION}-#{platform}-" \
                      "#{NOKOGIRI_VERSION}.tar.gz"
      ruby_path     = "#{TMP_DIR}/#{TRAVELING_RUBY_VERSION}-#{platform}.tar.gz"

      # set up dir structure
      rm_rf package_dir
      mkdir_p app_dir
      mkdir bin_dir
      mkdir exemplar_dir
      mkdir vendor_dir
      mkdir ruby_dir
      mkdir pack_dir

      cp_r "#{Rake.original_dir}/bin", app_dir
      cp_r "#{TMP_DIR}/vendor", lib_dir

      cp "#{Rake.original_dir}/exemplar_data/mrna_data.fa", exemplar_dir
      cp "#{Rake.original_dir}/exemplar_data/protein_data.fa", exemplar_dir

      cd vendor_dir do
        File.write('Gemfile', GEMFILE_CONTENTS)
        mkdir '.bundle'
        File.write('.bundle/config', BUNDLER_CONFIG)

        sh "tar -xzf #{nokogiri_path} -C ruby"
      end

      cd lib_dir do
        sh "tar -xzf #{ruby_path} -C ruby"
      end

      cd pack_dir do
        process_package(MAFFT[platform.to_sym], 'mafft')
        process_package(BLAST[platform.to_sym], 'blast')
      end

      cd package_dir do
        File.write(GEMSPEC.name, SCRIPT_CONTENTS)
        sh "chmod +x #{GEMSPEC.name}"
        File.write('Readme.txt', readme_contents(platform))
      end

      cd bin_dir do
        Dir['../lib/packages/blast/bin/*'].each do |bin|
          ln_s bin, File.basename(bin)
        end

        sh "curl -L #{JQ[platform.to_sym]} -o jq"
        sh 'chmod +x jq'

        sh "sed 's|SELFDIR}/|SELFDIR}/../|g' #{package_dir}/#{GEMSPEC.name} > #{GEMSPEC.name}"
        sh "chmod +x #{GEMSPEC.name}"
      end

      cp_r "#{TMP_DIR}/blast_db", blast_db_dir

      unless ENV['DIR_ONLY']
        cd Rake.original_dir do
          sh "tar -czf #{APP_NAME}-#{platform}.tar.gz #{APP_NAME}-#{platform}"
          rm_rf package_dir
        end
      end
    end
  end

  desc 'Install gems to local directory'
  task :bundle_install do
    if RUBY_VERSION !~ /^2\.2\./
      abort "You can only 'bundle install' using Ruby 2.2, because that's " \
            'what Traveling Ruby uses.'
    end

    cd Rake.original_dir do
      cp 'Gemfile', TMP_DIR
      File.write("#{TMP_DIR}/#{GEMSPEC.name}.gemspec", edited_gemspec_content)
    end

    cd TMP_DIR do
      Bundler.with_clean_env do
        sh 'env BUNDLE_IGNORE_CONFIG=1 bundle install --path vendor ' \
          '--without development test'
      end

      cd 'vendor/ruby/2.2.0' do
        cd 'gems' do
          mkdir APP_NAME
          %w[aux lib].each { |d| cp_r "#{Rake.original_dir}/#{d}", APP_NAME }
        end

        cd 'specifications' do
          cp "#{TMP_DIR}/#{GEMSPEC.name}.gemspec", "#{APP_NAME}.gemspec"
        end
      end

      mkdir 'blast_db'
      cd 'blast_db' do
        sh 'update_blastdb.pl --decompress swissprot' do |_, e|
          abort 'update_blastdb.pl failed to run.' if e.exitstatus == 2
          # This script returns 0 on successful operations that result in no
          # downloads, 1 on successful operations that downloaded files,
          # and 2 on errors.
        end
      end
    end
  end

  desc 'Reduce Vendor size'
  task :reduce_bundle_size do
    cd "#{TMP_DIR}/vendor" do
      sh 'rm -f */*/cache/*'
      sh 'rm -rf ruby/*/extensions'
      sh "find ruby/2.2.0/gems -name '*.so' | xargs rm -f"
      sh "find ruby/2.2.0/gems -name '*.bundle' | xargs rm -f"
      sh "find ruby/2.2.0/gems -name '*.o' | xargs rm -f"

      # Remove tests
      %w[test tests spec features benchmark].each do |dir|
        sh "rm -rf ruby/*/gems/*/#{dir}"
      end

      # Remove documentation
      %w[README* CHANGE* Change* COPYING* LICENSE* MIT-LICENSE* TODO *.txt *.md *.rdoc].each do |file|
        sh "rm -f ruby/*/gems/*/#{file}"
      end
      %w[doc docs example examples sample doc-api].each do |dir|
        sh "rm -rf ruby/*/gems/*/#{dir}"
      end
      sh "find ruby -name '*.md' | xargs rm -f"

      # Remove misc unnecessary files
      sh 'rm -rf ruby/*/gems/*/.gitignore'
      sh 'rm -rf ruby/*/gems/*/.travis.yml'

      # Remove leftover native extension sources and compilation objects
      sh 'rm -f ruby/*/gems/*/ext/Makefile'
      sh 'rm -f ruby/*/gems/*/ext/*/Makefile'
      sh 'rm -f ruby/*/gems/*/ext/*/tmp'
      sh "find ruby -name '*.c' | xargs rm -f"
      sh "find ruby -name '*.cpp' | xargs rm -f"
      sh "find ruby -name '*.h' | xargs rm -f"
      sh "find ruby -name '*.rl' | xargs rm -f"
      sh "find ruby -name 'extconf.rb' | xargs rm -f"
      sh "find ruby/2.2.0/gems -name '*.o' | xargs rm -f"
      sh "find ruby/2.2.0/gems -name '*.so' | xargs rm -f"
      sh "find ruby/2.2.0/gems -name '*.bundle' | xargs rm -f"

      # Remove Java files. They're only used for JRuby support
      sh "find ruby -name '*.java' | xargs rm -f"
      sh "find ruby -name '*.class' | xargs rm -f"
    end
  end
end

PLATFORMS.each do |platform|
  file "#{TMP_DIR}/#{TRAVELING_RUBY_VERSION}-#{platform}.tar.gz" do
    download_runtime(platform)
  end
  file "#{TMP_DIR}/#{TRAVELING_RUBY_VERSION}-#{platform}-#{NOKOGIRI_VERSION}.tar.gz" do
    download_native_extension(platform, NOKOGIRI_VERSION)
  end
end

def download_runtime(platform)
  sh "curl -L --fail -o #{TMP_DIR}/#{TRAVELING_RUBY_VERSION}-#{platform}.tar.gz " +
    "https://d6r77u77i8pq3.cloudfront.net/releases/#{TRAVELING_RUBY_VERSION}-#{platform}.tar.gz"
end

def download_native_extension(platform, gem_name_and_version)
  sh "curl -L --fail -o #{TMP_DIR}/#{TRAVELING_RUBY_VERSION}-#{platform}-#{gem_name_and_version}.tar.gz " +
    "https://d6r77u77i8pq3.cloudfront.net/releases/#{TRAVELING_RUBYGEMS_VERSION}-#{platform}/#{gem_name_and_version}.tar.gz"
end

def process_package(url, package_name)
  if url.end_with?('.tar.gz', '.tgz')
    mkdir package_name
    cd package_name do
      sh "curl -L --fail #{url} | tar -xzf - --strip-components=1"
    end
  elsif url.end_with?('.zip')
    sh "curl -L --fail #{url} -o #{package_name}.zip"
    sh "unzip #{package_name}.zip"
    mv 'mafft-mac', package_name
    rm "#{package_name}.zip"
  end
end

def edited_gemspec_content
  file_list = Dir['lib/**/**'] + Dir['aux/**/**']
  edited_gemspec = []
  File.readlines('genevalidator.gemspec').each_with_index do |l, index|
    next if index < 4 # skip first four lines
    l = "s.version = '#{GEMSPEC.version}'\n" if l =~ /^\s+s.version/
    l = "s.files = ['#{file_list.join("','")}']\n" if l =~ /^\s+s.files/
    l = "s.add_dependency 'nokogiri', '1.6.6.2'\nend" if l =~ /^end/
    edited_gemspec << l
  end
  edited_gemspec.join
end

GEMFILE_CONTENTS = <<-GEMFILE
source 'http://rubygems.org'

gem 'bio', '~> 1.4'
gem 'bio-blastxmlparser', '~> 2.0'
gem '#{GEMSPEC.name}', '#{GEMSPEC.version}'
gem 'nokogiri', '1.6.6.2'
gem 'statsample', '2.1.0'
GEMFILE

SCRIPT_CONTENTS = <<-SCRIPT
#!/bin/bash
set -e

# Figure out where this script is located.
SELFDIR="$(dirname "$0")"
SELFDIR="$(cd "$SELFDIR" && pwd)"

# Tell Bundler where the Gemfile and gems are.
export BUNDLE_GEMFILE="${SELFDIR}/lib/vendor/Gemfile"
unset BUNDLE_IGNORE_CONFIG

MAFFT_DIR="${SELFDIR}/lib/packages/mafft/mafftdir"
BLAST_BIN="${SELFDIR}/lib/packages/blast/bin"
GV_BLAST_DB_DIR="${SELFDIR}/blast_db"; export GV_BLAST_DB_DIR

MAFFT_BINARIES="${MAFFT_DIR}/libexec"; export MAFFT_BINARIES;

# Run the actual app using the bundled Ruby interpreter, with Bundler activated.
PATH=${MAFFT_DIR}/bin:${BLAST_BIN}:$PATH  exec "$SELFDIR/lib/ruby/bin/ruby" -rbundler/setup "$SELFDIR/lib/app/bin/genevalidator" --db "${GV_BLAST_DB_DIR}" "$@"

SCRIPT

BUNDLER_CONFIG = <<-CONFIG
BUNDLE_PATH: .
BUNDLE_WITHOUT: "development:test"
BUNDLE_DISABLE_SHARED_GEMS: '1'
CONFIG

def readme_contents(platform)
<<-README

--------------------------------------------------------------------------------
GeneValidator (v#{GEMSPEC.version})
Website: https://wurmlab.github.io/tools/genevalidator/
Paper: https://doi.org/10.1093/bioinformatics/btw015

Standalone Package for #{platform}.
This package includes BLAST+ (v#{BLAST[:version]}), MAFFT (v#{MAFFT[:version]}), JQ (v#{JQ[:version]}) and the Swissprot BLAST database.

Please cite as follows:
Dragan M‡, Moghul MI‡, Priyam A, Bustos C & Wurm Y. 2015.
GeneValidator: identify problems with protein-coding gene predictions".
Bioinformatics, doi: 10.1093/bioinformatics/btw015.
-------------------------------------------------------------------------------

Running GeneValidator with Exemplar Data:

    cd /path/to/genevalidator/package/
    genevalidator -d blast_db/swissprot exemplar_data/protein_data.fa

Run the following to see all options available.

  genevalidator -h

See https://github.com/wurmlab/genevalidator for more usage information.

Please contact us if you require any further information.

-------------------------------------------------------------------------------
Genevalidator is licensed under the AGPL-3.0 License.

Dependencies packaged with GeneValidator are licensed under their respective licenses:
BLAST+ (Public Domain), Mafft (BSD), JQ (MIT) and SwissProt BLAST DB (CC BY-ND 3.0).
-------------------------------------------------------------------------------

README
end