#!/bin/bash
# Extract FASTQ

run_lane=$RUN_LANE

echo "First checking sorting bam files jobs ran OK for $run_lane"
num_jobs=`ls $run_lane/*.bam | grep -v sorted | wc -l`
succ_jobs=`grep -l 'Successfully completed' $run_lane/*.sort.o | wc -l`
fail_jobs=`grep -l 'Exited' $run_lane/*.sort.o | wc -l`

if [ "$fail_jobs" -gt 0  ]; then 
    echo "We have $fail_jobs failed sort jobs, can not continue"
    exit 1
elif [ "$num_jobs" -gt "$succ_jobs" ]; then
    echo "$succ_jobs / $num_jobs completed, try again later"
    exit 1
fi

echo "Completed all $num_jobs sort bam file jobs successfully"
echo "Deleting original BAM files for $run_lane"
ls $run_lane/*.bam | grep -v sorted | xargs rm

echo "Convert BAM to FASTQ via SAM for $run_lane"
ls $run_lane/*.sorted.bam | sed -e 's/.sorted.bam$//' | xargs -ixxx mkdir xxx
ls $run_lane/*.sorted.bam | sed -e 's/.sorted.bam$//' | xargs -ixxx \
bsub -o xxx.bam2fastq.o -e xxx.bam2fastq.e \
-R'select[mem>2000] rusage[mem=2000]' -M2000 \
"/software/team31/bin/samtools view -h xxx.sorted.bam -o - | \
/software/java/bin/java -jar -XX:+UseParallelOldGC -Xms1500m -Xmx2g \
/software/team31/packages/picard-tools-1.79-detct/SamToFastq.jar \
INPUT=/dev/stdin OUTPUT_PER_RG=true OUTPUT_DIR=xxx VALIDATION_STRINGENCY=SILENT"
