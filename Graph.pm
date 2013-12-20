package Graph;

#use strict;
#use warnings;

use Graph::Node;

#########################################
## Class Functions                      #
#########################################

# Constructor
sub new {
    my $class = shift;

    my $self = {
        _nodes => [@_],
    };

    bless ($self, $class);

    return $self;
}

# Getter for nodes
sub nodes {
    my ($self) = @_;

    return @{$self->{_nodes}};
}

# Getter for edges
sub edges {
    my ($self) = @_;

    my $edges = {};
    for my $node ($self->nodes()) {
        for my $other ($node->adjacent_nodes()) {
            my $key = $node->edge_key ($other);

            $edges->{$key} = [$node, $other]
                unless (exists $edges->{$key});
        }
    }

    return $edges;
}

# Getter for start/end nodes. In this case defined by the nodes with the
# furthest distance, that does not have a direct link.
sub endpoints {
    my ($self) = @_;

    my ($start, $end, $dist) = (undef, undef, undef);

    for my $node ($self->nodes()) {
        # Select non-adjacent nodes, calculate distance, sort and select the
        # furthest node.
        my @possibles =
            sort { $b->[1] <=> $a->[1] }
                map { [$_, $_->calc_distance ($node)] }
                    grep { not $node->connects($_) }
                        $self->nodes();

        if (scalar @possibles) {
            if (not defined $dist or
                $possibles[0]->[1] > $dist) {
                $start = $node;
                $end   = $possibles[0]->[0];
                $dist  = $possibles[0]->[1];
            }
        }
    }

    return ($start, $end);
}

# Add a node
sub insert {
    my ($self, $node) = @_;

    push ($self->{_nodes}, $node);
}

# Empty the graph
sub clear {
    my ($self) = @_;

    $self->{_nodes} = [];
}

# Print out the degree sequence
sub degree_seq {
    my ($self) = @_;

    return sort { $b <=> $a } map { $_->degree() } $self->nodes();
}

# Print out adjacency lists
sub str {
    my ($self, %args) = @_;

    # Fix the index of the nodes, to allow an internally consistent
    # representation.
    my %index; # Translate node to index
    my @nodelist; # Translate index to node
    {
        my $i = 0;
        for (@{$self->{_nodes}}) {
            $index{$_} = $i;
            push (@nodelist, $_);
            ++$i;
        }
    }

    # Print each node like so:
    # index:coord:adjacent nodes
    #  |   |  |  |    |
    #  |   |  |  |    |     ,| Integer identifier for this node. Padded
    #   `--|--|--|----|-----|| with 0 or more spaces on the left side
    #      |  |  |    |     `| to make it more readable.
    #      |  |  |    |
    #      |  |  |    |     ,|
    #       `-|--+----|-----|| Field separators are a single colon (:)
    #         |       |     `|
    #         |       |
    #         |       |     ,| The coordinates of the node, in the form:
    #         '-------|-----|| (x,y). x and y are integers.
    #                 |     `|
    #                 |
    #                 |     ,| List of the indexes of the nodes adjacent
    #                 '-----|| to the current node. The nodes indexes are
    #                       `| separated by one or more spaces.

    # Nodes
    my $output = join (
        $/,
        map {
            sprintf (
                "%d:%s:%s",
                $index{$_}, $_->str(),
                join (
                    ' ',
                    map { sprintf('%d', $index{$_} ) } $_->adjacent_nodes()
                  )
            ) } @nodelist
        );

    return $output;
}

1;
