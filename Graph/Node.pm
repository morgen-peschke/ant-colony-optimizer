package Graph::Node;

#use strict;
#use warnings;

#########################################
## Class Functions                      #
#########################################

#########################################
## . Constructor                        #
#########################################

# Constructor
sub new {
    my ($class, %args) = @_;

    my $self = {
        _x         => $args{x}           || 0,
        _y         => $args{y}           || 0,
        _adj_nodes => {}
    };

    return bless ($self, $class);
}

#########################################
## . Getters                            #
#########################################

# Returns an (x,y) coordinate hash
sub loc {
    my ($self, %args) = @_;

    $self->{_x} = $args{x} if (defined $args{x});
    $self->{_y} = $args{y} if (defined $args{y});

    return (x => $self->{_x} ,
            y => $self->{_y} );
}

# Returns the degree of the node
sub degree {
    my $self = shift;

    return scalar keys $self->{_adj_nodes};
}

# Calculate distance
sub calc_distance {
    my ($self, $other) = @_;

    return 0 unless (verify_class($other, 'Graph::Node'));

    my %s = $self->loc();
    my %e = $other->loc();

    my $len = sqrt(
        ($e{x} - $s{x}) ** 2 +
        ($e{y} - $s{y}) ** 2
    );

    return $len;
}

#########################################
## . Edge Functions                     #
#########################################

# Checks for adjacency
sub connects {
    my ($self, $other) = @_;

    return (defined $other and exists $self->{_adj_nodes}{$other});
}

# Return all adjacent nodes
sub adjacent_nodes {
    my $self = shift;
    return map { $_->{node} } values ($self->{_adj_nodes});
}

# Resolve an adjacent node
sub adjacent_node {
    my ($self, $other) = @_;
    return $self->{_adj_nodes}{$other}{node};
}

# Return information on a given edge
sub edge {
    my ($self, $other) = @_;

    return undef unless ($self->connects($other));

    return $self->{_adj_nodes}{$other};
}

# Get distance
sub distance {
    my ($self, $other) = @_;

    return -1 unless (exists $self->{_adj_nodes}{$other});

    return $self->{_adj_nodes}{$other}{dist};
}

# Add a connecting node (bidirectional)
sub attach {
    my ($self, $other) = @_;

    return 0 unless (verify_class($other, 'Graph::Node'));

    my $len = $self->calc_distance ($other);
    my $key = $self->edge_key ($other);

    $self->{_adj_nodes}{$other} = {
        dist => $len,
        node => $other,
        key  => $key,
    };

    $other->{_adj_nodes}{$self} = {
        dist => $len,
        node => $self,
        key  => $key
    };

    return 1;
}

# Disconnects from a node (bidirectional)
sub detatch {
    my ($self, $other) = @_;

    delete $self->{_adj_nodes}{$other};
    delete $other->{_adj_nodes}{$self};
}

# Gets a distinct key for an edge
sub edge_key {
    my ($self, $other) = @_;

    # Sort by x, then y, coordinates, convert to a string and concatenate
    return join (
        '',
        map { $_->[0]->str() }
            sort { $a->[1] <=> $b->[1] || $a->[2] <=> $b->[2] }
                map { [$_, $_->{_x}, $_->{_y} ] }
                      @_
    );
}

#########################################
## . Output Functions                   #
#########################################

# Stringify node and all connected nodes
sub repr {
    my $self  = shift;
    my $width = shift || 0;

    return sprintf (
        "(%*d, %*d) -> ",
        $width, $self->{_x},
        $width, $self->{_y},
    ) . join (
        ', ',
        map { $_->{node}->str($width) }
            values ($self->{_adj_nodes})
        );
}

# Stringify node
sub str {
    my $self  = shift;
    return sprintf ("(%f,%f)",
                    $self->{_x},
                    $self->{_y});
}

#########################################
## . Testing Functions                  #
#########################################

# Checks for equality
sub is {
    my ($self, $other) = @_;

    return 0 unless (verify_class($other, 'Graph::Node'));

    return ($self->{_x} == $other->{_x} &&
            $self->{_y} == $other->{_y} );
}

# Helper to check class type
sub verify_class {
    my ($target, $class) = @_;

    return $target if (eval { $target->isa($class); });
    return 0;
}

1;
