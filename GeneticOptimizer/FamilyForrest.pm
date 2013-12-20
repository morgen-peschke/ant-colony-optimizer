package GeneticOptimizer::FamilyForrest;

use strict;
use warnings;

#########################################
## Constructor                          #
#########################################
sub new {
    my ($class, %args) = @_;

    my $self = {
        nodes => [],
    };

    bless ($self, $class);

    return $self;
}

#########################################
## Public interface                     #
#########################################
sub nodes {
    my ($self, @nodes) = @_;

    return @{$self->{nodes}} unless (scalar @nodes);
    return (@{$self->{nodes}})[@nodes];
}

sub add {
    my ($self, %args) = @_;

    my ($p1_id, $p2_id) = ( $args{parents}->[0] ,
                            $args{parents}->[1] );

    my ($p1, $p2) = (undef, undef);

    $p1 = $self->{nodes}[$p1_id]
        if (defined $p1_id);

    $p2 = $self->{nodes}[$p2_id]
        if (defined $p2_id);

    my $node  = {
        p1         => $p1,
        p2         => $p2,
        genome     => $args{genome},
        score      => $args{score},
        generation => $args{generation},
    };
    push (@{$self->{nodes}}, $node);

    $node->{id} = $#{$self->{nodes}};

    return $node->{id};
}

#########################################
## Display Functions                    #
#########################################
sub display {
    my ($self, %args) = @_;

    my $node = defined $args{node}
        ? $self->{nodes}[$args{node}]
        : $self->{nodes}[-1];

    $self->walk (
        node   => $node,
        sub    => \&_print,
        args   => {
            indent    => '',
            stringify => $args{stringify},
            fd => $args{fd}
        }
    );
}

sub walk {
    my ($self, %args) = @_;

    # Error checking
    return          unless (defined $args{node});
    $args{last} = 1 unless (defined $args{last});
    $args{sub}  = \&{$args{sub}};

    # Run the function, which should return the arguments to it's children.
    my %new_args  =
        $args{sub}->($args{node},
                     $args{last},
                     %{$args{args}});

    # Recurse into the children
    $self->walk (
        node => $args{node}->{p1},
        last => 0,
        sub  => $args{sub},
        args => \%new_args,
    );

    $self->walk (
        node => $args{node}->{p2},
        last => 1,
        sub  => $args{sub},
        args => \%new_args,
    );
}

# Algorithm from
# http://stackoverflow.com/a/1649223/1188897
sub _print {
    my ($node, $last, %args) = @_;

    my $indent = $args{indent}    || '';
    my $strsub = $args{stringify} || sub {
        return sprintf ('[%d]', $_[0]->{id})
    };

    my $fd = $args{fd};

    print { $fd } $indent . '|' . $/
        unless ($indent eq '');

    print { $fd } $indent
        . ($last ? '\_' :  '|_' )
        . $strsub->($node)
        . $/;

    $args{indent} = $indent . ($last ? '  ' : '| ');

    return (%args);
}

1;
