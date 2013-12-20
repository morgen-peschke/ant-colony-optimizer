package Graph::Generator;

#use strict;
#use warnings;

use Graph;
use Graph::Node;
use utils;

#########################################
## Control Function                     #
#########################################

sub generate {
    my %args = @_;

    die "Graph::Generator::generate : missing required parameter 'graph'"
        unless (defined $args{graph});

    my %context = (
        graph       => $args{graph},
        nodes       => $args{nodes}         || 10,
        sep         => $args{min_distance}  || 5,
        min_degree  => $args{min_degree}    || 2,
        max_degree  => $args{max_degree}    || 10,
    );

    generate_nodes         (%context);
    generate_spanning_tree (%context);
    generate_min_degree    (%context);
    generate_max_degree    (%context);

    return $context{graph};
}

#########################################
## Helper Functions                     #
#########################################

#########################################
## - Edge Generation                    #
#########################################

# Generate a helper function that generates the spanning tree, to guarantee
# connectivity. Returning a function wraps up the state in a disposable object
# that can be conveniently discarded.
sub generate_spanning_tree {
    my %context = @_;

    my @todo = $context{graph}->nodes();

    # Grow the tree from both ends, hopefully this will keep the paths short
    my $front = pop (@todo);
    my $back  = $front;

    while (scalar @todo) {
        # Holds info about the shortest trip
        my $f = { nearest => undef, distance => undef, index => 0 };
        my $b = { nearest => undef, distance => undef, index => 0 };

        # Search for the shortest node from the back and front
        my $i = 0;
        for my $other (@todo) {

            if ( (not defined $f->{nearest}) or
                 ($front->calc_distance($other) < $f->{distance}) ) {
                $f = {
                    nearest => $other,
                    distance => $front->calc_distance($other),
                    index    => $i
                };
            }

            if ( (not defined $b->{nearest}) or
                 ($back->calc_distance($other) < $b->{distance}) ) {

                $b = {
                    nearest  => $other,
                    distance => $back->calc_distance($other),
                    index    => $i,
                };
            }

            ++$i;
        }

        # Attach the shorter of the two.
        if ($f->{distance} <= $b->{distance}) {
            $front->attach ($f->{nearest});
            splice (@todo, $f->{index}, 1);
            $front = $f->{nearest};
        }
        else {
            $back->attach ($b->{nearest});
            splice (@todo, $b->{index}, 1);
            $back = $b->{nearest};
        }
    }
}

# Generate a helper function than creates random edges until every node has
# achieved at least the minimum degree specified
sub generate_min_degree {
    my %context = @_;

    # Nodes to work on (all, but will be parred down)
    my @start_points = $context{graph}->nodes();

    # Cache the degree for the next few operations
    @start_points = map { [$_->degree(), $_] } @start_points;

    # A quick check to make sure previous stages haven't caused it to have
    # problems yet.
    for (@start_points) {
        if ($_->[0] > $context{max_degree}) {
            die 'Graph::Generate::generate_min_degree: maximum degree exceeded, node ' . $_->[1]->str() . ' has degree ' . $_->[0];
        }
    }

    # Targets are those which have not yet hit their maximum. Cache is discarded.
    my @end_points = map { $_->[1] } grep { $_->[0] < $context{max_degree} } @start_points;

    # Filter out those which we do not have to work on, and discard the cache,
    # which is no longer needed
    @start_points  = map { $_->[1] } grep { $_->[0] < $context{min_degree} } @start_points;

    while (scalar @start_points) {

        # Get a random indexes from the sources
        my $index = utils::rint (0, scalar @start_points);
        my $start = $start_points[$index];

        # Filter the targets to prevent a self/duplicate match, then sort the
        # targets according to distance, and select closest one.
        my @tmp_tgts =
            map { $_->[0] }
                sort { $a->[1] <=> $b->[1] }
                    map { [$_, $_->calc_distance($start)] }
                        grep { not $_->is($start) || $_->connects($start)}
                            @end_points;

        my $end = $tmp_tgts[0];

        $start->attach($end);

        # Check if this changes the degree enough to recalculate the target or
        # source node lists
        if ($start->degree() >= $context{min_degree} or
            $end->degree()   >= $context{min_degree} ){
            @start_points = grep { $_->degree() < $context{min_degree} } @start_points;
        }

        if ($start->degree() == $context{max_degree} or
            $end->degree()   == $context{max_degree} ){
            @end_points = grep { $_->degree() < $context{max_degree} } @end_points;
        }
    }
};

