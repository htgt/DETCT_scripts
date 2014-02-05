#!/bin/bash
# Index BAM files
run_lane=$RUN_LANE

echo "Checking mark duplicates ran OK for $run_lane"
num_jobs=`ls $run_lane/*.bam | grep -v markdup | wc -l`
succ_jobs=`grep -l 'Successfully completed' $run_lane/*.tag.markdup.o | wc -l`
fail_jobs=`grep -l 'Exited' $run_lane/*.tag.markdup.o | wc -l`

if [ "$fail_jobs" -gt 0  ]; then 
    echo "We have $fail_jobs failed mark duplicates jobs, can not continue"
    exit 1
elif [ "$num_jobs" -gt "$succ_jobs" ]; then
    echo "$succ_jobs / $num_jobs completed, try again later"
    exit 1
fi

echo "Mark duplicates jobs completed successfully"

echo "Indexing BAM files for $run_lane"
ls $run_lane/*.tag.markdup.bam | sed -e 's/.bam$//' | xargs -ixxx \
bsub -o xxx.index.o -e xxx.index.e \
-R'select[mem>1000] rusage[mem=1000]' -M1000 \
/software/team31/bin/samtools index xxx.bam
