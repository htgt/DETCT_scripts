#!/bin/bash

# Set appropriate run_lane and then follow the recipe:
run_lane=$RUN_LANE

# Get the BAM files and indexes and metadata from iRODS
echo "Getting BAM files for $run_lane"
mkdir $run_lane
run=`echo $run_lane | sed -e 's/_.*//'`
lane=`echo $run_lane | sed -e 's/.*_//'`
/software/irods/icommands/bin/imeta qu -z seq -d id_run = $run and lane = $lane and target = 1 \
| grep : | awk '{ print $2 }' | paste - - -d/ \
| xargs -ixxx /software/irods/icommands/bin/iget xxx $run_lane
/software/irods/icommands/bin/imeta qu -z seq -d id_run = $run and lane = $lane and target = 1 \
| grep : | awk '{ print $2 }' | paste - - -d/ | sed -e 's/bam$/bai/' \
| xargs -ixxx /software/irods/icommands/bin/iget xxx $run_lane
/software/irods/icommands/bin/iget /seq/$run/$run_lane#0.bam $run_lane
/software/irods/icommands/bin/iget /seq/$run/$run_lane#0.bai $run_lane
chmod 664 $run_lane/*
find $run_lane | grep '#168\.' | xargs rm
for bam in $(find $run_lane | grep bam$ | sed -e 's/.*\///' | sed -e 's/\.bam$//')
do
/software/irods/icommands/bin/imeta ls -d /seq/$run/$bam.bam > $run_lane/$bam.imeta
done

# Get rid of any duplicated data (which is only a problem for really old runs)
echo "Delete any duplicated BAM file for $run_lane"
temp1=`find $run_lane | grep bam$ | grep -v '#'`
temp2=`find $run_lane | grep bam$ | grep '#0' | sed -e 's/#0//'`
if [[ -n $temp1 && -n $temp2 && $temp1 == $temp2 ]];
then
rm $temp1
fi

# Sort BAM files by read name prior to extracting FASTQ
# (I should really switch to German's bamtofastq <https://github.com/gt1/biobambam>
# which wouldn't require this step)
echo "Sorting BAM files by read name for $run_lane"
ls $run_lane/*.bam | sed -e 's/.bam$//' | xargs -ixxx \
bsub -o xxx.sort.o -e xxx.sort.e \
-R'select[mem>2000] rusage[mem=2000]' -M2000 \
/software/team31/bin/samtools sort -n xxx.bam xxx.sorted
