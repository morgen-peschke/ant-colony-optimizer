#!/usr/bin/env perl

use strict;
use warnings;

sub ID    () { 0 }
sub COORD () { 1 }
sub ADJ   () { 2 }

my @nodes =
    map {
        my $loc = $_->[COORD];
        $loc =~ s/[()]//g;
        $loc =~ s/,/ /g;
        [ $_->[ID], $loc, [split(/ /, $_->[ADJ])] ] }
    map { [split(/:/)] } <>;

my $node_count = scalar @nodes;
my $edge_count = 0;

my %visited = ();
for my $node (@nodes) {
    for my $other (@{$node->[ADJ]}) {
        my $s = $node->[COORD];
        my $e = $nodes[$other]->[COORD];

        unless (defined ($visited{"$s$e"}) ||
                defined ($visited{"$e$s"}) ){

            $visited{"$s$e"} = 1;
            $visited{"$e$s"} = 1;

            ++$edge_count;
        }
    }
}

printf "%d\t%d".$/, $node_count, $edge_count;
