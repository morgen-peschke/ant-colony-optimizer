#!/usr/bin/env perl

use strict;
use warnings;

use utils::all;

my @nodes = map {
    m/^\((.*),(.*)\)$/;
    [$1, $2]
} <>;

my $iter = utils::all::l_itr_by_n (2, @nodes);
my $sum = 0;

while (scalar (my ($s,$e) = $iter->())) {
    $sum += sqrt(
        ($e->[0] - $s->[0]) ** 2 +
        ($e->[1] - $s->[1]) ** 2
    );
}

print $sum . $/;
