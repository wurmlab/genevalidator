Identify problems with predicted genes
===============
<br>
<h3><div align = center><font color="blue">
GSoC13 version of the tool can be found on rubygem branch.<br><br> This is the alpha version of GeneValidator.<br> We continue the development.<br> So, stay tunned!


</font></div></h3>
<br><br>

### Authors

* GSoC student: [Monica Dragan](http://swarm.cs.pub.ro/~mdragan/gsoc2013/Monica_Dragan_CV.pdf) ([email](mailto:monica.dragan@cti.pub.ro))
* Mentors: [Anurag Priyam](https://plus.google.com/114122400102590087616/about)([email](mailto:anurag08priyam@gmail.com)) and [Yannick Wurm](http://yannick.poulet.org/)([email](mailto:y.wurm@qmul.ac.uk))

### Resources

* [Full Documentation](http://swarm.cs.pub.ro/~mdragan/gsoc2013/genevalidator/all_validations_prot.fasta.html/doc/about.html)
* [Blog](http://gene-prediction.blogspot.ro/)
* [Output](http://swarm.cs.pub.ro/~mdragan/gsoc2013/genevalidator/)
<br>

### Abstract
The goal of GeneValidator is to identify problems with gene predictions and provide useful information based on the similarities to genes in public databases.The results of the prediction validation will make evidence about how the sequencing curation may be done and can be useful in improving / trying new approaches for gene prediction tools. The main target users of this tool are the Biologists who want to validate the data obtained in their own laboratories.

### Current Validations
* Length validation by clusterization
* Length validation by ranking
* Check gene merge
* Check duplications
* Reading frame validation (for nucleotides)
* Main ORF validation (for nucleotides)
* Validation based on multiple alignment
* Codon coverage ~ under development

### Requirements
* Ruby (>= 1.9.3)
* RubyGems (>= 1.3.6)
* NCBI BLAST+ (>= 2.2.25+)
* MAFFT installation (download it from : http://mafft.cbrc.jp/alignment/software/ ).<br>
Linux and MacOS are officially supported!

### Installation
1. Get the source code<br>
`$ git clone git://github.com/monicadragan/GeneValidator.git`

2. Be sudo and build the gem<br>
`$ sudo rake`

3. Run GeneValidation<br>
`$ genevalidator [validations] [skip_blast] [start] [tabular] [mafft] [raw_seq] FASTA_FILE` 

Example that emphasizes all the validations:<br>
`$ genevalidator -x data/all_validations_prot/all_validations_prot.xml data/all_validations_prot/all_validations_prot.fasta`

Learn more:<br>
`$ genevalidator -h`

Uninstall GeneValidator: <br>
`$ sudo gem uninstall GeneValidator `

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


 


