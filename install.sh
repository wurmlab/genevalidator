#!/bin/bash
gem build genevalidator.gemspec
sudo gem install ./GeneValidatior-0.1.gem
rake test
yardoc 'lib/**/*.rb'

