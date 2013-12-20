package AntColony;

use strict;
use warnings;

use utils;

use AntColony::Ant;
use AntColony::Constants qw (:all);

#########################################
## Constructor                          #
#########################################
# Arguments Expected:
# graph      => Graph class object
# start      => node in graph
# end        => node in graph
# max_cycles => int
# settings   => hashref {
#           population         => int (1..20) - number of ants per cycle
#           global_evaporation => [0..1) - evaporation rate of global updates
#           local_evaporation  => [0..1) - evaporation rate of local updates
#
#           pheromone_update      => UPDATE_EACH_MOVE
#                                  | UPDATE_AT_END
#                                  This is a bitmask of when updates
#                                  are performed.
#
#           pheromone_update_type => UPDATE_ALL_ANTS
#                                  | UPDATE_ELITE_ANTS
#                                  | UPDATE_CLOSE_ANTS
#                                  | UPDATE_BEST_ANT
#                                  This is a bitmask of what update
#                                  criteria is used to select ants
#                                  that get to update.
#
#           max_elite_ants     => int (0..population) - Number of ants used
#                                 when updating the best n ants.
#           close_ants_percent => (0..100) - Percent of the current best
#                                 to use as the allowable rang
#                                 when updating close ants.
#
#           max_pheromone_limit => TRUE or FALSE - should the max
#                                  pheromones be explicitly limited.
#           min_pheromone_limit => TRUE or FALSE - should the min
#                                  pheromones be explicitly limited.
#
#           pheromone_weight => [0..1) - Importance of pheromones.
#           pheromone_init   => [0..1) - Initial pheromone level.
#           pheromone_base   => [0..1) - Base pheromone levels for updates.
#           pheromone_max    => [0..1) - Max pheromone level.
#           pheromone_min    => [0..1) - Min pheromone level.
#
#           heuristic_weight   => Importance of heuristics [0..1)
#
#           greedy_choose => TRUE or FALSE - should we use the optional
#                            greedy choice rules.
#           greediness    => Probability of greedy choice [0..1)
#
#           convergence_limit => int (n >= 1) Number of consecutive
#                                iterations with no improvement.
# }
sub new {
    my ($class, %args) = @_;

    my $self = {
        graph      => $args{graph}, # Graph object
        start      => $args{start}, # Node object
        end        => $args{end},   # Node object
        max_cycles => $args{max_cycles} || 100,

        pop_count => $args{settings}->{population}, # Integer > 0

        pheromones => {},
        heuristics => {},

        global_evaporation => $args{settings}->{global_evaporation} || 0.5,
        local_evaporation  => $args{settings}->{local_evaporation}  || 0.5,

        pheromone_weight => $args{settings}->{pheromone_weight} || 0.5,
        pheromone_init   => $args{settings}->{pheromone_init}   || 0.1,
        pheromone_base   => $args{settings}->{pheromone_base}   || 0.1,
        pheromone_max    => $args{settings}->{pheromone_max}    || 1.0,
        pheromone_min    => $args{settings}->{pheromone_min}    || 0.0001,

        heuristic_weight   => $args{settings}->{heuristic_weight}   || 0.5,

        greediness => $args{settings}->{greediness} || 0.25, # Used by ACS

        convergence_count => 0,
        convergence_limit => $args{settings}->{convergence_limit} || 10,

        shortest_path => {
            length => undef,
            path   => undef,
        },

        greedy_choose          => $args{settings}->{greedy_choose} || FALSE,

        pheromone_update       => $args{settings}->{pheromone_update}      || UPDATE_AT_END,
        pheromone_update_type  => $args{settings}->{pheromone_update_type} || UPDATE_ELITE_ANTS,

        max_elite_ants         => $args{settings}->{max_elite_ants}     || 1,
        close_ants_percent     => $args{settings}->{close_ants_percent} || 0,

        max_pheromone_limit    => $args{settings}->{max_pheromone_limit} || TRUE,
        min_pheromone_limit    => $args{settings}->{min_pheromone_limit} || TRUE,
    };

    # Create and initialize the ants
    $self->{ants} = [];
    for (my $i = 0; $i < $self->{pop_count}; ++$i) {
        push (@{$self->{ants}},
              AntColony::Ant->new($self->{start}));
    }

    # Error checking required parameters
    die "AntColony::new: Graph and start/end points must be set during construction"
        unless (defined $self->{graph} and
                defined $self->{start} and
                defined $self->{end} );

    die "AntColony::new: Decay rates must be greater than 0 and less than or equal to 1"
        unless ($self->{global_evaporation}  > 0 and
                $self->{global_evaporation} <= 1 and
                $self->{local_evaporation}   > 0 and
                $self->{local_evaporation}  <= 1 );

    die "AntColony::new: Greediness must greater than or equal to 0 and less than or equal to 1"
        unless ($self->{greediness} >= 0 and
                $self->{greediness} <= 1 );

    die "AntColony::new: Population cannot be 0"
        unless $self->{pop_count};

    # Actually creates the class
    bless ($self, $class);

    # Initialize pheromone levels and pre-calculate the heuristic values.
    my $calc_heuristic = sub { return 1 / ( $_[0]->distance($_[1]) ) };

    my $edges = $self->graph()->edges();
    for my $e (keys %$edges) {
        $self->{pheromones}{$e} = $self->{pheromone_init};
        $self->{heuristics}{$e} = $calc_heuristic->(@{$edges->{$e}});
    }

    # Initialize the cycle counter
    $self->{convergence_count} = 0;
    $self->{cycle_count} = 0;
    return $self;
}

