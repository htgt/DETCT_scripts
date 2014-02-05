#!/bin/bash
# Run BWA aln
run_lane=$RUN_LANE

echo "First checking split FASTQ jobs ran OK for $run_lane"
num_jobs=`find $run_lane | grep fastq$ | grep -E 'XXXX|NNNN' | wc -l`
succ_jobs=`grep -l 'Successfully completed' $run_lane/*/split.o | wc -l`
fail_jobs=`grep -l 'Exited' $run_lane/*/split.o | wc -l`

if [ "$fail_jobs" -gt 0  ]; then 
    echo "We have $fail_jobs failed split FASTQ jobs, can not continue"
    exit 1
elif [ "$num_jobs" -gt "$succ_jobs" ]; then
    echo "$succ_jobs / $num_jobs completed, try again later"
    exit 1
fi

echo "Split FASTQ jobs completed successfully"

echo "Deleting all FASTQ files except split ones for $run_lane"
find $run_lane | grep fastq$ | xargs rm

echo "Running BWA aln for $run_lane"
ls $run_lane/*/* | grep -v split | xargs -ixxx \
bsub -o xxx.bwaaln.o -e xxx.bwaaln.e \
-R'select[mem>4000] rusage[mem=4000]' -M4000 \
/software/team31/bin/bwa-0.5.10-mt_fixes aln \
-f xxx.sai \
/lustre/scratch109/srpipe/references/Mus_musculus/GRCm38/all/bwa/Mus_musculus.GRCm38.68.dna.toplevel.fa \
xxx
