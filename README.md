# GeneValidator - Identify problems with predicted genes 
[![Build Status](https://travis-ci.org/wurmlab/genevalidator.svg?branch=master)](https://travis-ci.org/wurmlab/genevalidator)
[![Gem Version](https://badge.fury.io/rb/genevalidator.svg)](http://badge.fury.io/rb/genevalidator)
[![Dependency Status](https://gemnasium.com/wurmlab/GeneValidator.svg)](https://gemnasium.com/wurmlab/GeneValidator)
[![Scrutinizer Code Quality](https://scrutinizer-ci.com/g/wurmlab/GeneValidator/badges/quality-score.png?b=master)](https://scrutinizer-ci.com/g/wurmlab/GeneValidator/?branch=master)
[![Test Coverage](https://codeclimate.com/github/wurmlab/GeneValidator/badges/coverage.svg)](https://codeclimate.com/github/wurmlab/GeneValidator)

## Introduction
The goal of GeneValidator is to identify problems with gene predictions and provide useful information based on the similarities to genes in public databases. The results produced will make provide evidence on how sequencing curation may be done and will be useful in improving or trying out new approaches for gene prediction tools. The main target of this tool are biologists who wish to validate the data produced in their labs.

If you use GeneValidator in your work, please cite us as follows:

"Dragan M, Moghul MI, Priyam A & Wurm Y (<em>in prep.</em>) GeneValidator: identify problematic gene predictions"


#### Related projects 
[GeneValidatorApp](https://github.com/wurmlab/GeneValidatorApp) - A Web App wrapper for GeneValidator.<br>
[GeneValidatorApp-API](https://github.com/wurmlab/GeneValidatorApp-API) - An easy to use API for GeneValidatorApp to allow you to use GeneValidator within your web applications.


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
* Ruby (>= 2.0.0)
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
1) After installing, GeneValidator can be run by typing the following command in the terminal:


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
    -e, --extract_raw_seqs           Produces a fasta file of the raw sequences of all BLAST hits in the
                                     supplied BLAST output file. This fasta file can then be provided to
                                     GeneValidator with the "-r", "--raw_sequences" argument
    -j, --json_file [JSON_FILE]      Generate GV results from a json file (or a subset of a json file)
                                     produced from GeneValidator
    -x [BLAST_XML_FILE],             Provide GeneValidator with a pre-computed BLAST XML output
        --blast_xml_file             file (BLAST -outfmt option 5).
    -t [BLAST_TABULAR_FILE],         Provide GeneValidator with a pre-computed BLAST tabular output
        --blast_tabular_file         file. (BLAST -outfmt option 6).
    -o [BLAST_TABULAR_OPTIONS],      Custom format used in BLAST -outfmt argument
        --blast_tabular_options      See BLAST+ manual pages for more details
    -n, --num_threads num_of_threads Specify the number of processor threads to use when running
                                     BLAST and Mafft within GeneValidator.
    -f, --fast                       Run BLAST on all sequences together (rather than separately)
                                     to speed up the analysis.
                                     However, this means that there will be a longer wait before the
                                     results can be viewed (as GeneValidator will need to run BLAST
                                     on all sequences before producing any results).
                                     The speed difference will be more apparent on larger input files
    -r, --raw_sequences [raw_seq]    Supply a fasta file of the raw sequences of all BLAST hits present
                                     in the supplied BLAST XML or BLAST tabular file.
    -m, --mafft_bin [MAFFT_PATH]     Path to MAFFT bin folder (is added to $PATH variable)
    -b, --blast_bin [BLAST_PATH]     Path to BLAST+ bin folder (is added to $PATH variable)
        --version                    The version of GeneValidator that you are running.
    -h, --help                       Show this screen.
```

Please type `genevalidator -h` into your terminal to see this information in your terminal. 

## Example Usage Scenarios

##### Local Database, with custom number of threads (in this case 8)

```bash
$ genevalidator -d 'Path-to-local-BLAST-db' -n 8 Input_FASTA_File
```
##### Local Database, with the fast mode, with custom number of threads (in this case 8)
Internally, GV will run BLAST on all input sequences before analysing any sequences (instead of running BLAST on each sequence and then analysing the sequence).

```bash
$ genevalidator -d 'Path-to-local-BLAST-db' -n 8 -f Input_FASTA_File
```

##### Local Database, with pre-computed BLAST XML file, with custom number of threads (in this case 8)

```bash
$  blast(p/x) -db SwissProt -out Path-to-XML-file -num_threads 8 -outfmt 5 -query Input_FASTA_File
$  genevalidator -d 'local-or-remote-BLAST-db' -n 8 -x 'Path-to-XML-file' Input_FASTA_File
```

##### Local Database, with pre-computed BLAST XML file, with custom number of threads (in this case 8)

```bash
$ blast(p/x) -db SwissProt -out Path-to-tabular-file -num_threads 8 -outfmt "7 qseqid sseqid sacc slen qstart qend sstart send length qframe pident nident evalue qseq sseq" -query Input_FASTA_File
$ genevalidator -d 'local-or-remote-BLAST-db' -n 8 -t 'Path-to-tabular-file' -o 'qseqid sseqid sacc slen qstart qend sstart send length qframe pident evalue' Input_FASTA_File 
```


## Output
The output produced by GeneValidator is presented in three manners.

#### HTML Output 
Firstly, the output is produced as a colourful, HTML file. This file is titled 'results.html' (found in the 'html' folder) and can be opened in a web browser (please use Mozilla Firefox). This file contains all the results in an easy-to-view manner with graphical visualisations. See exemplar html output [here](http://wurmlab.github.io/tools/genevalidator/exemplar_data/protein_input/) (protein input data) and [here](http://wurmlab.github.io/tools/genevalidator/exemplar_data/genetic_input/) (DNA input data).

#### JSON Output
The output is also produced in JSON. GeneValidator is able to re-generate results for any JSON files (or derived JSON files) with that were previously generated by the program. This means that you are able to use the JSON file in your own analysis pipelines and then use GeneValidator to produce the HTML output for the analysed JSON file.

#### Terminal Output
Lastly, a summary of the results is also outputted in the terminal to provide quick feedback on the results.


## Analysing the JSON output

There are numerous methods to analyse the JSON output including the [streamable JSON command line program](http://trentm.com/json/). The below examples use this tool.

### Examplar JSON CLI Installation
After installing node:

```bash
$ npm install -g json
```

### Filtering the results 

- Extract sequences that have an overall score of 100

```bash
$ json -f INPUT_JSON_FILE -c 'this.overall_score == 100' > OUTPUT_JSON_FILE
```

- Extract sequences that have an overall score of over 70

```bash
$ json -f INPUT_JSON_FILE -c 'this.overall_score > 70' > OUTPUT_JSON_FILE
```

- Extract sequences that have more than 50 hits

```bash
$ json -f INPUT_JSON_FILE -c 'this.no_hits > 50' > OUTPUT_JSON_FILE
```

- Sort the JSON based on the overall score (ascending - 0 to 100)

```bash
$ json -f INPUT_JSON_FILE -A -e 'this.sort(function(a,b) {return (a.overall_score > b.overall_score) ? 1 : ((b.overall_score > a.overall_score) ? -1 : 0);} );' > OUTPUT_JSON_FILE
```

- Sort the JSON based on the overall score (decending - 100 to 0)

```bash
json -f INPUT_JSON_FILE -A -e 'this.sort(function(a,b) {return (a.overall_score < b.overall_score) ? 1 : ((b.overall_score < a.overall_score) ? -1 : 0);} );' > OUTPUT_JSON_FILE
```

## Other Resources

* [Full Documentation](http://wurmlab.github.io/tools/genevalidator/documentation/v1/)
