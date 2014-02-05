#!/bin/bash
# Run BWA sampe
run_lane=$RUN_LANE

echo "Checking BWA aln ran OK for $run_lane"
num_jobs=`ls $run_lane/*/* | grep -v split | grep -v bwaaln | grep -v sai$ | wc -l`
succ_jobs=`grep -l 'Successfully completed' $run_lane/*/*.bwaaln.o | wc -l`
fail_jobs=`grep -l 'Exited' $run_lane/*/*.bwaaln.o | wc -l`

if [ "$fail_jobs" -gt 0  ]; then 
    echo "We have $fail_jobs failed BWA aln jobs, can not continue"
    exit 1
elif [ "$num_jobs" -gt "$succ_jobs" ]; then
    echo "$succ_jobs / $num_jobs completed, try again later"
    exit 1
fi

echo "BWA aln jobs completed successfully"

echo "Running BWA sampe for $run_lane"
for file in `ls -d $run_lane/*_1/ | sed -e 's/_1\/$//'`
do
  mkdir $file
  for split in `ls ${file}_1/ | grep -v '\.'`
  do
    bsub \
    -o $file/$split.sampe.o -e $file/$split.sampe.e \
    -R'select[mem>4000] rusage[mem=4000]' -M4000 \
    "/software/team31/bin/bwa-0.5.10-mt_fixes sampe -T \
    /lustre/scratch109/srpipe/references/Mus_musculus/GRCm38/all/bwa/Mus_musculus.GRCm38.68.dna.toplevel.fa \
    ${file}_1/$split.sai \
    ${file}_2/$split.sai \
    ${file}_1/$split \
    ${file}_2/$split \
    | /software/team31/bin/samtools view -S -b -T \
    /lustre/scratch109/srpipe/references/Mus_musculus/GRCm38/all/fasta/Mus_musculus.GRCm38.68.dna.toplevel.fa \
    -o $file/$split.bam - "
  done
done
