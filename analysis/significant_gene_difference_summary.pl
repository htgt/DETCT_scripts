#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use Try::Tiny;
use Text::CSV;
use YAML::Any qw( LoadFile );
use Getopt::Long;
use LIMS2::Util::EnsEMBL;
use Log::Log4perl ':easy';
use List::MoreUtils qw( all );
use List::Util qw( sum );
use IO::File;
use Pod::Usage;
use Path::Class;
use feature qw( say );

use Smart::Comments;

my $log_level = $WARN;
GetOptions(
    'help'          => sub { pod2usage( -verbose    => 1 ) },
    'man'           => sub { pod2usage( -verbose    => 2 ) },
    'debug'         => sub { $log_level = $DEBUG },
    'verbose'       => sub { $log_level = $INFO },
    'sig-file=s'    => \my $sig_file,
    'all-file=s'    => \my $all_file,
    'groups-file=s' => \my $groups_file,
    'low-value=i'   => \my $low_value,
    'high-value=i'  => \my $high_value,
    'ens-gene=s'    => \my $ens_gene_id,
    'output-type=s' => \my $output_type,
    'output-dir=s'  => \my $dir,
) or pod2usage(2);

Log::Log4perl->easy_init( { level => $log_level, layout => '%p %x %m%n' } );
LOGDIE( 'Specify file with significant genes: --sig-file' ) unless $sig_file;
LOGDIE( 'Specify file with all genes: --all-file' )         unless $all_file;
LOGDIE( 'Specify file with groups: --groups-file' )         unless $groups_file;
LOGDIE( 'Specify output dir: --output-dir ' )               unless $all_file;

#
# SETUP
#
$low_value   ||= 10;
$high_value  ||= 500;
$output_type ||= 'ensembl'; #ensembl for marker_symbol

my $output_dir = dir( $dir );
$output_dir->mkpath;

my $group_details = LoadFile( $groups_file );
my @group_names = keys %{ $group_details };

#
# Parse data from sig.csv
#
my %genes_data;
my $input_csv = Text::CSV->new();
open ( my $input_fh, '<', $sig_file ) or die( "Can not open $sig_file " . $! );
$input_csv->column_names( @{ $input_csv->getline( $input_fh ) } );
while ( my $data = $input_csv->getline_hr( $input_fh ) ) {
    # filter out any data we see as invalid
    next if is_invalid_gene_data( $data );
    my $ens_id = $data->{'e72 Ensembl Gene ID'};

    next if $ens_gene_id && $ens_gene_id ne $ens_id;

    push @{ $genes_data{$ens_id} }, process_gene( $data, $ens_id );
}
close $input_fh;
Log::Log4perl::NDC->remove;

de_dupe( \%genes_data );

my $low_expression_genes = find_low_expression_genes( \%genes_data );
my $high_expression_genes = find_high_expression_genes( \%genes_data );

print_diff_results( $low_expression_genes, 'low_expression' );
print_diff_results( $high_expression_genes, 'high_expression' );

#
# Parse data from all.csv
#
my %all_genes;
$input_csv = Text::CSV->new();
open ( $input_fh, '<', $all_file ) or die( "Can not open $all_file " . $! );
$input_csv->column_names( @{ $input_csv->getline( $input_fh ) } );
while ( my $data = $input_csv->getline_hr( $input_fh ) ) {
    my $ens_id = $data->{'e72 Ensembl Gene ID'};
    next unless $ens_id;

    next if exists $all_genes{$ens_id};
    $all_genes{$ens_id} = $data->{'Gene name'};
}
close $input_fh;

print_gene_lists( \%all_genes, 'all_genes' );

# genes in all.csv but not in sig.csv ( i.e. expression does not change )
my %non_change_genes;
for my $gene ( keys %all_genes ) {
    unless ( exists $genes_data{$gene} ) {
        $non_change_genes{ $gene } = $all_genes{$gene};
    }
}
print_gene_lists( \%non_change_genes, 'non_changed_genes' );

sub print_diff_results {
    my ( $data, $type ) = @_;

    for my $group ( @group_names ) {
        my $genes = $data->{$group}{$output_type};
        my $fh = create_file( $type . '-' . $group );
        say $fh join"\n", @{ $genes };
    }
}

sub print_gene_lists {
    my ( $list, $name ) = @_;

    my $fh = create_file( $name );
    if ( $output_type eq 'ensembl' ) {
        say $fh join "\n", keys %{ $list };
    }
    else {
        say $fh join "\n", values %{ $list };
    }
}

sub create_file {
    my $name = shift;

    my $file = $output_dir->file( $name . '.txt' );
    $file->touch;

    return $file->openw;
}

sub process_gene {
    my ( $data, $ens_id ) = @_;
    my %gene_data;

    $gene_data{transcript} = $data->{'e72 Ensembl Transcript ID'};
    $gene_data{transcript_type} = $data->{'Transcript type'};
    $gene_data{gene_name} = $data->{'Gene name'};
    $gene_data{gene_type} = $data->{'Gene type'};
    for my $group ( @group_names ) {
        my $avg_read_count = _avg_read_count( $data, $group );
        $gene_data{$group}{'avg_read_count'} = $avg_read_count;
    }

    return \%gene_data;
}

