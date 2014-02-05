#!/bin/bash
# Merge BAM files
run_lane=$RUN_LANE

echo "Checking BWA sampe ran OK for $run_lane"
num_jobs=`find $run_lane/*_1 -type f | grep -v split | grep -v bwaaln | grep -v sai$ | wc -l`
succ_jobs=`grep -l 'Successfully completed' $run_lane/*/*.sampe.o | wc -l`
fail_jobs=`grep -l 'Exited' $run_lane/*/*.sampe.o | wc -l`

if [ "$fail_jobs" -gt 0  ]; then 
    echo "We have $fail_jobs failed BWA sampe jobs, can not continue"
    exit 1
elif [ "$num_jobs" -gt "$succ_jobs" ]; then
    echo "$succ_jobs / $num_jobs completed, try again later"
    exit 1
fi

echo "BWA sampe jobs completed successfully"

echo "Merging BAM files for $run_lane"
for file in `ls -d $run_lane/*_1/ | grep -E 'XXXX|NNNN' | sed -e 's/_1\/$//'`
do
bsub -o $file/merge.o -e $file/merge.e \
-R'select[mem>4000] rusage[mem=4000]' -M4000 \
java -XX:ParallelGCThreads=1 -Xmx4g -jar /software/team31/packages/picard-tools-1.79-detct/MergeSamFiles.jar \
INPUT=`find $file | grep bam$ | sort | tr '\n' ' ' | sed -e 's/ $//' | sed -e 's/ / INPUT=/g'` \
OUTPUT=$file.bam \
MSD=true ASSUME_SORTED=false \
VALIDATION_STRINGENCY=SILENT VERBOSITY=WARNING QUIET=true \
TMP_DIR=$file
done
