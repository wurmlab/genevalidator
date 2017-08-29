# GeneValidator - Identify problems with predicted genes
[![Build Status](https://travis-ci.org/wurmlab/genevalidator.svg?branch=master)](https://travis-ci.org/wurmlab/genevalidator)
[![Gem Version](https://badge.fury.io/rb/genevalidator.svg)](http://badge.fury.io/rb/genevalidator)
[![Scrutinizer Code Quality](https://scrutinizer-ci.com/g/wurmlab/GeneValidator/badges/quality-score.png?b=master)](https://scrutinizer-ci.com/g/wurmlab/GeneValidator/?branch=master)
[![Test Coverage](https://codeclimate.com/github/wurmlab/GeneValidator/badges/coverage.svg)](https://codeclimate.com/github/wurmlab/GeneValidator)




## Introduction
GeneValidator helps in identifing problems with gene predictions and provide useful information extracted from analysing orthologs in BLAST databases. The results produced can be used by biocurators and researchers who need accurate gene predictions.

If you would like to use GeneValidator on a few sequences, see our online [GeneValidator Web App](http://genevalidator.sbcs.qmul.ac.uk) - [http://genevalidator.sbcs.qmul.ac.uk](http://genevalidator.sbcs.qmul.ac.uk).


If you use GeneValidator in your work, please cite us as follows:
> [Dragan M<sup>&Dagger;</sup>, Moghul MI<sup>&Dagger;</sup>, Priyam A, Bustos C & Wurm Y. 2016. GeneValidator: identify problems with protein-coding gene predictions. <em>Bioinformatics</em>, doi: 10.1093/bioinformatics/btw015](https://academic.oup.com/bioinformatics/article/32/10/1559/1742817/GeneValidator-identify-problems-with-protein).






## Validations
GeneValidator runs the following validation on all input sequences:

- **Length:** GeneValidator compares the length of the query sequence to the lengths of the most significant BLAST hits using hierarchical clustering and a rank test. This can suggest that the query is too short or too long. Graphs are dynamically produced for this validation.
- **Coverage:** GeneValidator determines whether hit regions match the query sequence more than once using a Wilcoxon test. Significance suggests that the query includes duplicated regions (e.g., resulting from merging of tandem gene duplication).
- **Conserved Regions:** GeneValidator performs multiple alignment of the ten most significant BLAST hits, derive a Position Specific Scoring Matrix Profile, and align this profile to the query. Results of this identify potentially missing or extra regions. Graphs are dynamically produced for this validation.
- **Different genes:** We expect the query sequence to encode a single protein-coding gene. GeneValidator first determines whether the BLAST HSPs map to multiple regions of the query by testing for deviation from unimodality of HSP start and stop coordinates. If this is the case, GeneValidator performs a linear regression between HSP start and stop coordinates (each datapoint is weighted proportionally to the significance of the corresponding HSP). We empirically determined that regression slopes of 0.4 to 1.2 indicate that the query prediction combines two different genes. Graphs are dynamically produced for this validation.

GeneValidator also runs a further two validation on cDNA sequences:

- **Ab initio Open Reading Frame (ORF):** Presence of more than one major ORF occurs in the presence of a frameshift, retained intron, or merged genes.
- **Similarity-based ORFs:** We expect all BLAST hits to align within a single ORF. This test is more sensitive than the previous when a query has many BLAST hits.

Each analysis of each query returns a binary result (good vs. potential problem) according to p-value or an empirically determined cutoff. The results for each query are combined into an overall quality score from 0 to 100. Each analysis of each query returns a binary result (good vs. potential problem) according to p-value or an empirically determined cutoff. The results for each query are combined into an overall quality score from 0 to 100.





## Installation
### Installation Requirements
* Ruby (>= 2.0.0)
* NCBI BLAST+ (>= 2.2.30+) (download [here](http://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download)).
* MAFFT installation (>=7.273) (download [here](http://mafft.cbrc.jp/alignment/software/)).
* A web browser - [Mozilla FireFox](https://www.mozilla.org/en-GB/firefox/new/) & Safari are recommended. At the moment, it is not possible to use Chrome to view the results locally (as chrome does not allow ajax to local files). To avoid this, simply use a different browser (like Firefox or Safari) or start a local server in the results folder.

Please see [here](https://gist.github.com/IsmailM/b783e8a06565197084e6) for more help with installing the prerequisites.

#### Setting up a BLAST database
GeneValidator requires a protein BLAST database in order to fully analyse all sequences. The BLAST database needs to be set up with the `-parse_seqids` argument as follows:

```bash
makeblastdb -in input_db -dbtype prot -parse_seqids
```

### Installation
Simply run the following command in the terminal.

```bash
gem install genevalidator
```

If that doesn't work, try `sudo gem install genevalidator` instead.

##### Running From Source (Not Recommended)
It is also possible to run from source. However, this is not recommended.

```bash
# Clone the repository.
git clone https://github.com/wurmlab/genevalidator.git

# Move into GeneValidator source directory.
cd GeneValidator

# Install bundler
gem install bundler

# Use bundler to install dependencies
bundle install

# Optional: run tests, build documentation and build the gem from source
bundle exec rake

# Run GeneValidator.
bundle exec genevalidator -h
# note that `bundle exec` executes GeneValidator in the context of the bundle

# Alternativaly, install GeneValidator as a gem
bundle exec rake install
genevalidator -h
```






## Usage
Verify GeneValidator installed by running the following command in the terminal:

```bash
genevalidator
```

You should see the following output.

```bash
USAGE:
    genevalidator [OPTIONS] Input_File

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
                                     e.g.   genevalidator -d "swissprot -remote" Input_File
    -e, --extract_raw_seqs           Produces a fasta file of the raw sequences of all BLAST hits in the
                                     supplied BLAST output file. This fasta file can then be provided to
                                     GeneValidator with the "-r", "--raw_sequences" argument
    -j, --json_file [JSON_FILE]      Generate HTML report from a JSON file (or a subset of a JSON file)
                                     produced by GeneValidator
    -x [BLAST_XML_FILE],             Provide GeneValidator with a pre-computed BLAST XML output
        --blast_xml_file             file (BLAST -outfmt option 5).
    -t [BLAST_TABULAR_FILE],         Provide GeneValidator with a pre-computed BLAST tabular output
        --blast_tabular_file         file. (BLAST -outfmt option 6).
    -o [BLAST_TABULAR_OPTIONS],      Custom format used in BLAST -outfmt argument
        --blast_tabular_options      See BLAST+ manual pages for more details
    -n, --num_threads num_of_threads Specify the number of processor threads to use when running
                                     BLAST and Mafft within GeneValidator.
    -r, --raw_sequences [raw_seq]    Supply a fasta file of the raw sequences of all BLAST hits present
                                     in the supplied BLAST XML or BLAST tabular file.
    -b, --binaries [binaries]        Path to BLAST and MAFFT bin folders (is added to $PATH variable)
                                     To be provided as follows:
                                     e.g.   genevalidator -b /blast/bin/path/ -b /mafft/bin/path/
        --version                    The version of GeneValidator that you are running.
    -h, --help                       Show this screen.
```





## Example Usage Scenarios

#### Simplest Usage (using NCBI remote BLAST servers)
This runs BLAST on NCBI remote Swiss-Prot BLAST database. As such this is suitable for analyses on less than 10 sequences.

```bash
genevalidator INPUT_FASTA_FILE
```

#### Using a local BLAST database.
GeneValidator would run BLAST (using an E-Value 1e-5) on each query against the provided BLAST database and then run the validation analyses.

```bash
genevalidator -d DATABASE_PATH -n NUM_THREADS INPUT_FASTA_FILE
```

#### Running BLAST separately
At times, it may be more suitable to run the resource-heavy BLAST separately and then pass the BLAST output file to GeneValidator. This may be the case if one is analysing a large number of input sequence and would like to run the time- and resource-consuming BLAST process on a faster machine (i.e a cluster).

GeneValidator supports the XML and tabular BLAST output formats.

```bash
# Run BLAST (XML output)
blast(p/x) -db DATABASE_PATH -num_threads NUM_THREADS -outfmt 5 -out BLAST_XML_FILE -query INPUT_FASTA_FILE

# Optional: Generate a fasta file for the BLAST hits.
# Note: this works best if you use the same database used to create the BLAST OUTPUT file.
genevalidator -d DATABASE_PATH -e -x BLAST_XML_FILE

# Run GeneValidator
## If you ran the previous command (i.e. if you produced fasta file for the BLAST hits)
genevalidator -n NUM_THREADS -x BLAST_XML_FILE -r RAW_SEQUENCES_FILE INPUT_FASTA_FILE

## If you did not run the previous command (this will run the previous command for you)
genevalidator -d DATABASE_PATH -n NUM_THREADS -x BLAST_XML_FILE INPUT_FASTA_FILE
```

This is the same, but using the BLAST tabular output.

```bash
# Run BLAST (tabular output)
blast(p/x) -db DATABASE_PATH -num_threads NUM_THREADS -outfmt '7 qseqid sseqid sacc slen qstart qend sstart send length qframe pident nident evalue qseq sseq' -out BLAST_TAB_FILE -query INPUT_FASTA_FILE

# Optional: Generate a fasta file for the BLAST hits.
# Note: this works best if you use the same database used to create the BLAST OUTPUT file.
genevalidator -d DATABASE_PATH -e -t BLAST_TAB_FILE -o 'qseqid sseqid sacc slen qstart qend sstart send length qframe pident nident evalue qseq sseq'

# Run GeneValidator
## If you ran the previous command (i.e. if you produced fasta file for the BLAST hits)
genevalidator -n NUM_THREADS -t BLAST_TAB_FILE -o 'qseqid sseqid sacc slen qstart qend sstart send length qframe pident nident evalue qseq sseq' -r RAW_SEQUENCES_FILE INPUT_FASTA_FILE

## If you did generate the BLAST hits fasta file (this will run the previous command for you)
genevalidator -d DATABASE_PATH -n NUM_THREADS -t BLAST_TAB_FILE -o 'qseqid sseqid sacc slen qstart qend sstart send length qframe pident nident evalue qseq sseq' INPUT_FASTA_FILE

```




## Output
The output produced by GeneValidator is presented in three manners.

#### HTML Output
Firstly, the output is produced as a colourful, HTML file. This file is titled 'results.html' (found in the 'html' folder) and can be opened in a web browser (please use a supported browser - See [Installation Requirements](#installation-requirements)). This file contains all the results in an easy-to-view manner with graphical visualisations. See exemplar HTML output [here](http://wurmlab.github.io/tools/genevalidator/exemplar_data/protein_input/) (protein input data) and [here](http://wurmlab.github.io/tools/genevalidator/exemplar_data/genetic_input/) (DNA input data).

#### JSON Output
The output is also produced in JSON. GeneValidator is able to re-generate results for any JSON files (or derived JSON files) with that were previously generated by the program. This means that you are able to use the JSON file in your own analysis pipelines and then use GeneValidator to produce the HTML output for the analysed JSON file.

#### Terminal Output
Lastly, a tabular summary of the results is also outputted in the terminal to provide quick feedback on the results. The terminal output can be piped to tools like `awk` and `sed` or redirected to a file for further processing.





## Analysing the JSON output

There are numerous methods to analyse the JSON output including the [streamable JSON command line program](http://trentm.com/json/) or [jq](https://stedolan.github.io/jq/). The below examples use the JSON tool.

### Examplar JSON CLI Installation
After installing node:

```bash
$ npm install -g json
```

### Filtering the results

```bash

# Extract sequences that have an overall score of 100
$ json -f INPUT_JSON_FILE -c 'this.overall_score == 100' > OUTPUT_JSON_FILE

# Extract sequences that have an overall score of over 70
$ json -f INPUT_JSON_FILE -c 'this.overall_score > 70' > OUTPUT_JSON_FILE

# Extract sequences that have more than 50 hits
$ json -f INPUT_JSON_FILE -c 'this.no_hits > 50' > OUTPUT_JSON_FILE

# Sort the JSON based on the overall score (ascending - 0 to 100)
$ json -f INPUT_JSON_FILE -A -e 'this.sort(function(a,b) {return (a.overall_score > b.overall_score) ? 1 : ((b.overall_score > a.overall_score) ? -1 : 0);} );' > OUTPUT_JSON_FILE

# Sort the JSON based on the overall score (decending - 100 to 0)
json -f INPUT_JSON_FILE -A -e 'this.sort(function(a,b) {return (a.overall_score < b.overall_score) ? 1 : ((b.overall_score < a.overall_score) ? -1 : 0);} );' > OUTPUT_JSON_FILE
```

The subsetted/sorted JSON file can then be passed back into GeneValidator (using the `-j` command line argument) to generate the HTML report for the sequences in the JSON file.

```bash
genevalidator -j SORTED_JSON_FILE
```


## Related projects
[GeneValidatorApp](https://github.com/wurmlab/GeneValidatorApp) - A Web App wrapper for GeneValidator.<br>
[GeneValidatorApp-API](https://github.com/wurmlab/GeneValidatorApp-API) - An easy to use API for GeneValidatorApp to allow you to use GeneValidator within your web applications.
