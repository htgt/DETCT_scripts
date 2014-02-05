#!/bin/bash
# Mark duplicates (taking random bases into account):
run_lane=$RUN_LANE

echo "Checking indexing BAM files ran OK for $run_lane"
num_jobs=`ls $run_lane/*.bam | wc -l`
succ_jobs=`grep -l 'Successfully completed' $run_lane/*.index.o | wc -l`
fail_jobs=`grep -l 'Exited' $run_lane/*.index.o | wc -l`

if [ "$fail_jobs" -gt 0  ]; then 
    echo "We have $fail_jobs failed indexing BAM files jobs, can not continue"
    exit 1
elif [ "$num_jobs" -gt "$succ_jobs" ]; then
    echo "$succ_jobs / $num_jobs completed, try again later"
    exit 1
fi

echo "Indexing BAM files jobs completed successfully"

echo "Running modified MarkDuplicates for $run_lane"
find $run_lane -type f | grep -v markdup | grep bam$ | sed -e 's/.bam$//' | xargs -ixxx \
bsub -o xxx.tag.markdup.o -e xxx.tag.markdup.e \
-q hugemem \
-R'select[mem>28000] rusage[mem=28000] span[hosts=1]' -n4 -M28000 \
/software/java/bin/java -jar -XX:+UseParallelOldGC -Xms21g -Xmx27g \
/software/team31/packages/picard-tools-1.79-detct/MarkDuplicates.jar \
I=xxx.bam \
O=xxx.tag.markdup.bam \
METRICS_FILE=xxx.tag.markdup.bam.stats \
REMOVE_DUPLICATES=false \
CREATE_INDEX=false \
MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=1000 \
VALIDATION_STRINGENCY=SILENT \
CONSIDER_TAGS=true
