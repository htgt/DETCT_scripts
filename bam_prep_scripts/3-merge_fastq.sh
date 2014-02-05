#!/bin/bash
# Merge FASTQ files

run_lane=$RUN_LANE

echo "First checking BAM to FASTQ jobs ran OK for $run_lane"
num_jobs=`ls $run_lane/*.sorted.bam | wc -l`
succ_jobs=`grep -l 'Successfully completed' $run_lane/*.bam2fastq.o | wc -l`
fail_jobs=`grep -l 'Exited' $run_lane/*.bam2fastq.o | wc -l`

if [ "$fail_jobs" -gt 0  ]; then 
    echo "We have $fail_jobs failed BAM to FASTQ jobs, can not continue"
    exit 1
elif [ "$num_jobs" -gt "$succ_jobs" ]; then
    echo "$succ_jobs / $num_jobs completed, try again later"
    exit 1
fi

echo "Completed all $num_jobs jobs successfully"
echo "Deleting sorted BAM files for $run_lane"
#rm $run_lane/*.bam $run_lane/*.bai

echo "Merging FASTQ file for $run_lane"
bsub -o $run_lane/1.merge_fastq.o -e $run_lane/1.merge_fastq.e \
"cat `ls $run_lane/*/*1.fastq | sort | tr '\n' ' '` > $run_lane/$run_lane.1.fastq"
bsub -o $run_lane/2.merge_fastq.o -e $run_lane/2.merge_fastq.e \
"cat `ls $run_lane/*/*2.fastq | sort | tr '\n' ' '` > $run_lane/$run_lane.2.fastq"
