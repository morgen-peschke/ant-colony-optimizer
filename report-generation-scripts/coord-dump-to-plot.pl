#!/usr/bin/env perl

use strict;
use warnings;

my @nodes =
    map {
        my $loc = $_;
        $loc =~ s/[()]//g;
        $loc =~ s/,/ /g;
        $loc;
    } <>;

print @nodes;

