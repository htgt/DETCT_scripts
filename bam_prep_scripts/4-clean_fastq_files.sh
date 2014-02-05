#!/bin/bash
# Remove tags and polyT and trim reads
run_lane=$RUN_LANE

echo "First checking merging FASTQ jobs ran OK for $run_lane"
num_jobs=2
succ_jobs=`grep -l 'Successfully completed' $run_lane/*.merge_fastq.o | wc -l`
fail_jobs=`grep -l 'Exited' $run_lane/*.merge_fastq.o | wc -l`

if [ "$fail_jobs" -gt 0  ]; then 
    echo "We have $fail_jobs failed merge FASTQ jobs, can not continue"
    exit 1
elif [ "$num_jobs" -gt "$succ_jobs" ]; then
    echo "$succ_jobs / $num_jobs completed, try again later"
    exit 1
fi

echo "Merging FASTQ jobs completed successfully"
echo "Deleting extracted FASTQ files for $run_lane"
rm $run_lane/*/*.fastq

echo "Detagging and trimming FASTQ file for $run_lane"
bsub -o $run_lane/detag.o -e $run_lane/detag.e \
-R'select[mem>1000] rusage[mem=1000]' -M1000 \
perl \
-I/software/team31/perl/lib/perl5 \
-I/software/team31/packages/DETCT/lib \
/software/team31/packages/DETCT/script/detag_fastq.pl \
--fastq_read1_input $run_lane/$run_lane.1.fastq \
--fastq_read2_input $run_lane/$run_lane.2.fastq \
--fastq_output_prefix $run_lane/$run_lane \
--read_tags \
NNNNBGAGGC NNNNBAGAAG NNNNBCAGAG \
NNNNBGCACG NNNNBCGCAA NNNNBCAAGA \
NNNNBGCCGA NNNNBCGGCC NNNNBAACCG \
NNNNBACGGG NNNNBCCAAC NNNNBAGCGC

