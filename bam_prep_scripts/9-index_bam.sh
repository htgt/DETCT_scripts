#!/bin/bash
# Index BAM files
run_lane=$RUN_LANE

echo "Checking merging BAM files ran OK for $run_lane"
num_jobs=`ls -d $run_lane/*_1/ | grep -E 'XXXX|NNNN' | wc -l`
succ_jobs=`grep -l 'Successfully completed' $run_lane/*/merge.o | wc -l`
fail_jobs=`grep -l 'Exited' $run_lane/*/merge.o | wc -l`

if [ "$fail_jobs" -gt 0  ]; then 
    echo "We have $fail_jobs failed merging BAM files jobs, can not continue"
    exit 1
elif [ "$num_jobs" -gt "$succ_jobs" ]; then
    echo "$succ_jobs / $num_jobs completed, try again later"
    exit 1
fi

echo "Merge BAM files jobs completed successfully"

echo "Deleting intermediate files for $run_lane"
ls $run_lane/*/*.sai | sed -e 's/.sai//' | xargs rm
rm $run_lane/*/*.bam $run_lane/*/*.sai 
find $run_lane | grep libsnappyjava.so | xargs rm

echo "Indexing BAM files for $run_lane"
ls $run_lane/*.bam | sed -e 's/.bam$//' | xargs -ixxx \
bsub -o xxx.index.o -e xxx.index.e \
-R'select[mem>1000] rusage[mem=1000]' -M1000 \
/software/team31/bin/samtools index xxx.bam
