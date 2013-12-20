package Genome;

use strict;
use warnings;

use utils;

sub TYPE_INT   () { 0 }
sub TYPE_FLOAT () { 1 }
sub TYPE_BOOL  () { 2 }

sub TRUE  () { 1 }
sub FALSE () { 0 }

sub CROSSOVER () { 0 }
sub AVERAGE   () { 1 }
sub MUTATE    () { 2 }
sub PASS      () { 3 }

#########################################
## Constructor                          #
#########################################
sub new {
    my ($class, %args) = @_;

    my $self = {
        probabilities => [
            $args{p_cross}   || 0.750,
            $args{p_average} || 0.083,
            $args{p_mutate}  || 0.083,
            undef,
        ],

        generation_now => 0,
        generation_max => 0,
        generation_dep => $args{time_dependence} || 0.5,

        gene_names  => [],
        gene_types  => [],
        gene_values => [],
        gene_bounds => [],
    };

    # Probability of passing is the probability is the leftover from the other
    # probabilities. It will be negative if the other probabilities sum to a
    # number greater than 1.
    $self->{probabilities}[PASS] = 1 -
        $self->{probabilities}[CROSSOVER] -
            $self->{probabilities}[AVERAGE] -
                $self->{probabilities}[MUTATE];

    die "Genome::new error: probabilities cannot exceed 1"
        if ($self->{probabilities}[PASS] < 0);

    bless ($self, $class);
}

#########################################
## Specification functions              #
#########################################
# Generation info specifier
sub generation {
    my ($self, %args) = @_;

    $self->{generation_now} = $args{now} if (defined $args{now});
    $self->{generation_max} = $args{max} if (defined $args{max});
    $self->{generation_dep} = $args{dependence} if (defined $args{dependence});

    return $self;
}

# Adds an item to the genome
# Arguments:
#  type  : Type of item, one of TYPE_{BOOL,INT,FLOAT}
#  name  : Identifier (optional, defaults to 'Unnamed')
#  value : Value (optional, will be chosen randomly if omitted)
#  upper : Maximum upper bound (not inclusive, may be omitted)
#  lower : Minimum lower bound (inclusive, may be omitted)
sub append {
    my ($self, %args) = @_;

    my $value = $args{value};
    my $type  = $args{type};
    my $name  = $args{name}  || 'Unnamed';
    my $upper = $args{upper} || 1;
    my $lower = $args{lower} || 0;

    die "Genome::append error: invalid bounds specification"
        if ($args{type}  != TYPE_BOOL    and
            $args{upper} <= $args{lower} );

    die "Genome::append error: missing type specification"
        unless (defined $args{type} and ($args{type} == TYPE_INT   or
                                         $args{type} == TYPE_FLOAT or
                                         $args{type} == TYPE_BOOL  ));

    # Choose random default values
    unless (defined $value) {
        if    ($type == TYPE_INT  ) {
            $value = utils::rint ($lower, $upper);
        }
        elsif ($type == TYPE_FLOAT) {
            $value = utils::rfloat ($lower, $upper);
        }
        elsif ($type == TYPE_BOOL ) {
            $value = rand () > 0.5;
        }
    }

    push (@{$self->{gene_names}}, $name);
    push (@{$self->{gene_types}}, $type);
    push (@{$self->{gene_values}}, $value);
    push (@{$self->{gene_bounds}}, {
        upper => $upper,
        lower => $lower,
    });

    return $self;
}

# Creates a new genome using the current as a pattern, but random values
sub derive {
    my ($self) = @_;

    my $new = Genome->new (
        p_cross   => $self->{probabilities}[CROSSOVER],
        p_mutate  => $self->{probabilities}[MUTATE],
        p_average => $self->{probabilities}[AVERAGE],
    );

    for (my $i = 0; $i < scalar @{$self->{gene_values}}; ++$i) {
        $new->append (
            type  => $self->{gene_types}[$i],
            name  => $self->{gene_names}[$i],
            upper => $self->{gene_bounds}[$i]{upper},
            lower => $self->{gene_bounds}[$i]{lower},
        );
    };

    $new->{generation_max} = $self->{generation_max};
    $new->{generation_now} = $self->{generation_now};
    $new->{generation_dep} = $self->{generation_dep};

    return $new;
}

# Duplicates a genome
sub clone {
    my ($self) = @_;

    my $new = Genome->new (
        p_cross   => $self->{probabilities}[CROSSOVER],
        p_mutate  => $self->{probabilities}[MUTATE],
        p_average => $self->{probabilities}[AVERAGE],
    );

    for (my $i = 0; $i < scalar @{$self->{gene_values}}; ++$i) {
        $new->append (
            type  => $self->{gene_types}[$i],
            name  => $self->{gene_names}[$i],
            value => $self->{gene_values}[$i],
            upper => $self->{gene_bounds}[$i]{upper},
            lower => $self->{gene_bounds}[$i]{lower},
        );
    };

    $new->{generation_max} = $self->{generation_max};
    $new->{generation_now} = $self->{generation_now};
    $new->{generation_dep} = $self->{generation_dep};

    return $new;
}

