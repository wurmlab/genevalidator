Identify problems with predicted genes
===============

This is a GSoC 2013 project.<br>
Details about the project's progress during the **Coding period** can be found [here](https://github.com/monicadragan/gene_prediction/wiki/Project-Diary).<br>
We also have a [blog](http://gene-prediction.blogspot.ro/).<br><br>
<h3><div align = center><font color="blue">Please note that some of the functionalities<br> of this tool are still under development.<br> So, stay tunned!</font></div></h3>
<br><br>

### Authors

* GSoC student: [Monica Dragan](http://swarm.cs.pub.ro/~mdragan/gsoc2013/Monica_Dragan_CV.pdf) ([email](mailto:monica.dragan@cti.pub.ro))
* Mentors: [Anurag Priyam](https://plus.google.com/114122400102590087616/about)([email](mailto:anurag08priyam@gmail.com)) and [Yannick Wurm](http://yannick.poulet.org/)([email](mailto:y.wurm@qmul.ac.uk))

### Abstract
The goal of GeneValidator is to identify problems with gene predictions and provide useful information based on the similarities to genes in public databases.The results of the prediction validation will make evidence about how the sequencing curation may be done and can be useful in improving / trying new approaches for gene prediction tools. The main target users of this tool are the Biologists who want to validate the data obtained in their own laboratories.

### Current Validations
* Length validation by clusterization
* Length validation by ranking
* Reading frame validation
* Check gene merge
* Check duplications
* Main ORF validation (for nucleotides)
* Validation based on multiple alignment ~ under development
* Codon coverage ~ under development

### Requirements
* Ruby (>= 1.9.3)
* RubyGems (>= 1.3.6)
* NCBI BLAST+ (>= 2.2.25+)
* MAFFT installation (download it from : http://mafft.cbrc.jp/alignment/software/ ).<br>
Linux and MacOS are officially supported!

### Installation
1. Get the source code<br>
`$ git clone git@github.com:monicadragan/gene_prediction.git`

2. Be sudo and build the gem<br>
`$ sudo rake`

3. Run GeneValidation<br>
`$ genevalidator [validations] [skip_blast] [start] [tabular] [mafft] [raw_seq] FILE` 

Example that emphasizes all the validations:<br>
`$ genevalidator -x data/all_validations_prot/all_validations_prot.xml data/all_validations_prot/all_validations_prot.fasta`

Learn more:<br>
`$ genevalidator -h`

### Outputs
By running GeneValidator on your dataset you get numbers and plots. Some relevant files will be generated at the same path with the input file. The results are available in 3 formats:
* console table output 
* validation results in YAML format (the YAML file has the same name with the input file + YAML extension) 
* html output with plot visualization (the useful files will be generated in the 'html' directory, at the same path with the input file)<br>
! Note: for the moment check the html output with Firefox browser only !

[Have a look at our results!](http://swarm.cs.pub.ro/~mdragan/gsoc2013/genevalidator)

### Other things

4. Run unit tests<br>
`$ rake test`

5. Generate documentation<br>
`$ rake doc`


 