sub is_invalid_gene_data {
    my ( $data ) = @_;
    # no gene data, no go
    return 1 unless $data->{'e72 Ensembl Gene ID'};
    Log::Log4perl::NDC->remove;
    Log::Log4perl::NDC->push( $data->{'e72 Ensembl Gene ID'} );

    # filter out if 3' end position of reads does not match up with genomic posistion of gene
    if ( $data->{"3' end strand"} == 1 ) {
        if ( $data->{'Region end'} != $data->{"3' end position"} ) {
            DEBUG( "3' end positions no match" );
            return 1;
        }
    }
    elsif ( $data->{"3' end strand"} == -1 ) {
        if ( $data->{'Region start'} != $data->{"3' end position"} ) {
            DEBUG( "3' end positions no match" );
            return 1;
        }
    }

    my $dist_3_end = $data->{"Distance to 3' end "};
    if ( $dist_3_end !~ /^-?\d+$/ ) {
        return 1;
    }

    if ( $dist_3_end > 100 || $dist_3_end < -100 ) {
        DEBUG( "Distance to 3' end too big: " . $dist_3_end );
        return 1;
    }

    return;
}

# data has count and normalised count values
# we used normalised counts
sub _avg_read_count {
    my ( $data, $group ) = @_;

    my @field_names = map{ $_ . ' normalised count' } @{ $group_details->{$group} };
    my @normalised_count = @{ $data }{ @field_names };

    return sprintf( "%d" ,( sum @normalised_count ) / scalar(@field_names) );
}

sub de_dupe {
    my ( $genes_data ) = @_;

    my $fh = create_file( 'duplicates' );
    for my $gene ( keys %{ $genes_data } ) {
        Log::Log4perl::NDC->remove;
        Log::Log4perl::NDC->push( $gene );
        my @rows = @{ $genes_data->{$gene} };
        if ( scalar( @rows ) == 1 ) {
            $genes_data->{$gene} = shift @rows;
        }
        else {
            INFO( "Multiple Transcripts for gene" );
            my @transcripts = map { $_->{transcript} } @rows;
            my @filtered_rows = grep{ $_->{transcript_type} =~ /protein_coding/ } @rows;

            if ( scalar( @filtered_rows ) == 1 ) {
                say $fh $gene . ' : ' . join(',',@transcripts) . ' : ' . 'only one protein coding.';
                DEBUG( "... but only one transcript is protein coding, using that" );
                $genes_data->{$gene} = shift @filtered_rows;
            }
            else {
                WARN('... and more than one of the transcripts are protein coding, choosing by read count' );
                say $fh $gene . ' : '
                    . join( ',', @transcripts ) . ' : '
                    . 'multiple protein coding, picked one with most read count.';
                my @sorted_counts = sort { _sum_counts($b) <=> _sum_counts($a) } @filtered_rows;
                $genes_data->{$gene} = shift @sorted_counts;
            }
        }
    }
}

sub _sum_counts {
    my $row = shift;
    return sum map { $row->{$_}{avg_read_count} } @group_names;
}

# find genes from the specified groups where the avg read count is below
# a certain threshold, defaults to 10
sub find_low_expression_genes {
    my ( $genes_data ) = @_;
    my %low_expression_genes;

    for my $gene ( keys %{ $genes_data } ) {
        my @low_count_groups = grep { $genes_data->{$gene}{$_}{avg_read_count} < $low_value } @group_names;

        my $gene_name = $genes_data->{$gene}{gene_name};
        push @{ $low_expression_genes{$_}{marker_symbol} }, $gene_name for @low_count_groups;
        push @{ $low_expression_genes{$_}{ensembl} }, $gene for @low_count_groups;
    }

    return \%low_expression_genes;
}

# find genes from the specified groups where the avg read count is
# above a certain threshold, defaults to 500
sub find_high_expression_genes {
    my ( $genes_data ) = @_;
    my %high_expression_genes;

    for my $gene ( keys %{ $genes_data } ) {
        my @high_count_groups = grep { $genes_data->{$gene}{$_}{avg_read_count} > $high_value } @group_names;

        my $gene_name = $genes_data->{$gene}{gene_name};
        push @{ $high_expression_genes{$_}{marker_symbol} }, $gene_name for @high_count_groups;
        push @{ $high_expression_genes{$_}{ensembl} }, $gene for @high_count_groups;
    }

    return \%high_expression_genes;
}

__END__

=head1 NAME

signification_gene_difference_summary.pl -

=head1 SYNOPSIS

  signification_gene_difference_summary.pl [options]

      --help            Display a brief help message
      --man             Display the manual page
      --debug           Debug output
      --verbose         Verbose output
      --species         Species of targets ( default Human )
      --sig-file*       The sig.csv file produced by the pipeline
      --all-file*       The all.csv file produced by the pipeline
      --groups-file*    A yaml file describing the grouping of the run
      --low-value       Read count considered to be low, defaults to 10
      --high-value      Read count considered to be high, defaults to 500
      --output-type     Identifiers used for genes in output, ensembl or marker_symbol only, default ensembl
      --output-dir*     Directory where output files created

  Flags marker with (*) are mandatory.

=head1 DESCRIPTION


=head1 AUTHOR

Sajith Perera

=head1 BUGS

None reported... yet.

=head1 TODO

=cut
