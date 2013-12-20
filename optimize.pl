#!/usr/bin/env perl

#########################################
## Setup                                #
#########################################

use feature 'say';

use strict;
use warnings;

#########################################
## - Includes (CPAN)                    #
#########################################

use Carp::Always;

#########################################
## - Includes (Custom)                  #
#########################################

use utils;

use Graph;
use Graph::AStar;
use Graph::Generator;

use AntColony;
use AntColony::Constants qw(:all);

use GeneticOptimizer;
use GeneticOptimizer::Genome;

#########################################
## - Global Variables                   #
#########################################

# Graph id counter
my $graph_id = 0;

# Flag for debug printing
my $PRINT_DEBUG = 1;

# Flag for graceful shutdown
my $SHUTDOWN = 0;

# Log file locations
my $graph_log    = 'raw-data/graph%04d.txt';
my $astar_log    = 'raw-data/astar%04d.txt';
my $ant_path_log = 'raw-data/ant_path%04d.txt';
my $colony_log   = 'raw-data/colony%04d.csv';
my $pid_file     = 'raw-data/pid.%d';
my $best_tree    = 'raw-data/best_tree.txt';

# This is a Perl idiom that is in-lined to this:
# #define MAX_TESTS 4
sub MAX_TESTS () { 4 }

# Hard coded for my system, there is no reason to pull in all of the POSIX
# module just for this value.
sub FLOAT_MIN () { 2.2250738585072e-308 }

# These constants control the characteristics of the graphs used in
# test.
sub GRAPH_SIZE   () { 60 }
sub NODE_MIN_DEG () {  3 }
sub NODE_MAX_DEG () {  7 }

#########################################
## Signal Trapping                      #
#########################################

sub toggle_print { $PRINT_DEBUG = ! $PRINT_DEBUG }
sub clean_die    { $SHUTDOWN    = 1 }

#########################################
## Constructors                         #
#########################################

sub create_graph {
    # Setup the graph
    my $graph = Graph::Generator::generate (
        graph        => new Graph(),
        nodes        => GRAPH_SIZE,
        min_degree   => NODE_MIN_DEG,
        max_degree   => NODE_MAX_DEG,
        min_distance => GRAPH_SIZE * 2.5,
    );

    # Determine the endpoints
    my ($start, $end) = $graph->endpoints();

    # Calculate the shortest path
    my ($path_len, @path) = new Graph::AStar (
        graph => $graph,
        start => $start,
        end   => $end,
    )->run();

    die 'A* Terminated without solution' unless (scalar @path);

    # Increment the graph id
    ++$graph_id;

    return (
        $graph_id,
        $graph,
        $start,
        $end,
        $path_len,
        @path,
    );
}

#########################################
## Helper functions                     #
#########################################

# (trial - known) / known
# percent_error (trial, known)
sub percent_error { return abs($_[0] - $_[1]) / $_[1]; }

# Save the log data about each graph used in the trials.
# The saved data will be the graph data (nodes and edges) and the shortest path
# found using A*
sub log_graph {
    my ($graph_id, $graph, @path) = @_;

    open  (FILE, '>', sprintf ($graph_log, $graph_id)) or
        die ("Unable to open: " . sprintf ($graph_log, $graph_id));

    print  FILE  $graph->str() . $/;
    close (FILE);

    open (FILE, '>', sprintf ($astar_log, $graph_id)) or
        die ("Unable to open: " . sprintf ($astar_log, $graph_id));

    print FILE $_->str() . $/
        for (@path);
    close (FILE);
}

# Saves the best path found by the ant colonies
sub log_best_ant {
    my ($id, @path) = @_;

    open (FILE, '>', sprintf ($ant_path_log, $graph_id));
    print FILE $_->str() . $/
        for (@path);
    close (FILE);
}

# This logs the information about each colony, their genome, how long it takes
# to converge, and the parent algorithms
sub log_colony {
    my ($id, @solutions) = @_;

    open (FILE, '>', sprintf ($colony_log, $id));
    print FILE join(',', 'ID', map { uc $_ } $solutions[0]->{genome}->names, 'LENGTHS', 'CONVERGENCE TIMES', 'PARENTS') . $/;

    for my $s (@solutions) {
        print FILE solution_to_str ($s) . $/;
    }

    close FILE;
}

# Helper for printing out the solution data
sub solution_to_str {
    my ($s) = @_;
    return join (
        ',',
        $s->{id},
        map { $_ || '0' } $s->{genome}->array,
        join (' ', @{$s->{metadata}[0]}),
        join (' ', @{$s->{metadata}[1]}),
        join (' ', map { $_ || '-' } @{$s->{parents}})
    );
}

#########################################
## - Genetic programming functions      #
#########################################

my ( $graph_best_path_length,
     @graph_best_path_trace );

