#!/bin/bash

export SAMTOOLS=/software/team31/packages/samtools

export PERL5LIB=/software/team31/bioperl/bioperl-1-6-9:$PERL5LIB
export PERL5LIB=/software/team31/perl/lib/perl5:$PERL5LIB
export PERL5LIB=/software/team31/packages/DETCT/lib:$PERL5LIB
export PERL5LIB=/software/pubseq/PerlModules/Ensembl/www_72_1/ensembl/modules:$PERL5LIB

export PATH=/software/team31/packages/DETCT/bin/:$PATH
export PATH=/software/team31/bin:$PATH

export LSB_DEFAULTGROUP=team87-grp
export R_LIBS_USER=/software/team31/R
