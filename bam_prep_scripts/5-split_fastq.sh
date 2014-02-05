#!/bin/bash
# Split FASTQ files
run_lane=$RUN_LANE

echo "First checking clean FASTQ jobs ran OK for $run_lane"
num_jobs=1
succ_jobs=`grep -l 'Successfully completed' $run_lane/detag.o | wc -l`
fail_jobs=`grep -l 'Exited' $run_lane/detag.o | wc -l`

if [ "$fail_jobs" -gt 0  ]; then 
    echo "We have $fail_jobs failed clean FASTQ jobs, can not continue"
    exit 1
elif [ "$num_jobs" -gt "$succ_jobs" ]; then
    echo "$succ_jobs / $num_jobs completed, try again later"
    exit 1
fi

echo "Cleaning FASTQ jobs completed successfully"

echo "Splitting FASTQ files for $run_lane"
find $run_lane | grep fastq$ | grep -E 'XXXX|NNNN' | sed -e 's/.fastq$//' | xargs mkdir
find $run_lane | grep fastq$ | grep -E 'XXXX|NNNN' | sed -e 's/.fastq$//' | xargs -ixxx \
bsub -o xxx/split.o -e xxx/split.e \
split -l 30000000 xxx.fastq xxx/
