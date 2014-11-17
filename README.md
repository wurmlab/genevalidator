# GeneValidator - Identify problems with predicted genes 

[![Build Status](https://travis-ci.org/monicadragan/GeneValidator.svg?branch=alpha)](https://travis-ci.org/monicadragan/GeneValidator)
[![Gem Version](https://badge.fury.io/rb/GeneValidator.svg)](http://badge.fury.io/rb/GeneValidator)
[![Dependency Status](https://gemnasium.com/3b0e5081b7f0b8dc4b849d0c35a5f864.svg)](https://gemnasium.com/b7eac83bbd785b15275259cb66babff1)
[![Scrutinizer Code Quality](https://scrutinizer-ci.com/g/IsmailM/GeneValidator/badges/quality-score.png?b=alpha)](https://scrutinizer-ci.com/g/IsmailM/GeneValidator/?branch=alpha)

## Introduction
The goal of GeneValidator is to identify problems with gene predictions and provide useful information based on the similarities to genes in public databases. The results produced will make provide evidence on how sequencing curation may be done and will be useful in improving or trying out new approaches for gene prediction tools. The main target of this tool are biologists who wish to validate the data produced in their labs.

### Citation
If you use GeneValidator in your work, please cite us as follows:

"Dragan M, Moghul MI, Priyam A & Wurm Y (<em>in prep.</em>) GeneValidator: identify problematic gene predictions"


### Validations
GeneValidator currently carries out a number of validations which include:
* Length validation by clusterization (a graph is dynamically produced)
* Length validation by ranking
* Check gene merge (a graph is dynamically produced)
* Check duplications
* Reading frame validation (for nucleotides)
* Main ORF validation (for nucleotides) (a graph is dynamically produced)
* Validation based on multiple alignment (a graph is dynamically produced)

### Resources

* [Full Documentation](http://swarm.cs.pub.ro/~mdragan/gsoc2013/genevalidator/all_validations_prot.fasta.html/doc/about.html)
* [Blog](http://gene-prediction.blogspot.ro/)
* [Output](http://swarm.cs.pub.ro/~mdragan/gsoc2013/genevalidator/)

## Installation Requirements
* Ruby (>= 1.9.3)
* NCBI BLAST+ (>= 2.2.25+)
* MAFFT installation (download it from : http://mafft.cbrc.jp/alignment/software/ ).<br>
Linux and MacOS are officially supported!
* Mozilla FireFox - In order to dynamically produce graphs for some of the validation, GeneValidator relies on dependency called 'd3'. Unfortunately, at this moment of time, d3 only works in Firefox.


## Installation
1. Type the following command in the terminal

```bash
$ gem install GeneValidator
```


## Usage 
1. After installing, GeneValidator can be run by typing the following command in the terminal

```bash

USAGE:
    $ genevalidator [OPTIONS] INPUT_FILE

ARGUMENTS:
    INPUT_FILE: Path to the input FASTA file containing the predicted sequences.

OPTIONAL ARGUMENTS:

    -v, --validations <String>       The Validations to be applied.
                                     Validation Options Available (separated by coma):
                                       all    = run all validations (default)
                                       lenc   = length validation by clusterization
                                       lenr   = length validation by ranking
                                       frame  = reading frame validation
                                       merge  = check gene merge
                                       dup    = check duplications
                                       orf    = main ORF validation (applicable for nucleotides)
                                       align  = validation based on multiple alignment
                                       codons = codon coverage ~ under development
    -d, --db [BLAST_DATABASE]        base where to look up the sequences
                                     e.g. "swissprot -remote" or a local BLAST database
    -x, --skip_blast [FILENAME]      Skip blast-ing part and provide a blast xml or tabular output
                                     as input to this script.
                                     Only BLAST xml (BLAST -outfmt 5) or basic tabular (BLAST -outfmt 6
                                     or 7) outputs accepted
    -t [BLAST OUTFMT STRING],        Custom format used in BLAST -outfmt argument
        --tabular                    Usage:
                                        $ genevalidator -x tabular_file -t "slen qstart qend" INPUT_FILE
                                      See the manual pages of BLAST for more details
    -m, --mafft [MAFFT_PATH]         Path to MAFFT program installation
    -b, --blast [BLAST_PATH]         Path to BLAST+ bin folder
    -r, --raw_seq [FASTA_FILE]       Fasta file containing the raw sequences of each of the BLAST hits in
                                     BLAST XML output file.
        --version                    The version of GeneValidator that you are running.
    -h, --help                       Show this screen.

```

Please type `genevalidator -h` into your terminal to see this information in your terminal. 

## Output
The output produced by GeneValidator is presented in three manners

### HTML Output
Firstly, the output is produced as a colourful, HTML file. This file is titled 'results.html' (found in the 'html' folder) and can be opened in a web browser (please use Mozilla Firefox). This file contains all the results in an easy-to-view manner with graphical visualisations 

### Yaml Output
The output is also produced in YAML. This allows you to reuse the results and all the related global variables within your own programs.

### Terminal Output
Lastly, a summary of the results is also outputted in the terminal to provide quick feedback on the results.