#########################################
## State Transition Function            #
#########################################

# Executes one cycle. Returns true until the maximum number of cycles has
# been reached
sub step {
    my ($self) = @_;

    my @transition;

    $transition[STATE_PRE_CYCLE        ] = STATE_UPDATE_ANTS;
    $transition[STATE_UPDATE_ANTS      ] = STATE_MID_CYCLE;
    $transition[STATE_MID_CYCLE        ] = STATE_UPDATE_PHEROMONES;
    $transition[STATE_UPDATE_PHEROMONES] = STATE_EXIT;

    my $state = STATE_PRE_CYCLE;

    until ($state == STATE_EXIT) {
        my $remain = undef;

        if    ($state == STATE_PRE_CYCLE        ) { $remain = $self->pre_cycle()         }
        elsif ($state == STATE_UPDATE_ANTS      ) { $remain = $self->update_ants()       }
        elsif ($state == STATE_MID_CYCLE        ) { $remain = $self->mid_cycle()         }
        elsif ($state == STATE_UPDATE_PHEROMONES) { $remain = $self->update_pheromones() }

        $state = $transition[$state] if (!$remain);
    }

    ++$self->{cycle_count};
    ++$self->{convergence_count};

    return ($self->has_converged || $self->maxed_out);
}

#########################################
## State Functions                      #
#########################################

# These are the main functions that do the
# actual work of the simulation. They
# handle the various states that make up a cycle.
# Transitions are defined in the 'step' function above,
# and are triggered by returning a false value. A true
# value continues in the current state.

#########################################
## - Pre-Cycle Functions                #
#########################################
sub pre_cycle {
    my ($self) = @_;

    # Reset the living ant count
    $self->{ants_left} = scalar @{$self->{ants}};

    # Reset the ants themselves
    AntColony::Ant->reset_counter();
    $_->reset($self->start) for ($self->ants);

    # Reset the update paths
    $self->{update_paths} = {
        elite => [],
        close => [],
        all   => [],
    };

    return 0;
}

#########################################
## - Update Ants Functions              #
#########################################

sub update_ants {
    my ($self) = @_;

    for my $ant ($self->ants) {
        # Skip the dead ants
        next unless ($ant->is_alive);

        # Will need for local update
        my $last_node = $ant->current;

        --$self->{ants_left}
            unless ($self->move_ant ($ant));

        # Optionally do a local update of the last node
        if ($self->{incremental_pheromone_update}) {
            $self->local_pheromone_update ($last_node, $ant->current)
                if ($ant->is_alive());
        }

        # Check if this ant made it to the end
        if ($ant->current->is ($self->end)) {
            --$self->{ants_left};
            $ant->kill();
        }
    }

    return $self->{ants_left};
}

# Returns 1 if the ant survives, 0 if it dies
# Chooses the next place the ant will move, and makes that change.
sub move_ant {
    my ($self, $ant) = @_;

    # Select all adjacent nodes that have not been visited as potential
    # next moves
    my @neighbors =
        $ant->get_potentials ();

    # Kill this ant if there is no possible further move
    unless (scalar @neighbors) {
        $ant->kill();
        return 0;
    }

    # Choose the next stop
    my $next = undef;

    # Check for greediness
    if ($self->{greedy_choose} and
        rand () <= $self->{greediness}) {

        $next = $self->greedy_choose ($ant->current, @neighbors);
    }
    # Otherwise choose randomly
    else {
        $next = utils::rbiased (
            $self->calc_biases ($ant->current, @neighbors)
        );

        $next = $neighbors[$next];
    }

    $ant->move_to ($next);

    # Survived another day!
    return 1;
}