# This is a bit of a beast, as it has to return a function that will calculate
# the fitness function for a graph and colony. Basically it creates a function
# that will run the target algorithm a bunch of times to get an average.
sub gen_fitness_function {
    my ($graph, $start, $end, $best_length) = @_;

    # Max iterations * max population is a good bet for a beyond impossible time
    my $best_time = 500 * 60;

    return sub {
        my ($genome) = @_;
        my %args = $genome->hash;

        # This is basically doing a conversion between the genome and the
        # constructor arguments.
        my $colony = AntColony->new (
            graph    => $graph,
            start    => $start,
            end      => $end,
            settings => {
                population => $args{population},

                global_evaporation => $args{global_evaporation},
                local_evaporation  => $args{local_evaporation},

                pheromone_update =>
                    $args{pheromone_update_each_move} +
                    $args{pheromone_update_at_end}    ,

                pheromone_update_type =>
                    $args{pheromone_update_type_all}   +
                    $args{pheromone_update_type_elite} +
                    $args{pheromone_update_type_close} +
                    $args{pheromone_update_type_best}  ,

                max_elite_ants     => $args{max_elite_ants},
                close_ants_percent => $args{close_ants_percent},

                max_pheromone_limit => $args{max_pheromone_limit},
                min_pheromone_limit => $args{min_pheromone_limit},

                pheromone_min => $args{pheromone_min},
                pheromone_max => $args{pheromone_max},

                pheromone_init => $args{pheromone_init},
                pheromone_base => $args{pheromone_base},

                pheromone_weight => $args{pheromone_weight},
                heuristic_weight => $args{heuristic_weight},

                greedy_choose => $args{greedy_choose},
                greediness    => $args{greediness},

                convergence_limit => $args{convergence_limit},
            }
        );

        my @lengths = ();
        my @times   = ();

        my ($time, $steps);

        print ' ::' if ($PRINT_DEBUG);

        # This is the meat of it, running the actual tests and capturing the results
        for (1 .. MAX_TESTS) {
            $colony->reset();

            $steps = 100;
            while (!$colony->has_converged and --$steps) { $colony->step() }

            # Log the best path in a global so we can pass it to a log file when
            # the algorithm is done. This is run by a global as it is not a
            # function of the GeneticOptimizer class.
            if (defined ($colony->length) and
                        ((not defined $graph_best_path_length) ||
                         ($colony->length < $graph_best_path_length)
                         )) {
                @graph_best_path_trace = $colony->path;
                $graph_best_path_length = $colony->length;
            }

            # If they don't find any path, set them to an order of magnitude
            # worse than the best path as a penalty.
            push (@lengths,
                  (defined ($colony->length) ? $colony->length : ($best_length * 10))
              );


            $time = $colony->cycles;

            push (@times, $time);

            $best_time = $time if ($time < $best_time);

            printf ' %2d', $time if ($PRINT_DEBUG);
        }

        # Score calculation
        my $score = 0;
        $steps = MAX_TESTS - 1;

        $score
            += percent_error ($lengths[$_], $best_length)
                + percent_error ($times[$_],   $best_time)
                    for (0 .. $steps);

        if ($PRINT_DEBUG) {
            my @rules = ();
            push (@rules, 'ALL'   ) if ($args{pheromone_update_type_all}  );
            push (@rules, 'ELITE' ) if ($args{pheromone_update_type_elite});
            push (@rules, 'CLEAR' ) if ($args{pheromone_update_type_close});
            push (@rules, 'BEST'  ) if ($args{pheromone_update_type_best} );
            push (@rules, 'GLOBAL') if ($args{pheromone_update_at_end}    );
            push (@rules, 'LOCAL' ) if ($args{pheromone_update_each_move} );

            printf ' :: %9.4f : %s ' . $/, $score, (join (' ', @rules) || "NONE");
        }

        return ($score, [\@lengths, \@times]);
    };
}

#########################################
## Main                                 #
#########################################

###################################
# Create the colony genome pattern
#
print 'Generating genome pattern' . $/ if ($PRINT_DEBUG);

my $p = Genome->new (
    p_cross         => 0.90,
    p_mutate        => 0.05,
    p_average       => 0.02,
    time_dependence => 0.85,
);

