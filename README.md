GeneValidatorValidator
======================

###How to use the scripts:

Compare scores from two datasets
```$ ruby statistics_compare.rb YAML_FILE1 [YAML_FILE2] [NEE]```

Plot the score difference between corrsponding (by identifier) predictions from two genome versions
```$ ruby statistics_pairs.rb YAML_FILE_v1 YAML_FILE_v2 FASTA_v1 FASTA_v2 ```

Plot the score difference between corrsponding predictions (by reciprocal blast) from two genome versions
```$ makeblastdb -in file.fasta -dbtype prot -title Title -out DB_v2 ```
```$ ruby statistics_pairs_reciprocal_blast.rb YAML_FILE_v1 YAML_FILE_v2 FASTA_v1 DB_v2```