#########################################
## - Mid Cycle                          #
#########################################

sub mid_cycle {
    my ($self) = @_;

    # No reason to do these calculations unless an actual update will occur.
    return 0
        unless ($self->{pheromone_update} & UPDATE_AT_END);

    my $old_length = $self->length;

    for my $ant ($self->ants) {

        if ($ant->current->is ($self->end)) {
            # Note if it is global best
            if ($self->is_better_path ($ant->path_length)) {
                $self->set_best_path ($ant->path_length, $ant->path);

                $old_length = $self->length;
            }

            # Check for 'elite' status
            if ($self->{pheromone_update_type} & UPDATE_ELITE_ANTS) {
                my $add_ant = FALSE;

                # We have yet to reach the max elite ants, so there is a free 'in'
                if (scalar @{$self->{update_paths}{elite}} < $self->{max_elite_ants}) {
                    $add_ant = TRUE;
                }
                # Otherwise check against the longest path that's made it in already
                elsif ($ant->path_length < $self->{update_paths}{elite}[0]{length}) {
                    $add_ant = TRUE;
                }

                if ($add_ant) {
                    push (@{$self->{update_paths}{elite}}, {
                        length => $ant->path_length,
                        path   => [$ant->path],
                    });

                    # Set the keeping length to either the max_elite_ants, or
                    # the current array length (whichever is smaller).
                    my $keep_length = (
                        scalar @{$self->{update_paths}{elite}} < $self->{max_elite_ants}
                            ? scalar @{$self->{update_paths}{elite}}
                            : $self->{max_elite_ants}
                        ) - 1;

                    # Sort in descending order by path length so the longest
                    # solution is in the 0th index. In addition we only keep
                    # the number we need to keep down the sort times.
                    $self->{update_paths}{elite} = [
                        (sort { $b->{length} <=> $a->{length} }
                             @{$self->{update_paths}{elite}} )[0..$keep_length]
                    ];

                }
            }

            # Check if this ant is 'close enough' to update the pheromones
            if ($self->{pheromone_update_type} & UPDATE_CLOSE_ANTS) {
                my $change_threashold =
                    $old_length *
                        ($self->{close_ants_percent} / 100.0);

                if (abs($ant->path_length - $old_length) < $change_threashold) {
                    push (@{$self->{update_paths}{close}}, {
                        length => $ant->path_length,
                        path   => [$ant->path]
                    });
                }
            }

            # Finally, add if everyone gets to update
            if ($self->{pheromone_update_type} & UPDATE_ALL_ANTS) {
                push (@{$self->{update_paths}{all}}, {
                    length => $ant->path_length,
                    path   => [$ant->path]
                });
            }
        }
    }

    return 0;
}

#########################################
## - Pheromone update                   #
#########################################

sub update_pheromones {
    my ($self) = @_;

    # Bug out unless we need to update pheromones
    return 0
        unless ($self->{pheromone_update} & UPDATE_AT_END);

    my %deltas = ();

    my $update_deltas = sub {
        my ($length, @path) = @_;
        my $amount = 1 / $length;

        my $itr = utils::iter_nata (2, @path);

        while (scalar (my ($a, $b) = $itr->())) {
            $deltas{$a->edge($b)->{key}} += $amount;
        }
    };

    # Calculate the deltas along the best path
    if ($self->{pheromone_update_type} & UPDATE_BEST_ANT
            and defined $self->length) {
        $update_deltas->($self->length, $self->path);
    }

    # Calculate the deltas along the elite paths
    if ($self->{pheromone_update_type} & UPDATE_ELITE_ANTS) {
        for (@{$self->{update_paths}{elite}}) {
            $update_deltas->($_->{length}, @{$_->{path}});
        }
    }

    # Calculate the deltas along the close paths
    if ($self->{pheromone_update_type} & UPDATE_CLOSE_ANTS) {
        for (@{$self->{update_paths}{close}}) {
            $update_deltas->($_->{length}, @{$_->{path}});
        }
    }

    # Calculate the deltas along all the paths
    if ($self->{pheromone_update_type} & UPDATE_ALL_ANTS) {
        for (@{$self->{update_paths}{all}}) {
            $update_deltas->($_->{length}, @{$_->{path}});
        }
    }

    # Update pheromones
    for my $edge (keys %{$self->{pheromones}}) {
        my $new_val =
            (1 - $self->{global_evaporation}) * $self->{pheromones}{$edge} +
                ($deltas{$edge} || 0);

        # Check the limits
        if ($self->{min_pheromone_limit}) {
            $new_val = $new_val < $self->{pheromone_min} ? $self->{pheromone_min} : $new_val;
        }

        if ($self->{max_pheromone_limit}) {
            $new_val = $new_val > $self->{pheromone_max} ? $self->{pheromone_max} : $new_val;
        }

        # Set the new value
        $self->{pheromones}{$edge} = $new_val;
    }

    return 0;
}

