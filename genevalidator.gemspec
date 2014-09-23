Gem::Specification.new do |s|
  # meta
  s.name        = 'GeneValidator'
  s.date        = '2013-07-22'
  s.version     = '0.1'
  s.authors     = ['Monica Dragan', 'Anurag Priyam', 'Yannick Wurm']
  s.email       = 'monica.dragan@cti.pub.ro'
  s.homepage    = 'https://github.com/monicadragan/GeneValidator'
  s.license     = "GPL"
  s.summary     = 'Identifying problems with gene predictions.'
  s.description = <<DESC
The tool validates the input predicted genes and provides useful information (length validation, gene merge validation, sequence duplication checking, ORF finding) based on the similarities to genes in public databases.
DESC

  # dependencies
# <<<<<<< HEAD
# #  s.required_ruby_version     = '> 1.9.3'

#   s.add_dependency "bio-blastxmlparser", "~>1.1"
#   s.add_dependency "bio", "~> 1.4"
#   s.add_dependency "statsample", "~> 1.3"
#   s.add_dependency "minitest", "~> 5.4"
#   s.add_dependency "shoulda", "~> 3.5"
#   s.add_dependency "mini_shoulda", "~> 0.5"
#   s.add_dependency "rack", "~> 1.5"
# =======
  s.required_ruby_version     = '>= 1.9.3'
  s.add_dependency('bio-blastxmlparser', "~>1.1")
  s.add_dependency('bio', "~> 1.4")
  s.add_dependency('statsample', "~> 1.3")
  s.add_dependency('minitest', "~> 5.3")
  s.add_dependency('shoulda', "~> 3.5")
  s.add_dependency('mini_shoulda', "~> 0.5")
  s.add_dependency('rack', "~> 1.5")
# >>>>>>> upstream/alpha

  s.files       = Dir["test/**/*"] + Dir["aux/**/*"] + Dir['lib/**/*']
  s.executables   = ['genevalidator', 'get_raw_sequences']

  # post install information
  s.post_install_message = <<INFO

------------------------------------------------------------------------
  Thank you for validating your gene predictions with GeneValidator!

  To launch GeneValidator execute 'genevalidator' from command line.

    $ genevalidator [validations] [skip_blast] [start] [tabular] [mafft] [raw_seq] FASTA_FILE

  Visit https://github.com/monicadragan/GeneValidator for more information.
------------------------------------------------------------------------

INFO
end
