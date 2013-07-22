Gem::Specification.new do |s|
  # meta
  s.name        = 'GeneValidatior'
  s.date        = '2013-07-22'
  s.version     = '0.1'
  s.authors     = ['Monica Dragan', 'Yannick Wurm', 'Anurag Priyam']
  s.email       = 'monica.dragan@cti.pub.ro'
  s.homepage    = 'https://github.com/monicadragan/gene_prediction/'

  s.summary     = 'Identifying problems with gene predictions.'
  s.description = <<DESC
The tool validates the input predicted genes and provides useful information (length validation, gene merge validation, sequence duplication checking, ORF finding) based on the similarities to genes in public databases.
DESC

  # dependencies
#  spec.required_ruby_version     = '>= 1.9.3'

  s.add_dependency('bio-blastxmlparser')
  s.add_dependency('rinruby')

#  s.files       = ["lib/genevalidator.rb"]
  s.files       = ["lib/genevalidator.rb"] + Dir['lib/**/*']
  # gem
#  s.files         = Dir['lib/*'] + Dir['data/**/*'] + Dir['results/**/*'] + Dir['tests/*']
#  s.files         = s.files + ['README.txt']
#  s.files         = s.files + ['genevalidator.gemspec']
  s.executables   = ['genevalidator']
#  s.require_paths = ['lib']

  # post install information
  s.post_install_message = <<INFO

------------------------------------------------------------------------
  Thank you for validating your gene predictions with GeneValidator!

  To launch SequenceServer execute 'genevalidator' from command line.

    $ genevalidatior -t TYPE [-s START] [--outfmt html|yaml] [--skip_blast xml_file_path] fasta_file_path

  This is a GSoC project. 
  Visit https://github.com/monicadragan/gene_prediction/wiki for more information.
------------------------------------------------------------------------

INFO
end
