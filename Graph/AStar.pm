package Graph::AStar;

#use strict;
#use warnings;

use Graph;
use Graph::Node;

#########################################
## Class Function                       #
#########################################

# Constructor
sub new {
    my ($class, %args) = @_;

    my $self  = {
        _graph     => $args{graph} || undef,
        _start     => $args{start} || undef,
        _end       => $args{end}   || undef,
        _worker    => undef,
        _path      => undef,
    };

    die 'AStar::new: Target graph must be specified during initialization.'
        unless (defined $self->{_graph});

    die 'Astar::new: Origin node must be specified during initialization.'
        unless (defined $self->{_start});

    die 'Astar::new: Destination node must be specified during initialization.'
        unless (defined $self->{_end});

    bless ($self, $class);

    $self->{_worker} = $self->_make_worker();

    return $self;
}

# Mainly just a bit of syntactic sugar that calls the function under the hood
# that does the actual work.

# Stepwise version for debugging
sub step { my $self = shift; return $self->{_worker}() }

# This version runs completely through the algorithm, and returns the relevant
# data.
sub run  {
    my $self = shift;
    while ($self->{_worker}()) {}

    return $self->results();
}


# Accessors to observe the intermediate state of the A* algorithm
sub open_set    { return $_[0]->{_worker}('queue'          ) }
sub close_set   { return $_[0]->{_worker}('visited'        ) }
sub search_tree { return $_[0]->{_worker}('search_tree'    ) }
sub bestness    { return $_[0]->{_worker}('bestness', $_[1]) }
sub path_len    { return $_[0]->{_worker}('path_len', $_[1]) }
sub current     { return $_[0]->{_worker}('current'        ) }
sub best_path   {
    return @{$_[0]->{_path}}
        if (defined $_[0]->{_path});
    return ();
}

# Accessors for the start and end nodes
sub start { return $_[0]->{_start} }
sub end   { return $_[0]->{_end}   }

# Get the final results
sub results {
    my $self = shift;
    return ($self->path_len($self->{_end}),
            $self->best_path());
}

# Makes the worker function, using a closure hides information better, and makes
# some of the variable access syntax easier to handle.
# Returns: function
# Function returns:
#    0 -> no further processing
#    1 -> work still to do
sub _make_worker {
    my $self = shift;

    my %queue    = ( $self->{_start} => $self->{_start} ); # Open set (nodes to visit)
    my %previous = ( $self->{_start} => undef );           # Back links to reconstruct path

    my %visited  = (); # Closed set (nodes already processed)
    my %path_len = (); # Current path score for each node

    # Heuristic metric (straight line distance to target node)
    my %distance  = ();

    # Measurement of assumed goodness (path_len + distance).
    my %bestness = ();

    # Add the start node to the open set. Self referential hash is needed
    # because 'keys' returns a hashed (and inert) version of the node.
    $queue{$self->{_start}} = $self->{_start};

    # Undef marks the initial node so we know when to stop backtracking.
    $previous{$self->{_start}} = undef;

    $distance{$self->{_start}} = $self->{_start}->calc_distance($self->{_end});
    $path_len{$self->{_start}} = 0;
    $bestness{$self->{_start}} = $distance{$self->{_start}};

    ########## DEBUG VALUE
    my $last_current = undef;

    return sub {
        ####################################################################
        ####################################################################
        #                                                                  #
        #                    START DEBUG FUNCTIONALITY                     #
        #                                                                  #
        ####################################################################
        ####################################################################
        my $arg = shift;
        if (defined $arg) {
            return values %queue         if ($arg eq 'queue'   );
            return values %visited       if ($arg eq 'visited' );
            return $bestness{$_[0]} || 0 if ($arg eq 'bestness');
            return $path_len{$_[0]} || 0 if ($arg eq 'path_len');
            return $last_current         if ($arg eq 'current' );

            if ($arg eq 'search_tree') {
                my @pairs = ();

                push (@pairs, [$_, $previous{$_}]) for (values %queue);
                push (@pairs, [$_, $previous{$_}]) for (values %visited);

                return grep { defined $_->[0] and defined $_->[1] } @pairs;
            }
        }
        ####################################################################
        ####################################################################
        #                                                                  #
        #                    END DEBUG FUNCTIONALITY                       #
        #                                                                  #
        ####################################################################
        ####################################################################

        # If there are no more elements in the queue, we have failed
        unless (scalar keys %queue) {
            $self->{_path} = undef;
            return 0;
        }

        # Grab the current best guess in the priority queue by transforming it
        # into a list of nodes and their scores, sorting that list by score,
        # shifting off the first value, and grabbing the first element (the
        # node) of that value.
        my $current =
            (shift @{[ sort { $a->[1] <=> $b->[1] }
                           map {
                               [ $queue{$_}, $bestness{$_} ]
                           } keys %queue ]})->[0];

        # This is the node we want, so we reconstruct the path back and save it
        # off.
        if ($current->is($self->{_end})) {

            my @path = ();
            while (defined $current) {
                unshift (@path, $current);
                $current = $previous{$current};
            }
            $self->{_path} = \@path;

            return 0;
        }

        # Remove from the open set, and add to the closed set
        delete ($queue{$current});
        $visited{$current} = $current;

        # Process all nodes adjacent to the current node
        for my $node ($current->adjacent_nodes()) {

            # Calculate the distance from start -> node using the path length of
            # our current node
            my $path_len_guess = $path_len{$current} + $current->distance($node);

            # If it has already been processed, and the old path is better than
            # the new, we can jump to the next iteration
            next if (exists $visited{$node} and $path_len{$node} < $path_len_guess);

            # If we need create it (not already in the queue) or we need to
            # update about a shorter path, do so.
            if (not exists $queue{$node} or $path_len_guess < $path_len{$node}) {
                $previous{$node} = $current;
                $path_len{$node} = $path_len_guess;
                $distance{$node} = $self->{_end}->calc_distance($node) unless (defined $distance{$node});
                $bestness{$node} = $path_len_guess + $distance{$node};

                $queue{$node} = $node unless (exists $queue{$node});
            }

            # Implicit case: exists in queue, but no better path: do nothing
        }

        $last_current = $current;

        return 1;
    };
}

1;