# This defines the genome. It could probably be done in a configuration file,
# but I was running out of patience.
$p->append (type => Genome::TYPE_INT,   name => 'population',                  value => 0, lower => 1,         upper => GRAPH_SIZE);
$p->append (type => Genome::TYPE_FLOAT, name => 'global_evaporation',          value => 0, lower => FLOAT_MIN, upper => 1);
$p->append (type => Genome::TYPE_FLOAT, name => 'local_evaporation',           value => 0, lower => FLOAT_MIN, upper => 1);
$p->append (type => Genome::TYPE_BOOL,  name => 'pheromone_update_each_move',  value => 0);
$p->append (type => Genome::TYPE_BOOL,  name => 'pheromone_update_at_end',     value => 0);
$p->append (type => Genome::TYPE_BOOL,  name => 'pheromone_update_type_all',   value => 0);
$p->append (type => Genome::TYPE_BOOL,  name => 'pheromone_update_type_elite', value => 0);
$p->append (type => Genome::TYPE_BOOL,  name => 'pheromone_update_type_close', value => 0);
$p->append (type => Genome::TYPE_BOOL,  name => 'pheromone_update_type_best',  value => 0);
$p->append (type => Genome::TYPE_INT,   name => 'max_elite_ants',              value => 0, lower => 1,         upper => 100);
$p->append (type => Genome::TYPE_FLOAT, name => 'close_ants_percent',          value => 0, lower => FLOAT_MIN, upper => 100);
$p->append (type => Genome::TYPE_FLOAT, name => 'max_pheromone_limit',         value => 0, lower => FLOAT_MIN, upper => 1);
$p->append (type => Genome::TYPE_FLOAT, name => 'min_pheromone_limit',         value => 0, lower => FLOAT_MIN, upper => 1);
$p->append (type => Genome::TYPE_FLOAT, name => 'pheromone_init',              value => 0, lower => FLOAT_MIN, upper => 1);
$p->append (type => Genome::TYPE_FLOAT, name => 'pheromone_base',              value => 0, lower => FLOAT_MIN, upper => 1);
$p->append (type => Genome::TYPE_FLOAT, name => 'pheromone_weight',            value => 0, lower => FLOAT_MIN, upper => 1);
$p->append (type => Genome::TYPE_FLOAT, name => 'heuristic_weight',            value => 0, lower => FLOAT_MIN, upper => 1);
$p->append (type => Genome::TYPE_BOOL,  name => 'greedy_choose',               value => 0);
$p->append (type => Genome::TYPE_FLOAT, name => 'greediness',                  value => 0, lower => FLOAT_MIN, upper => 1);
$p->append (type => Genome::TYPE_INT,   name => 'convergence_limit',           value => 0, lower => 1,         upper => GRAPH_SIZE);

#################################
# Create and log the graph
#
print 'Creating graph' . $/ if ($PRINT_DEBUG);

my ($graph, $start, $end, $length, @path);

($graph_id, $graph, $start, $end, $length, @path) =
    create_graph ();

log_graph ($graph_id, $graph, @path);

###############################
# Create the Genetic Optimizer
#
print 'Creating Optimizer' . $/ if ($PRINT_DEBUG);

$graph_best_path_length = undef;
@graph_best_path_trace  = ();

my $optimizer = GeneticOptimizer->new (
    pattern => $p,
    fitness => gen_fitness_function (
        $graph, $start, $end, $length
    ),

    population  => 40,
    sample_size => 5,

    max_generations => 1000,
);

###########################
# Log the initial solutions
# generated by the constructor
#
log_colony   ($graph_id, $optimizer->solutions);
log_best_ant ($graph_id, @graph_best_path_trace);

###########################
# Do the selection
#
print 'Optimizer created' . $/ if ($PRINT_DEBUG);

print 'Registering signal handlers' . $/ if ($PRINT_DEBUG);
use sigtrap qw (handler toggle_print USR1
                handler clean_die normal-signals);

###########################
# Notify and log the PID
#
print 'OK to send signals to PID: ' . $$ . $/;
open (FILE, '>', sprintf ($pid_file, $$));
print FILE $$ . $/;
close (FILE);


print 'Starting the selections' . $/ if ($PRINT_DEBUG);
while (!$SHUTDOWN) {
    print 'Iteration #' . $graph_id . $/ if ($PRINT_DEBUG);
    print ' :: Making a new graph'  . $/ if ($PRINT_DEBUG);

    # Generate a new graph and log it
    ($graph_id, $graph, $start, $end, $length, @path) =
        create_graph ();

    log_graph ($graph_id, $graph, @path);

    # A new graph will need a new fitness function
    $optimizer->set_fitness (
        gen_fitness_function ($graph, $start, $end, $length)
    );

    # Run the optimizer
    $graph_best_path_length = undef;
    @graph_best_path_trace  = ();

    $SHUTDOWN = 1 unless ($optimizer->step());

    # Log the solutions
    log_colony   ($graph_id, $optimizer->solutions);
    log_best_ant ($graph_id, @graph_best_path_trace)
}

#####################################
# Save the tree of the best algorithm

# WARNING: only uncomment this section if you have alot of disk space, and alot
# of time. Frankly it's not all that interesting anyway.

#open (my $FILE, '>', $best_tree);

#$optimizer->ancestral_tree->display(
#    node      => $optimizer->best_id,
#    fd        => $FILE,
#    stringify => sub {
#        return sprintf ('[%d] %.4f', $_[0]->{id}, $_[0]->{score})
#    }
#);
#close ($FILE);

#####################################
# Remove the pid file
#
unlink (sprintf ($pid_file, $$));