#########################################
## Convenience Functions                #
#########################################

sub reset {
    my ($self) = @_;

    my $edges = $self->graph()->edges();
    for my $e (keys %$edges) {
        $self->{pheromones}{$e} = $self->{pheromone_init};
    }

    $self->{shortest_path} = {
        length => undef,
        path   => undef,
    };

    $self->{convergence_count} = 0;
    $self->{cycle_count} = 0;
}

#########################################
## - Getters                            #
#########################################
sub graph      { return   $_[0]->{graph}       }
sub ants       { return @{$_[0]->{ants}}       }
sub start      { return   $_[0]->{start}       }
sub end        { return   $_[0]->{end}         }
sub cycles     { return   $_[0]->{cycle_count} }
sub population { return   $_[0]->{pop_count}   }

sub length { return $_[0]->{shortest_path}{length} }
sub path {
    my ($self) = @_;
    return @{$self->{shortest_path}{path}}
        if (defined $self->{shortest_path}{path});
    return ();
}

#########################################
## - Setters                            #
#########################################

sub set_best_path {
    my ($self, $length, @path) = @_;

    $self->{shortest_path}{length} = $length;
    $self->{shortest_path}{path}   = [@path];

    $self->{convergence_count} = 0;
}

#########################################
## - Logic Testing                      #
#########################################

sub is_better_path {
    my ($self, $length) = @_;

    return (
        (!defined $self->{shortest_path}->{length}) ||
        $length < $self->{shortest_path}->{length}  );
}

sub has_converged {
    my ($self) = @_;

    return ($self->{convergence_count} > $self->{convergence_limit});
}

sub maxed_out {
    my ($self) = @_;

    return ($self->{cycle_count} > $self->{max_cycles});
}

#########################################
## - Calculation                        #
#########################################

# Choose the next step in a very greedy fashion
sub greedy_choose {
    my ($self, $node, @neighbors) = @_;

    # Calculate the scores and sort them in descending order
    @neighbors =
        map { $_->[0] }
            sort { $b->[1] <=> $a->[1] }
                map { [$_, $self->calc_edge_score_greedy ($node, $_) ] }
                    @neighbors;

    # Select the highest score
    return $neighbors[0]
}

# Helper function for update_ants.
sub calc_edge_score_greedy {
    my ($self, $node, $dest) = @_;
    my $e = $node->edge($dest)->{key};

    return +($self->{heuristics}{$e} *
             $self->{pheromones}{$e} ** $self->{pheromone_weight});
}

# Calculate the probability biases for choosing each of the neighbors
sub calc_biases {
    my ($self, $node, @neighbors) = @_;

    # The probability of choosing each node is the score of each node,
    # normalized against the total score of all other neighboring nodes
    # that haven't been visited yet (collected above as @neighbors).

    # Calculate the score of each path and the total score
    my $total_score = 0;
    for (@neighbors) {
        $_ = [$_, $self->calc_edge_score ($node, $_)];

        $total_score += $_->[1];
    }

    # Build the probability bias hash
    return map { $_->[1] / $total_score } @neighbors;
}

# Helper function for calc_bias
sub calc_edge_score {
    my ($self, $node, $dest) = @_;
    my $e = $node->edge ($dest)->{key};

    return +($self->{heuristics}{$e} ** $self->{heuristic_weight} *
             $self->{pheromones}{$e} ** $self->{pheromone_weight});
}

# Perform a local pheromone update (done by each ant, after each construction)
sub local_pheromone_update {
    my ($self, $a, $b) = @_;
    my $e = $a->edge($b)->{key};

    $self->{pheromones}{$e} =
        (1 - $self->{local_evaporation}) * $self->{pheromones}{$e} +
             $self->{local_evaporation}  * $self->{pheromone_base};
}

1;


