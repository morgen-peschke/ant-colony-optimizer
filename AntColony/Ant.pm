package AntColony::Ant;

use strict;
use warnings;

use Graph::Node;

# Constants
sub NODE        () { 0 }
sub PATH_LENGTH () { 1 }
sub PATH_TRACE  () { 2 }
sub VISITED     () { 3 }
sub ID          () { 4 }
sub LIVING      () { 5 }

my $id_counter;
#########################################
## Public Functions                     #
#########################################
sub new {
    my ($class, $start) = @_;

    my $self = [];
    bless ($self, $class);

    return $self->init($start);
}

sub reset_counter { $id_counter = 0 }
sub reset {
    return $_[0]->init(
        $_[0]->[PATH_TRACE][0]
    );
}

sub kill {
    $_[0]->[LIVING] = 0;
    return $_[0];
}

sub id          { return   $_[0]->[ID]          }
sub is_alive    { return   $_[0]->[LIVING]      }
sub current     { return   $_[0]->[NODE]        }
sub path        { return @{$_[0]->[PATH_TRACE]} }
sub path_length { return   $_[0]->[PATH_LENGTH] }

sub neighbors {
    return $_[0]->[NODE]->adjacent_nodes();
}

# Selects the unvisited adjacent nodes of an ant
sub get_potentials {
    my ($self) = @_;
    return
        grep { not $self->visited ($_) }
            $self->neighbors;
};


sub visited {
    my ($self, $node) = @_;
    return exists $self->[VISITED]{int($node)};
}

sub move_to {
    my ($self, $new) = @_;

    # Dereferencing through the current node is necessary, as the value returned
    # from rand_biased is a hash of that reference rather than the reference itself.
    $new = $self->[NODE]->adjacent_node($new);

    # Add the new node to the trace
    push (@{$self->[PATH_TRACE]}, $new);

    # Mark the new node as visited
    $self->[VISITED]{int($new)} = 1;

    # Add the distance traveled
    $self->[PATH_LENGTH] += $self->[NODE]->distance($new);

    # Set the new node location
    $self->[NODE] = $new;
}

#########################################
## Helpers                              #
#########################################
sub init {
    my ($self, $start) = @_;

    reset_counter() unless (defined $id_counter);

    $self->[NODE]        = $start;
    $self->[PATH_LENGTH] = 0;
    $self->[PATH_TRACE]  = [$start];
    $self->[VISITED]     = {int($start) => 1};
    $self->[ID]          = ++$id_counter;
    $self->[LIVING]      = 1;

    return $self;
};

1;