#########################################
## Output functions                     #
#########################################
# Converts the genome into a hash of values
sub hash {
    my ($self) = @_;

    my %hash = ();

    for (my $i = 0; $i < scalar @{$self->{gene_values}}; ++$i) {
        my $key = $self->{gene_names}[$i];
        my $val = $self->{gene_values}[$i];

        if (defined $hash{$key}) {

            if (ref $hash{$key} eq 'ARRAY') {
                push (@{$hash{$key}}, $val);
            }
            else {
                my $old_val = $hash{$key};
                $hash{$key} = [$old_val, $val];
            }
        }
        else {
            $hash{$key} = $val;
        }
    }

    return %hash;
}

# Converts the genome into an array of values
sub array { return @{$_[0]->{gene_values}} }

# Returns the gene names in the order they will
# appear in $self->array
sub names { return @{$_[0]->{gene_names}} }

#########################################
## Recombination                        #
#########################################
sub mix {
    my ($self, $other) = @_;

    die "Genome::mix failure: genomes are not compatible (size)"
        if (scalar @{$self->{gene_names}} != scalar @{$other->{gene_names}});

    my $new = $self->clone();
    ++$new->{generation_now};

    my $src = 1;

    for (my $i = 0; $i < scalar @{$self->{gene_names}}; ++$i) {

        #############################
        # Error checking
        #
        die "Genome::mix failure: genomes are not compatible (type at index $i)"
            unless ($self->{gene_names}[$i]         eq $other->{gene_names}[$i]         and
                    $self->{gene_types}[$i]         == $other->{gene_types}[$i]         and
                    $self->{gene_bounds}[$i]{upper} == $other->{gene_bounds}[$i]{upper} and
                    $self->{gene_bounds}[$i]{lower} == $other->{gene_bounds}[$i]{lower} );

        my $action = utils::rbiased (@{$self->{probabilities}});

        #############################
        # Pass (simple copy)
        #
        if ($action == PASS) {

            # Simply copy the value from the source
            $new->{gene_values}[$i] = $src
                ? $self->{gene_values}[$i]
                : $other->{gene_values}[$i];
        }

        #############################
        # Mutation
        #
        elsif ($action == MUTATE) {

            # Bool mutation flips the value
            if ($self->{gene_types}[$i] == TYPE_BOOL) {
                $new->{gene_values}[$i] = not $self->{gene_values}[$i];
            }

            # Int and float mutation give random values
            #
            # Algorithm taken from "An Experimental Comparison of Binary and
            # Floating Point Representations in Genetic Algorithms" by Janikow
            # and Michalewicz - University of North Carolina
            elsif ($self->{gene_types}[$i] == TYPE_INT   or
                   $self->{gene_types}[$i] == TYPE_FLOAT ) {
                my $coin = utils::rint (0,2);

                my $old_val = $new->{gene_values}[$i];

                $new->{gene_values}[$i] =
                    $coin
                        ? $old_val + $new->rand_delta ($new->{gene_bounds}[$i]{upper} - $old_val)
                        : $old_val - $new->rand_delta ($old_val - $new->{gene_bounds}[$i]{lower});
            }
        }

        #############################
        # Average
        elsif ($action == AVERAGE) {
            # Bool Average flips the value.
            if ($self->{gene_types}[$i] == TYPE_BOOL) {
                $new->{gene_values}[$i] = not $self->{gene_values}[$i];
            }

            # Otherwise, the new value is the average of the other.
            else {
                $new->{gene_values}[$i] =
                    ($self->{gene_values}[$i] + $other->{gene_values}[$i])
                        / 2.;
            }
        }

        #############################
        # Crossover
        elsif ($action == CROSSOVER) {
            # Swap sources and do a simple copy
            $src = !$src;

            $new->{gene_values}[$i] = $src
                ? $self->{gene_values}[$i]
                : $other->{gene_values}[$i];
        }

        # Apply rounding to int values (makes processing easier to do it once here)
        $new->{gene_values}[$i] = int($new->{gene_values}[$i])
            if ($self->{gene_types}[$i] == TYPE_INT);
    }

    return $new;
}

#########################################
## Helper functions                     #
#########################################
# Generations getters / setters
sub current_generation {
    my ($self, $new) = @_;
    $self->{generation_now} = $new
        if (defined $new);

    return $self->{generation_now};
}

sub max_generation {
    my ($self, $new) = @_;
    $self->{generation_max} = $new
        if (defined $new);

    return $self->{generation_max};
}

# Helper for the mutations, gets less random as the generations increase.
sub rand_delta {
    my ($self, $range) = @_;
    my $t = $self->{generation_now};
    my $T = $self->{generation_max};
    my $b = $self->{generation_dep};

    return $range * (1. - rand () ** (1 - $t/$T) ** $b);
}

1;
