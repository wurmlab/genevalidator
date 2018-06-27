# Running GeneValidator with sample data

Here, we walk through the steps involved in analysing some sample data with GeneValidator. There are two options on how to run genevalidator - the second option is faster with larger input files.

## Expected Results

<strong>protein_data.fa</strong> [See here](http://wurmlab.github.io/tools/genevalidator/examplar_data/protein_input/)
<strong>mrna_data.fa</strong> [See here](http://wurmlab.github.io/tools/genevalidator/examplar_data/genetic_input/)

##### Running GeneValidator with a the included SwissProt Database, with four threads

```bash
# Protein data
$ genevalidator -n 4 protein_data.fa

# MRNA data
$ genevalidator -n 4 mrna_data.fa
```

This will produce a folder that will contain your result files.

##### Running GeneValidator with a pre-computed BLAST XML file

For protein_data.fa:

```
blastp -db DATABASE_PATH -num_threads 4 -out protein_data.blast.xml -query protein_data.fa -outfmt 5

# Run GeneValidator
genevalidator -d DATABASE_PATH -n 4 -x protein_data.blast.xml protein_data.fa
```

For mrna_data.fa:

```
blastx -db DATABASE_PATH -num_threads 4 -out mrna_data.blast.xml -query mrna_data.fa -outfmt 5

# Run GeneValidator
genevalidator -d DATABASE_PATH -n 4 -x mrna_data.blast.xml mrna_data.fa
```

##### Running GeneValidator with a pre-computed BLAST tabular file

For protein_data.fa:

```
blastp -db DATABASE_PATH -num_threads 4 -out protein_data.blast.tsv -query protein_data.fa -outfmt '7 qseqid sseqid sacc slen qstart qend sstart send length qframe pident nident evalue qseq sseq'

# Run GeneValidator
genevalidator -d DATABASE_PATH -n 4 -t protein_data.blast.tsv --blast_tabular_options 'qseqid sseqid sacc slen qstart qend sstart send length qframe pident nident evalue qseq sseq' protein_data.fa
```

For mrna_data.fa:

```
blastp -db DATABASE_PATH -num_threads 4 -out mrna_data.blast.tsv -query mrna_data.fa -outfmt '7 qseqid sseqid sacc slen qstart qend sstart send length qframe pident nident evalue qseq sseq'

# Run GeneValidator
genevalidator -d DATABASE_PATH -n 4 -t mrna_data.blast.tsv --blast_tabular_options 'qseqid sseqid sacc slen qstart qend sstart send length qframe pident nident evalue qseq sseq' mrna_data.fa
```
