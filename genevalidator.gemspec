lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'genevalidator/version'

Gem::Specification.new do |s|
  s.name        = 'genevalidator'
  s.version     = GeneValidator::VERSION
  s.authors     = ['Monica Dragan', 'Ismail Moghul', 'Anurag Priyam',
                   'Yannick Wurm']
  s.email       = 'y.wurm@qmul.ac.uk'
  s.homepage    = 'https://wurmlab.github.io/tools/genevalidator/'
  s.license     = 'AGPL'
  s.summary     = 'Identifying problems with gene predictions.'
  s.description = 'The tool validates the input predicted genes and provides' \
                  ' useful information (length validation, gene merge' \
                  ' validation, sequence duplication checking, ORF finding)' \
                  ' based on the similarities to genes in public databases.'
  s.required_ruby_version = '>= 2.2.0'

  s.add_development_dependency 'minitest', '~> 5.10'
  s.add_development_dependency 'rake', '~> 12.3'
  s.add_development_dependency 'yard', '~> 0.9.11'

  s.add_dependency 'bio', '~> 1.4'
  s.add_dependency 'bio-blastxmlparser', '~> 2.0'
  s.add_dependency 'genevalidatorapp', '~> 2.0'
  s.add_dependency 'rack', '~> 2.0'
  s.add_dependency 'statsample', '2.1.0'

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.post_install_message = <<INFO

----------------------------------------------------------------------------
Thank you for validating your gene predictions with GeneValidator!

==> To launch GeneValidator execute 'genevalidator' from command line.

        genevalidator [OPTIONAL ARGUMENTS] INPUT_FILE

    See 'genevalidator --help' for more information

==> To launch GeneValidator as a web application execute 'genevalidator' from command line.

        genevalidator app [OPTIONAL ARGUMENTS]

    See 'genevalidator app --help' for more information

==> Visit https://wurmlab.github.io/tools/genevalidator/ for more information.

----------------------------------------------------------------------------

INFO
end
