# GeneValidator - Identify problems with predicted genes 

[![Build Status](https://travis-ci.org/monicadragan/GeneValidator.svg?branch=master)](https://travis-ci.org/monicadragan/GeneValidator)
[![Gem Version](https://badge.fury.io/rb/GeneValidator.svg)](http://badge.fury.io/rb/GeneValidator)
[![Dependency Status](https://gemnasium.com/IsmailM/GeneValidator.svg)](https://gemnasium.com/IsmailM/GeneValidator)
[![Scrutinizer Code Quality](https://scrutinizer-ci.com/g/IsmailM/GeneValidator/badges/quality-score.png?b=alpha)](https://scrutinizer-ci.com/g/IsmailM/GeneValidator/?branch=alpha)
[![Test Coverage](https://codeclimate.com/github/IsmailM/GeneValidator/badges/coverage.svg)](https://codeclimate.com/github/IsmailM/GeneValidator)
[![total downloads](http://ruby-gem-downloads-badge.herokuapp.com/GeneValidator?type=total&color=brightgreen)](https://rubygems.org/gems/GeneValidator)

## Introduction
The goal of GeneValidator is to identify problems with gene predictions and provide useful information based on the similarities to genes in public databases. The results produced will make provide evidence on how sequencing curation may be done and will be useful in improving or trying out new approaches for gene prediction tools. The main target of this tool are biologists who wish to validate the data produced in their labs.

If you use GeneValidator in your work, please cite us as follows:

"Dragan M, Moghul MI, Priyam A & Wurm Y (<em>in prep.</em>) GeneValidator: identify problematic gene predictions"


#### Related projects 
[GeneValidatorApp](https://github.com/IsmailM/GeneValidatorApp) - A Web App wrapper for GeneValidator.<br>
[GeneValidatorApp-API](https://github.com/IsmailM/GeneValidatorApp-API) - An easy to use API for GeneValidatorApp to allow you to use GeneValidator within your web applications.


### Validations
Currently, it is possible to run the following validations with GeneValidator

* Length validation by clusterization (a graph is dynamically produced)
* Length validation by ranking
* Check gene merge (a graph is dynamically produced)
* Check duplications
* Reading frame validation (for nucleotides)
* Main ORF validation (for nucleotides) (a graph is dynamically produced)
* Validation based on multiple alignment (a graph is dynamically produced)

It is also possible to add your own custom validations to GeneValidator. 

## Installation Requirements
* Ruby (>= 1.9.3)
* NCBI BLAST+ (>= 2.2.30+)
* MAFFT installation (download [here](http://mafft.cbrc.jp/alignment/software/)).
* Mozilla FireFox - In order to dynamically produce graphs for some of the validation, GeneValidator relies on dependency called 'd3'. Unfortunately, at this moment of time, d3 only works in Firefox (download [here](https://www.mozilla.org/en-GB/firefox/new/)).

Please see [here](https://gist.github.com/IsmailM/b783e8a06565197084e6) for more help with installing the prerequisites.
  
## Installation
1) Type the following command in the terminal

```bash
$ gem install genevalidator
```


## Usage 
1) After installing, GeneValidator can be run by typing the following command in the terminal

```bash

USAGE:
    $ genevalidator [OPTIONS] Input_File

ARGUMENTS:
    Input_File: Path to the input fasta file containing the predicted sequences.

OPTIONAL ARGUMENTS
    -v, --validations <String>       The Validations to be applied.
                                     Validation Options Available (separated by coma):
                                       all   = All validations (default),
                                       lenc  = Length validation by clusterization,
                                       lenr  = Length validation by ranking,
                                       merge = Analyse gene merge,
                                       dup   = Check for duplications,
                                       frame = Open reading frame (ORF) validation,
                                       orf   = Main ORF validation,
                                       align = Validating based on multiple alignment
    -d, --db [BLAST_DATABASE]        Path to the BLAST database
                                     GeneValidator also supports remote databases:
                                     e.g.   $ genevalidator -d "swissprot -remote" Input_File
    -x, --blast_xml_file [FILE]      Provide GeneValidator with a pre-computed BLAST XML output
                                     file (BLAST -outfmt option 5).
    -t, --blast_tabular_file [FILE]  Provide GeneValidator with a pre-computed BLAST tabular output
                                     file. (BLAST -outfmt option 6).
    -o [Options],                    Custom format used in BLAST -outfmt argument
        --blast_tabular_options      See BLAST+ manual pages for more details
    -n, --num_threads num_of_threads Specify the number of processor threads to use when running
                                     BLAST and Mafft within GeneValidator.
    -f, --fast                       Run BLAST on all sequences together (rather than separately)
                                     to speed up the analysis.
                                     The speed difference is more apparent on larger input files
    -m, --mafft_bin [MAFFT_PATH]     Path to MAFFT bin folder (is added to $PATH variable)
    -b, --blast_bin [BLAST_PATH]     Path to BLAST+ bin folder (is added to $PATH variable)
        --version                    The version of GeneValidator that you are running.
    -h, --help                       Show this screen.


```

Please type `genevalidator -h` into your terminal to see this information in your terminal. 

## Example Usage Scenarios

##### Running GeneValidator with a local Database, with two threads

```bash
$ genevalidator -d 'Path-to-local-BLAST-db' -n 2 Input_File
```

##### Running GeneValidator with a remote Database

```bash
$ genevalidator -d 'swissprot -remote' Input_File
```

##### Running GeneValidator with a pre-computed BLAST XML file


```bash
$  genevalidator -d 'local-or-remote-BLAST-db' -x 'Path-to-XML-file' Input_File
```

##### Running GeneValidator with a pre-computed BLAST tabular file 

```bash
$ genevalidator -d 'local-or-remote-BLAST-db' -t 'Path-to-tabular-file' -o 'qseqid sseqid sacc slen qstart qend sstart send length qframe pident evalue' Input_File 
```

##### Running GeneValidator with the fast option 

```bash
$ genevalidator -d 'Path-to-local-BLAST-db' -n 2 -f Input_File
```

## Output
The output produced by GeneValidator is presented in three manners.

#### HTML Output 
Firstly, the output is produced as a colourful, HTML file. This file is titled 'results.html' (found in the 'html' folder) and can be opened in a web browser (please use Mozilla Firefox). This file contains all the results in an easy-to-view manner with graphical visualisations. See exemplar html output [here](http://wurmlab.github.io/tools/genevalidator/exemplar_data/protein_input/) (protein input data) and [here](http://wurmlab.github.io/tools/genevalidator/exemplar_data/genetic_input/) (genetic input data).

#### Yaml Output
The output is also produced in YAML. This allows you to reuse the results and all the related global variables within your own programs.

#### Terminal Output
Lastly, a summary of the results is also outputted in the terminal to provide quick feedback on the results.

### Other Resources

* [Full Documentation](http://wurmlab.github.io/tools/genevalidator/documentation/v1/)
