BAM PREP
--------

## Overview
- Take in multiple bam files, one for each tag.
- Merges them all together into 2 large FASTQ files ( one for each of the reads from a paired end reads )
- Detag and trim the FASTQ files.
- Re-align the reads ( aln > sampe > view ), end up with BAM files, one for each tag
- Index BAM files, mark duplicate reads, then re-index

## Notes
This convoluted setup was put in place because originally there was only 1 sample in iRODS
which would be downloaded. This then needed to be split up ( by tags ) so that it could
be sent into the pipeline for analysis.

Now there are multiple samples, I think each sample maps to a tag one to one.
So its probably a lot of the steps below are now not needed and can be taken away.
But its hard to figure out exactly how to to this.

The de-duplication step does still need to be done.

- extra tags,  so we could have 8 samples but 12 tags.
- these tags should only produce minumal alignments, ( check file size of final output bam files )
- tag XXXXXXXXXXX - I think it means stuff where the tag could not be worked out

## Setup
- all run in farm3
- needs lots of storage space, 100GB was not enough when looking at one particular run
    - probably needs 300GB+, and more if we do not delete surplus files as we go along
- process has been split into sequential bash scripts, each normally submits a farm job.
- each script tries to check if the last job was successful:
    - will not run if one or more jobs failed
    - will not run if not all the jobs have completed successfully
- Keep careful track of what step you are on.
    - there is nothing stopping running a job twice or running old jobs again


## Steps

### 0: Initialise
- setup kerberos account ( to authenticate with iRODS )
- setup run and lane we are looking at

### 1: Get BAM files
- Download BAM files for run & lane from iRODS
- ? 1 bam file for each tag in lane I think
- Gets rid of duplicated data
    - only seems a problem in really old runs ( may be able to remove this step )

- Sort BAM files by read name
    - currently done with `samtools sort -n`, with -n flag to sort by read names 
    - Original docs says there is a better can to do this 
    - ? why is this done, maybe because next step requires it

### 2: Extract FASTQ
- Sequence data with more informative headers than normal Fasta files
- Conversion from BAM to FASTQ
- `samtools view` gets all alignments, outputs SAM file
- `picard-tools SamToFastq` used to create FASTQ
    - extracts read sequences and qualities from BAM/SAM files and writes to FASTQ
    - set to output fastq file per read group ( two output files per read group if group is paired )

### 3: Merge FASTQ 
- giant cat command that merges all the seperate FASTQ files into 2 seperate onces ( 1 and 2 )
- paired end reads, so 1 and 2 refer to the read 1 and read 2 of the pair ..

### 4: Clean FASTQ
- detagging and trimming FASTQ files
- runs `DETCT/script/detag_fastq.pl`
- hard coded set of read tags currently
- ? not sure what detagging is ?
- outputs multiple FASTQ files
    - ? I think one for each tag ?

### 5: Split FASTQ
- split the FASTQ files
- looks like it splits on every 30 million lines for each FASTQ file
    - uses regular split command
- ? not sure why, probably to speed up aln step ?

### 6: BWA aln
- runs `bwa aln` on each split fastq file
- uses hardened version of bwa
- running for 3 hours + ..

### 7: BWA sampe
- `sampe` generates alignments in the SAM format given paired-end reads ( takes input from bwa aln )
- sampe output piped to samtools view, outputs BAM files

### 8: Merge BAM 
- users `picard-tools MergeSamFiles` - which merges multiple SAM/BAM files into one
- we will end up with one BAM file for each tag 

### 9: Index BAM 
- use `samtools index`
- index sorted alignment for fast random access

### 10: Mark Duplicates
- uses `picard-tools MarkDuplicates`
- marks or removes duplicate reads that match to the same position in the genome
    - in our case if just marks the duplicates, does not remove them
    - does not mark the 'best' read pair

### 11: Index Bam Again
- Index the BAM files again
- ? Why is this done again? Does it ignore the duplicates now ?

### 12: Finish
- Just check the last step (11) completed
