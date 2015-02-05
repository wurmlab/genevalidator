# GeneValidator - Unit Tests

[![Test Coverage](https://codeclimate.com/github/IsmailM/GeneValidator/badges/coverage.svg)](https://codeclimate.com/github/IsmailM/GeneValidator)

Please see below for a summary of the tests that are currently run.

## test_all_validations.rb

* Assert that xml and tabular inputs produce the same output for a protein dataset
* Assert that xml and tabular inputs produce the same output for a mRNA dataset

## test_blast.rb

* Assert that the BLAST Class can detect nucleotide sequence type,
* Assert that the BLAST Class can detect protein sequence type,
* Assert that the BLAST Class raises an error when input types are mixed in the fasta,
* Assert that the BLAST Class can parse xml input
* Assert that the BLAST Class can parse tabular -6 input with default tabular format
* Assert that the BLAST Class can parse tabular -6 input with tabular format as argument
* Assert that the BLAST Class can parse tabular -6 input with mixed columns
* Assert that the BLAST Class can parse tabular -7 input
* Assert that the BLAST Class can remove identical matches among protein sequences
* Assert that the BLAST Class can remove identical matches among nucleotide sequences with tabular input
* Assert that the BLAST Class can remove identical matches among nucleotide sequences with xml input
* Assert that the BLAST Class can return an error when using a nonexisting input file

## test_clusterization.rb

* Assert that during Hierarchical clusterization, it should make clusterization 
* Assert that during Hierarchical clusterization, it should most dense cluster, method 1
* Assert that during Hierarchical clusterization, it should most dense cluster, method 2
* Assert that during Hierarchical clusterization, it should most dense cluster mean

## test_clusterizaion_2d.rb

* Assert that during 2D clusterization, it should calculate the mean of the cluster
* Assert that during 2D clusterization, it should calculate the distance between clusters 
* Assert that during 2D clusterization, it should do clusterization

## test_enumerable.rb

* Assert that the Enumerable Modules works as expected.

## test_sequences.rb

* Assert that the Sequence Class can get sequence by accession for mrna
* Assert that the Sequence Class can get sequence by accession for protein
* Assert that the Sequence Class can initialize seq tabular attributes
* Assert that the Sequence Class can initialize hsp tabular attributes

## test_validation_open_reading_frame.rb

* Assert that the OpenReadingFrameValidation class is able to correctly obtain ORF.

## test_validations.rb

* Assert that the correct number of hits can be derived from the XML file
* Assert that the length by rank validation is able to function correctly
* Assert that the blast reading frame validation is able to function correctly
* Assert that the gene merge validation is able to function correctly
* Assert that the duplication validation is able to function correctly
* Assert that the alignment validation is able to function correctly
* Assert that the open reading frames validation is able to function correctly
