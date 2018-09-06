# GeneValidator - Identify problems with predicted genes
[![Build Status](https://travis-ci.org/wurmlab/genevalidator.svg?branch=master)](https://travis-ci.org/wurmlab/genevalidator)
[![Gem Version](https://badge.fury.io/rb/genevalidator.svg)](http://badge.fury.io/rb/genevalidator)
[![Scrutinizer Code Quality](https://scrutinizer-ci.com/g/wurmlab/GeneValidator/badges/quality-score.png?b=master)](https://scrutinizer-ci.com/g/wurmlab/GeneValidator/?branch=master)
[![Test Coverage](https://codeclimate.com/github/wurmlab/GeneValidator/badges/coverage.svg)](https://codeclimate.com/github/wurmlab/GeneValidator)




## Introduction
GeneValidator helps in identifing problems with gene predictions and provide useful information extracted from analysing orthologs in BLAST databases. The results produced can be used by biocurators and researchers who need accurate gene predictions.

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
sh -c "$(curl -fsSL https://install-genevalidator.wurmlab.com)"
```

By default this will install in a folder called `genevalidator` in your current folder. If you wish to have GeneValidator installed in a different location, add the path to the end of the above install line. For example to install GeneValidator in a hidden folder in your home path

```bash
sh -c "$(curl -fsSL https://install-genevalidator.wurmlab.com)" ~/.genevalidator
```

NOTE: [https://install-genevalidator.wurmlab.com](https://install-genevalidator.wurmlab.com) redirects to [https://raw.githubusercontent.com/wurmlab/genevalidator/master/install.sh](https://raw.githubusercontent.com/wurmlab/genevalidator/master/install.sh).

Alternatively download and compress the standalone package from our [releases](https://github.com/wurmlab/genevalidator/releases/latest) page.

The produced folder contains the following:

```bash
Readme.txt      # See Readme for version and basic usage information
bin/            # bin folder for genevalidator, BLAST+ and JQ (can add to $PATH)
blast_db/       # contains the SWISSPROT BLAST database.
exemplar_data/  # contains exemplar mrna and protein fasta files
lib/            # contains genevalidator dependencies
```

## Usage

GeneValidator can be run immediately after the GeneValidator package has been downloaded and uncompressed.

```bash
genevalidator -h
```

You should see the following output.

```bash
SUMMARY:
  GeneValidator - Identify problems with predicted genes

USAGE:
  genevalidator [OPTIONAL ARGUMENTS] INPUT_FILE

  To run as a web application:

    genevalidator app [OPTIONAL ARGUMENTS]

    See 'genevalidator app --help' for more information

OPTIONAL ARGUMENTS

        --validations [VALIDATIONS]  The Validations to be applied.
                                     Validation Options Available (separated by comma):
                                       all   = All validations (default),
                                       lenc  = Length validation by clusterization,
                                       lenr  = Length validation by ranking,
                                       merge = Analyse gene merge,
                                       dup   = Check for duplications,
                                       frame = Open reading frame (ORF) validation,
                                       orf   = Main ORF validation,
                                       align = Validating based on multiple alignment
    -d, --db [PATH]                  Path to the BLAST database
                                     e.g.   genevalidator -d /path/to/databasa.fa Input_File
                                     GeneValidator also supports remote databases:
                                     e.g.   genevalidator -d "swissprot -remote" Input_File
    -s, --select_single_best         Writes the fasta sequence of the best scoring gene to STDOUT.

# OUTPUT ARGUMENTS

    -o, --output_dir [PATH]          Path to the output folder.
                                     By default the output folder is in the same directory as the input
                                     file and is named as input filename, followed by the time of
                                     analysis
    -f, --force_rewrite              Rewrites over existing output.
        --output_formats [STRING]    Output Formats to generate. This can be either: "all", "html",
                                     "csv", "json", "summary" or "stdout". Multiple formats can be
                                     separated by a semi-colon e.g. "csv:json".
                                     By default, all output formats are generated.

# BLAST ARGUMENTS

        --min_blast_hits_required [NUM]
                                     The minimum number of BLAST hits required by GeneValidator in order
                                     to carry out validations. Note: certain validations have their own
                                     set minimum (such as the multiple alignment validation, which
                                      requires a minimum of 10 BLAST hits)
    -b, --blast_options [STRING]     A string that is to passed to BLAST
    -x, --blast_xml_file [PATH]      Provide GeneValidator with a pre-computed BLAST XML output
                                     file (BLAST -outfmt option 5).
    -t, --blast_tabular_file [PATH]  Provide GeneValidator with a pre-computed BLAST tabular output
                                     file. (BLAST -outfmt option 6).
        --blast_tabular_options [STRING]
                                     Custom format used in BLAST -outfmt argument
                                     See BLAST+ manual pages for more details
        --raw_sequences [PATH]       Supply a fasta file of the raw sequences of all BLAST hits present
                                     in the supplied BLAST XML or BLAST tabular file.

# EXTRACT RAW SEQUENCES ARGUMENTS

    -e, --extract_raw_seqs           Extract a fasta file of the raw sequences of BLAST hits in the
                                     supplied BLAST output file. This fasta file can then be provided to
                                     GeneValidator with the "--raw_sequences" argument

# REPROCESS JSON ARGUMENTS

    -j, --json_file [JSON_FILE]      Path to json file. Re-generate the HTML report from a (filtered)
                                     JSON file that was previously produced by GeneValidator

# GENERAL ARGUMENTS

    -n, --num_threads [THREADS]      Specify the number of processor threads to use when running
                                     BLAST and GeneValidator.
    -m, --mafft_threads [THREADS]    Specify the number of processor threads to use when running
                                     Mafft. Note Mafft is run independently in each of the threads
                                     specified in --num_threads.
    -r, --resume [DIR]               Resumes an analysis. This works by using previously generated
                                     temporary files instead of recomputing the analysis where possible.
                                     A new output directory is created where the output files are
                                     generated. This assumes that the input file is the same as that
                                     used in the analysis you are resuming from.
        --bin [DIR]                  Path to BLAST and MAFFT bin folders (is added to $PATH variable)
                                     To be provided as follows:
                                     e.g.   genevalidator --bin /blast/bin/ --bin /mafft/bin/
    -h, --help                       Show this screen.
    -v, --version                    The version of GeneValidator that you are running.
```

## Example Usage Scenarios

#### Simplest Usage (using included SWISSPROT database)
This runs BLAST on the included SwissProt BLAST database.

```bash
genevalidator INPUT_FASTA_FILE
```

#### Using an alternative BLAST database
GeneValidator requires a protein BLAST database in order to fully analyse all sequences. The BLAST database needs to be set up with the `-parse_seqids` argument of the makeblastdb script from BLAST+ (from Genevalidator Package, in the bin directory). See [this page](https://gist.github.com/IsmailM/3e3519de18c5b8b36d8aa0f223fb7948) for more information on how to set up BLAST databases.

```bash
genevalidator -d DATABASE_PATH -n NUM_THREADS INPUT_FASTA_FILE
```

#### Running BLAST separately
At times, it may be more suitable to run the resource-heavy BLAST separately and then pass the BLAST output file to GeneValidator. This may be the case if one is analysing a large number of input sequence and would like to run the time- and resource-consuming BLAST process on a faster machine (i.e a cluster).

GeneValidator supports the XML and tabular BLAST output formats.

```bash
# Run BLAST (XML output)
blast(p/x) -db DATABASE_PATH -num_threads NUM_THREADS -outfmt 5 -out BLAST_XML_FILE -query INPUT_FASTA_FILE

# Run GeneValidator
genevalidator -d DATABASE_PATH -n NUM_THREADS -x BLAST_XML_FILE INPUT_FASTA_FILE
```

This is the same, but using the BLAST tabular output.

```bash
# Run BLAST (tabular output)
blast(p/x) -db DATABASE_PATH -num_threads NUM_THREADS -outfmt '7 qseqid sseqid sacc slen qstart qend sstart send length qframe pident nident evalue qseq sseq' -out BLAST_TAB_FILE -query INPUT_FASTA_FILE

# Run GeneValidator
genevalidator -n NUM_THREADS -t BLAST_TAB_FILE -o 'qseqid sseqid sacc slen qstart qend sstart send length qframe pident nident evalue qseq sseq' INPUT_FASTA_FILE
```




## Output
The output produced by GeneValidator is presented in four manners.

#### HTML Output
Firstly, the output is produced as a colourful, HTML file. This file is titled 'results.html' (found in the 'html' folder) and can be opened in a web browser (please use a supported browser - See [Installation Requirements](#installation-requirements)). This file contains all the results in an easy-to-view manner with graphical visualisations. See exemplar HTML output [here](http://wurmlab.github.io/tools/genevalidator/exemplar_data/protein_input/) (protein input data) and [here](http://wurmlab.github.io/tools/genevalidator/exemplar_data/genetic_input/) (DNA input data).


#### CSV Output
The output table is also presented in the CSV format for programmatic or spreadsheet (i.e. Microsoft Excel) access.


#### JSON Output
The output is also produced in JSON. GeneValidator is able to re-generate results for any JSON files (or derived JSON files) with that were previously generated by the program. This means that you are able to use the JSON file in your own analysis pipelines and then use GeneValidator to produce the HTML output for the analysed JSON file.

#### Terminal Output
Lastly, a tabular summary of the results is also outputted in the terminal to provide quick feedback on the results. The terminal output can be piped to tools like `awk` and `sed` or redirected to a file for further processing.





## Using the JSON output

JSON output can be filtered or processed in a variety of ways using standard tools, such as the [streamable JSON command line program](http://trentm.com/json/), or [jq](https://stedolan.github.io/jq/). The examples below makes use of jq 1.5 which is bundled with GeneValidator.

```bash
# Requires jq 1.5

# Extract sequences that have an overall score of 100
$ jq '.[] | select(.overall_score == 100)' INPUT_JSON_FILE > OUTPUT_JSON_FILE

# Extract sequences that have an overall score of over 70
$ jq '.[] | select(.overall_score == 70)' INPUT_JSON_FILE > OUTPUT_JSON_FILE

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

