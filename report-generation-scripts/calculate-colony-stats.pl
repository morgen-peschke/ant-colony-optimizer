#!/usr/bin/perl

use strict;
use warnings;

use Carp::Always;
use Data::Dumper;

my $MAX = 281;

# Boatload of constants
sub ID                          () {  0 }
sub POPULATION                  () {  1 }
sub GLOBAL_EVAPORATION          () {  2 }
sub LOCAL_EVAPORATION           () {  3 }
sub PHEROMONE_UPDATE_EACH_MOVE  () {  4 }
sub PHEROMONE_UPDATE_AT_END     () {  5 }
sub PHEROMONE_UPDATE_TYPE_ALL   () {  6 }
sub PHEROMONE_UPDATE_TYPE_ELITE () {  7 }
sub PHEROMONE_UPDATE_TYPE_CLOSE () {  8 }
sub PHEROMONE_UPDATE_TYPE_BEST  () {  9 }
sub MAX_ELITE_ANTS              () { 10 }
sub CLOSE_ANTS_PERCENT          () { 11 }
sub MAX_PHEROMONE_LIMIT         () { 12 }
sub MIN_PHEROMONE_LIMIT         () { 13 }
sub PHEROMONE_INIT              () { 14 }
sub PHEROMONE_BASE              () { 15 }
sub PHEROMONE_WEIGHT            () { 16 }
sub HEURISTIC_WEIGHT            () { 17 }
sub GREEDY_CHOOSE               () { 18 }
sub GREEDINESS                  () { 19 }
sub CONVERGENCE_LIMIT           () { 20 }
sub LENGTHS                     () { 21 }
sub TIMES                       () { 22 }
sub PARENTS                     () { 23 }

# Helper functions
sub percent_error {
    my ($trial, $best) = @_;
    return abs($trial - $best) / $best;
}

sub sum {
    my $s = 0;
    $s += $_ for (@_);
    return $s;
}

sub average {
    return undef unless (scalar @_);
    return sum (@_) / scalar @_;
}

# Data locations
my $file_pattern  = 'raw-data/colony%04s.csv';
my $astar_file    = 'data/astar-lengths.txt';

my @generations   = ();
my @astar_lengths = ();

# Read in the precalculated astar best lengths
open (FILE, '<', $astar_file);
@astar_lengths = map { chomp; (split (/ /))[1] } <FILE>;
close (FILE);

# Compensate for 1 based nature of the logs
unshift (@astar_lengths, 0);
unshift (@generations,   0);

# Read in the data and find the shortest time
my $best_time = undef;
for my $generation (1 .. $MAX) {

    # Read in an entire generation at once, saving only the bits we need
    open (FILE, '<', sprintf ($file_pattern, $generation))
        or die ("Unable to open file: " . sprintf($file_pattern, $generation));

    <FILE>; # Drop the header line

    my @generation_data = map { chomp;
                                my @t = split(/,/);
                                [ [ split (/ /, $t[LENGTHS]) ] ,
                                  [ split (/ /, $t[TIMES]  ) ] ];
                            } <FILE>;
    close (FILE);

    for my $g (@generation_data) {
        for my $t (@{$g->[1]}) {
            $best_time = $t
                if (
                    (not defined $best_time)
                        or ($t < $best_time)
                    );
        }
    }

    push (@generations, \@generation_data);
}

# Process each generation in turn
for my $g_num (1 .. $MAX) {
    my @lengths = ();
    my @times   = ();
    my @fitness = ();
    my $win_count  = 0;
    my $total_time = 0;

    # Used to select those within 10% of the astar score
    my $target = $astar_lengths[$g_num] * 1.10;

    # Calculate the score for each colony
    for my $colony (@{$generations[$g_num]}) {

        my $length_score = 0;
        my $time_score   = 0;

        for (@{$colony->[0]}) {
            ++$win_count
                if ($_ < $target);

            $length_score += percent_error ($_, $astar_lengths[$g_num])
        }

        for (@{$colony->[1]}) {
            $time_score += percent_error ($_, $best_time);

            $total_time += $_;
        }

        push (@lengths, $length_score);
        push (@times,   $time_score  );
        push (@fitness, $length_score + $time_score);
    }

    # Select the top 10% in each category
    @lengths = (sort { $a <=> $b } @lengths)[0 .. int($#lengths * 0.1)];
    @times   = (sort { $a <=> $b } @times  )[0 .. int($#times   * 0.1)];
    @fitness = (sort { $a <=> $b } @fitness)[0 .. int($#fitness * 0.1)];

    # Print the data
    print join (
        ' ',
        $g_num,
        average (@lengths),
        average (@times),
        average (@fitness),
        $win_count,
        $total_time) . $/;
}
