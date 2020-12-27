# GeneValidator - Identify problems with predicted genes

[![Build Status](https://travis-ci.org/wurmlab/genevalidator.svg?branch=master)](https://travis-ci.org/wurmlab/genevalidator)
[![GitHub release](https://img.shields.io/github/release/wurmlab/genevalidator.svg)](https://github.com/wurmlab/genevalidator/releases/latest)

## Introduction

GeneValidator helps in identifying problems with gene predictions and provide useful information extracted from analysing orthologs in BLAST databases. The results produced can be used by biocurators and researchers who need accurate gene predictions.

If you would like to use GeneValidator on a few sequences, see our online [GeneValidator Web App](http://genevalidator.sbcs.qmul.ac.uk) - [http://genevalidator.sbcs.qmul.ac.uk](http://genevalidator.sbcs.qmul.ac.uk).

If you use GeneValidator in your work, please cite us as follows:

> [Dragan M<sup>&Dagger;</sup>, Moghul I<sup>&Dagger;</sup>, Priyam A, Bustos C & Wurm Y. 2016. GeneValidator: identify problems with protein-coding gene predictions. <em>Bioinformatics</em>, doi: 10.1093/bioinformatics/btw015](https://academic.oup.com/bioinformatics/article/32/10/1559/1742817/GeneValidator-identify-problems-with-protein).

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

Run the following in your terminal:

```bash
# Installs in a folder called `genevalidator` in your current folder
sh -c "$(curl -fsSL https://install-genevalidator.wurmlab.com)"

# The above link is redirection to https://raw.githubusercontent.com/wurmlab/genevalidator/master/install.sh

# In order to install in a different location, add the path to the end of the above command
```

Alternatively, the standalone package can be manually downloaded and installed from our [releases](https://github.com/wurmlab/genevalidator/releases/latest) page.

## Usage

GeneValidator can be run immediately after it has been installed. The below example shows how to run GV on the included exemplar data.

```bash
# assuming that installed genevalidator directory is the current working directory
genevalidator --db genevalidator/blast_db/swissprot --num_threads 4 genevalidator/exemplar_data/protein_data.fa
```

Other command line arguments can be viewed by running the following command.

```bash
# This should show the GeneValidator CLI help text
genevalidator -h
```

It is possible run GeneValidator as a web application. This graphical interface can launched by running the following command.

The path to a directory containing one or more blast databases is required - by default this points the blastdb directory in GeneValidator installation containing the SwissProt BLAST database.

```bash
genevalidator app --database_dir genevalidator/blastdb --num_threads 4
```

This will open the default browser at [http://localhost:5678](http://localhost:5678)

Other GeneValidator subcommands include:

```bash
# This is for downloading pre-formatted BLAST database from NCBI
genevalidator ncbi-blast-dbs -h

# This is for creating a local web server for viewing the HTML results.
# This is necessary to view HTML result in certain browsers such as chrome.
# The exact command to run will be shown when opening the HTML result in a browser.
genevalidator serve -h
```

### BLAST databases

GeneValidator's default database is the included Swiss-Prot database, which is used if a BLAST database is not specified. Alternative BLAST databases (such as Uniref50 or the NCBI non-redundant database) can also be used once they have been downloaded and installed. More information on how to download alternative BLAST databases and how to pass BLAST output files to GV can be found [here](https://github.com/wurmlab/genevalidator/wiki/Setting-Up-BLAST-Databases).

## Output

The output produced by GeneValidator is presented in four manners.

#### HTML Output

Firstly, the output is produced as a colourful, HTML file. This file is titled 'results.html' (found in the 'html' folder) and can be opened in a web browser. This file contains all the results in an easy-to-view manner with graphical visualisations. See exemplar HTML output [here](https://wurmlab.github.io/tools/genevalidator/exemplar_data/protein_input/protein_query_results) (Amino acid sequences input) and [here](https://wurmlab.github.io/tools/genevalidator/exemplar_data/genetic_input/genetic_query_results) (Nucleotide sequences input).

#### CSV Output

The output table is also presented in the CSV format for programmatic or spreadsheet (i.e. Microsoft Excel) access. See exemplar CSV output [here](https://wurmlab.github.io/tools/genevalidator/exemplar_data/protein_input/protein_query_results.csv) (Amino acid sequences input) and [here](https://wurmlab.github.io/tools/genevalidator/exemplar_data/genetic_input/genetic_query_results.csv) (Nucleotide sequences input)

#### Summary CSV

A summary CSV file is a 2 column CSV file providing summary statistics on the GV analysis. See exemplar summary CSV output [here](https://wurmlab.github.io/tools/genevalidator/exemplar_data/protein_input/protein_query_summary.csv) (Amino acid sequences input) and [here](https://wurmlab.github.io/tools/genevalidator/exemplar_data/genetic_input/genetic_query_summary.csv) (Nucleotide sequences input)

#### Terminal Output

A tabular summary of the results is also outputted in the terminal to provide quick feedback on the results. The terminal output can be piped to tools like `awk` and `sed` or redirected to a file for further processing.

#### JSON Output

The output is also produced in JSON. GeneValidator is able to re-generate results for any JSON files (or derived JSON files) with that were previously generated by the program. This means that you are able to use the JSON file in your own analysis pipelines and then use GeneValidator to produce the HTML output for the analysed JSON file. See exemplar JSON output [here](https://wurmlab.github.io/tools/genevalidator/exemplar_data/protein_input/protein_query_results.json) (Amino acid sequences input) and [here](https://wurmlab.github.io/tools/genevalidator/exemplar_data/genetic_input/genetic_query_results.json) (Nucleotide sequences input)

###### Exemplar JSON output usage

JSON output can be filtered or processed in a variety of ways using standard tools, such as the [streamable JSON command line program](http://trentm.com/json/), or [jq](https://stedolan.github.io/jq/). The examples below makes use of jq 1.6 which is bundled with GeneValidator.

```bash
# Extract sequences that have an overall score of 100
$ jq '.[] | select(.overall_score == 100)' INPUT_JSON_FILE > OUTPUT_JSON_FILE

# Extract sequences that have an overall score of over 70
$ jq '.[] | select(.overall_score > 70)' INPUT_JSON_FILE > OUTPUT_JSON_FILE

# Extract sequences that have more than 50 hits
$ jq '.[] | select(.no_hits > 50)' INPUT_JSON_FILE > OUTPUT_JSON_FILE

# Sort the JSON based on the overall score (ascending - 0 to 100)
$ jq 'sort_by(.overall_score)' INPUT_JSON_FILE > OUTPUT_JSON_FILE
# Sort the JSON based on the overall score (decending - 100 to 0)
$ jq 'sort_by(- .overall_score)' INPUT_JSON_FILE > OUTPUT_JSON_FILE

# Remove the large graphs objects (note these Graphs objects are required if you wish to pass the json back into GV using the `-j` option - see below)
$ jq --raw-output '[ .[] | del(.validations[].graphs) ]' INPUT_JSON_FILE > OUTPUT_JSON_FILE
```

The subsetted/sorted JSON file can then be passed back into GeneValidator (using the `-j` command line argument) to generate the HTML report for the sequences in the JSON file.

```bash
genevalidator -j OUTPUT_JSON_FILE
```
