get GeneValidator to identify problems with predicted genes
===============

This is a GSoC 2013 project.<br>
Details about the project's progress during the **Coding period** can be found [here](https://github.com/monicadragan/gene_prediction/wiki/Project-Diary).<br>
We also have a [blog](http://gene-prediction.blogspot.ro/).<br>
_Please note that some of the functionalities of the tool are still under development. We prepare to finish up by the end of September! So, stay tunned!_
<br><br>

### Authors

* GSoC student: [Monica Dragan](swarm.cs.pub.ro/~mdragan/gsoc2013/Monica_Dragan_CV.pdf) ([email](mailto:monica.dragan@cti.pub.ro))
* Mentors: [Anurag Priyam](https://plus.google.com/114122400102590087616/about)([email](mailto:anurag08priyam@gmail.com)) and [Yannick Wurm](http://yannick.poulet.org/)([email](mailto:y.wurm@qmul.ac.uk))

### Abstract
The goal of GeneValidator is to identify problems with gene predictions and provide useful information based on the similarities to genes in public databases.The results of the prediction validation will make evidence about how the sequencing curation may be done and can be useful in improving / trying new approaches for gene prediction tools. The main target users of this tool are the Biologists who want to validate the data obtained in their own laboratories.

### Actual Validations
* Length validation by clusterization
* Length validation by ranking
* Reading frame validation
* Check gene merge
* Check duplications
* Main ORF validation (for nucleotides)
* Validation based on multiple alignment ~ under development
* Codon coverage ~ under development

### Requirements
Ruby (>= 1.9.3), R (>= 2.14.2), RubyGems (>= 1.3.6), and NCBI BLAST+ (>= 2.2.25+), and MAFFT installation (download it from : http://mafft.cbrc.jp/alignment/software/ ).<br>
Linux and MacOS are officially supported!

### Installation
1. Get the source code<br>
$ git clone git@github.com:monicadragan/gene_prediction.git

2. Be sudo and build the gem<br>
$ sudo rake

3. Run GeneValidation<br>
$ genevalidator type [validations] [skip_blast] [start] FILE 

Example that runs all validations on a set of ant gene predictions:<br>
$ genevalidator -t protein -x data/solenopsis_length_test/prot_Solenopsis_invicta.xml data/solenopsis_length_test/prot_Solenopsis_invicta.fasta

To learn more:<br>
$ genevalidator -h

Outputs:
* validation results in yaml format (the name of the input file with yaml extension) 
* html output with plot visualization (the useful files will be generated in the 'html' directory, at the same path with the input file)<br>
! Note: for the moment check the html output with Firefox browser only.

Other things:

4. Run unit tests
$ rake test

5. Generate documentation
$ rake doc


 