# This will ensure that at least one node has the maximum degree
sub generate_max_degree {
    my %context = @_;

    # Working set is all nodes with less than the max degree
    my @pts = grep { $_->degree() < $context{max_degree}} $context{graph}->nodes();

    while (scalar @pts) {

        my $start = $pts[utils::rint (0, scalar @pts)];

        # Filter the targets to prevent a self/duplicate match, then sort the targets
        # according to distance, and select the closest candidate.
        my @tgts =
            map { $_->[0] }
                sort { $a->[1] <=> $b->[1] }
                    map { [$_, $_->calc_distance($start)] }
                        grep { not $_->is($start) || $_->connects($start) }
                            @pts;

        my $end = $tgts[0];

        $start->attach($end);

        last
            if ($start->degree() == $context{max_degree} or
                $end->degree()   == $context{max_degree} );
    }
}

#########################################
## - Node Generation                    #
#########################################

# Generates the nodes, returns 0 to signal there is nothing more to do
sub generate_nodes {
    my %context = @_;

    $context{graph}->clear();

    my ($sep, $grow)  = ($context{sep}, $context{sep} * 2);

    my ($min_x, $min_y) = (0, 0);
    my ($max_x, $max_y) = ($sep + $grow, $sep + $grow);

    my ($next_max_x, $next_max_y,
        $next_min_x, $next_min_y,
        %l);

 NODE:
    while (scalar $context{graph}->nodes() < $context{nodes}) {

        ($next_max_x, $next_max_y) = ($min_x, $min_y);
        ($next_min_x, $next_min_y) = ($max_x, $max_y);

        # Generate a new potential node in our available space
        my $node = new Graph::Node ( x => utils::rfloat ($min_x, $max_x) ,
                                     y => utils::rfloat ($min_y, $max_y) );

        # Check against other nodes
        for my $other ($context{graph}->nodes()) {
            # Take advantage to figure out the max node
            %l = $other->loc ();
            $next_max_x = $l{x} if ($next_max_x < $l{x});
            $next_max_y = $l{y} if ($next_max_y < $l{y});

            $next_min_x = $l{x} if ($next_min_x > $l{x});
            $next_min_y = $l{y} if ($next_min_y > $l{y});

            # If it is too close, increase our working area and try again.
            if ($node->calc_distance($other) < $sep) {
                $max_x += $sep; $max_y += $sep;
                $min_x -= $sep; $min_y -= $sep;

                next NODE;
            }
        }

        # Add the node, and optionally grow the target area
        $context{graph}->insert($node);

        %l = $node->loc();
        $next_max_x = $l{x} if ($next_max_x < $l{x});
        $next_max_y = $l{y} if ($next_max_y < $l{y});

        $next_min_x = $l{x} if ($next_min_x > $l{x});
        $next_min_y = $l{y} if ($next_min_y > $l{y});

        $next_max_x += $grow; $next_max_y += $grow;
        $next_min_x -= $grow; $next_min_y -= $grow;

        $max_x = $next_max_x if ($max_x < $next_max_x);
        $max_y = $next_max_y if ($max_y < $next_max_y);

        $min_x = $next_min_x if ($min_x > $next_min_x);
        $min_y = $next_min_y if ($min_y > $next_min_y);
    }

    # Normalize the results back into the positive numbers
    for my $n ($context{graph}->nodes) {
        %l = $n->loc ();
        $l{x} -= $min_x + $sep;
        $l{y} -= $min_y + $sep;
        $n->loc(%l);
    }
};

1;
