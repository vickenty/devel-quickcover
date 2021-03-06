#!/usr/bin/env perl

use strict;
use warnings;

# Generate a Devel::Cover-compatible report file from cover data.

use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use File::Path qw(make_path);
use File::Slurp qw(read_file write_file);
use Getopt::Long;
use JSON::XS;
use Sereal qw(encode_sereal decode_sereal);

my $QC_DATABASE   = 'qc.dat';
my $COVERDB       = './cover_db/';
my $VERBOSE       = 0;
my %PATH_REWRITES = ();

GetOptions('input=s'         => \$QC_DATABASE,
           'cover-db=s'      => \$COVERDB,
           'verbose=i'       => \$VERBOSE,
           'path-rewrite=s%' => \%PATH_REWRITES,
);

my $DIGESTS       = "$COVERDB/digests";
my $STRUCTURE     = "$COVERDB/structure/";
my $RUNS          = "$COVERDB/runs/";

my $JSON          = JSON::XS->new->utf8->indent;
my $DEVEL_COVER_DB_FORMAT = 'Sereal';
$ENV{DEVEL_COVER_DB_FORMAT}
    and $DEVEL_COVER_DB_FORMAT = 'JSON';

exit main();

sub main {
    my $data = load_data($QC_DATABASE);

    make_coverdb_directories();
    generate_cover_db($data);

    return 0;
}

sub make_coverdb_directories {
    -d $COVERDB
        or make_path $COVERDB;

    -d $STRUCTURE
        or make_path $STRUCTURE;

    -d $RUNS
        or make_path $RUNS;
}

sub load_data {
    my $file = shift;

    my $data = read_file($file, { binmode => ':raw' })
        or die "Can't read the data";

    my $decoded = Sereal::decode_sereal($data)
        or die "Can't decode the input data";

    return $decoded;
}

sub coverdb_decode {
    if ($DEVEL_COVER_DB_FORMAT eq 'JSON') {
       return $JSON->decode(shift);
    }
    return decode_sereal(shift);
}

sub coverdb_encode {
    if ($DEVEL_COVER_DB_FORMAT eq 'JSON') {
        return $JSON->encode(shift);
    }
    return encode_sereal(shift);
}

sub generate_cover_db {
    my $data     = shift;
    my $digests  = {};

    if (-r $DIGESTS) {
        my $digests_data = read_file($DIGESTS, { binmode => ':raw' });
        $digests //= coverdb_decode( $digests_data );
    }

    my $run = {
        OS        => 'xx',
        collected => [ 'statement' ],
        count     => {},
        digests   => {},
        start     => 0,
        run       => 'xx',
    };

    for my $file (keys %{ $data }) {
        my $original_filename = $file;
        while ( my ($from, $to) = each %PATH_REWRITES ) {
            $file =~ s/$from/$to/;
        }
        if (!-r $file) {
            $VERBOSE and
                print "Skipping $file for now. Probably an eval\n";
            next;
        }

        my $hits       = $data->{ $original_filename };
        my $statements = [ sort { $a <=> $b } keys %$hits ];
        my $md5        = process_file_structure($file, $statements, $digests);

        $run->{count}{$file}{statement} = [ @{$hits}{@$statements}  ];
        $run->{digests}{$file}          = $md5;
    }

    write_file( $DIGESTS, { binmode => ':raw' }, coverdb_encode( $digests ) );

    my $run_id = rand(1000);
    my $run_structure = { runs => { $run_id => $run } };
    mkdir ( "$RUNS/$run_id" );

    write_file ( "$RUNS/$run_id/cover.14", { binmode => ':raw' }, coverdb_encode( $run_structure ) );
}

sub process_file_structure {
    my ($file, $statements, $digests) = @_;

    my $content = read_file($file, { binmode => ':raw'});
    my $md5     = md5_hex( $content );

    if (! exists($digests->{ $md5 })) {
        $digests->{ $md5 } = $file;
        write_structure($file, $md5, $statements);
    }
    return $md5;
}

sub write_structure {
    my ($file, $md5, $statements) = @_;

    my $structure = {
        file       => $file,
        digest     => $md5,
        start      => {},
        statement  => $statements,
        subroutine => [],
    };

    write_file( "$STRUCTURE/$md5", { binmode => ':raw' }, coverdb_encode( $structure ));
}
