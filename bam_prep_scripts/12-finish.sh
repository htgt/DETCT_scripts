#!/bin/bash
# Check last job finished
run_lane=$RUN_LANE

echo "Checking re-indexing BAM files ran OK for $run_lane"
num_jobs=`ls $run_lane/*.tag.markdup.bam | wc -l`
succ_jobs=`grep -l 'Successfully completed' $run_lane/*.tag.markdup.index.o | wc -l`
fail_jobs=`grep -l 'Exited' $run_lane/*.tag.markdup.index.o | wc -l`

if [ "$fail_jobs" -gt 0  ]; then 
    echo "We have $fail_jobs re-indexing BAM files failed jobs, can not continue"
    exit 1
elif [ "$num_jobs" -gt "$succ_jobs" ]; then
    echo "$succ_jobs / $num_jobs completed, try again later"
    exit 1
fi

echo "Re-indexing BAM files jobs completed successfully"
