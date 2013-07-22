GSoC 2013 project: Identify problems with predicted genes
===============

Details about the project's progress during the **Community Bonding period** can be found [here](https://github.com/monicadragan/gene_prediction/wiki/Community-Bonding).<br>
Details about the project's progress during the **Coding period** can be found [here](https://github.com/monicadragan/gene_prediction/wiki/Project-Diary).<br>
We also have a [blog](http://gene-prediction.blogspot.ro/).
<br><br>

**Look forward to showing you a functional application soon!**<br>
Meanwhile, you can [clone](https://github.com/monicadragan/gene_prediction) the last functional version of the application and read more about the project. <br>
**Your feedback is welcome!**

### Authors

* GSoC student: [Monica Dragan](swarm.cs.pub.ro/~mdragan/gsoc2013/Monica_Dragan_CV.pdf) ([email](mailto:monica.dragan@cti.pub.ro))
* Mentors: [Anurag Priyam](https://plus.google.com/114122400102590087616/about)([email](mailto:anurag08priyam@gmail.com)) and [Yannick Wurm](http://yannick.poulet.org/)([email](mailto:y.wurm@qmul.ac.uk))

### Abstract

The goal of the project is to validate predicted genes by computing a confidence score and suggesting possible errors / untrusted regions in the sequence. The results of the prediction validation will make evidence about how the sequencing curation may be done and can be useful in improving / trying new approaches for gene prediction tools. The main target users of this tool are the Biologists who want to validate the data obtained in their own laboratories.

### Background and Approach

Genome sequencing is now possible at almost no cost. However, obtaining accurate gene predictions remains a target hard to achieve with the existing biotechnology. The goal of this project is to create a tool  that identifies potential problems with the predicted genes, in order to make evidence about how the gene curation can be made or whether a certain predicted gene may not be considered in other analysis. Also, the prediction validation could be used for improving the results of the existing gene prediction tools.

The application takes as input a collection of mRNA / protein predictions (called **predicted sequences**) and identifies potential problems with each sequence, by matching and comparing them with sequences available in trusted databases (called **reference sequences**). The tool will determine if the following errors appear in the predicted sequence: 
* whether the predicted sequence does not have an acceptable length, according to the reference sequence set.
* the occurrence of gaps or extra sections in the predicted sequence, according to the reference sequence set.
* some of the conserved regions among the reference sequence are absent in the predicted sequence.

The main target users of this tool are the Biologists who want to validate the data obtained in their own laboratories. The application will be be easily installable as a RubyGem.

_More details can be found in the project's [proposal](http://www.google-melange.com/gsoc/proposal/review/google/gsoc2013/mdragan/11001)._



 

