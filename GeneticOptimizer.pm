package GeneticOptimizer;

#use strict;
#use warnings;

use GeneticOptimizer::FamilyForrest;

#########################################
## Constructor                          #
#########################################

sub new {
    my ($class, %args) = @_;

    my $self = {
        fitness     => $args{fitness},
        population  => $args{population}  || 20,
        sample_size => $args{sample_size} || 5,

        this_generation => 0,
        max_generations => $args{max_generations},

        solutions     => [],
        ancestry_tree =>
            GeneticOptimizer::FamilyForrest->new(),
    };

    #################
    # Error checking
    #
    die "GeneticOptimizer::new failure: missing pattern"
        unless (defined $args{pattern});

    die "GeneticOptimizer::new failure: zero population is useless"
        unless (defined $args{population});

    die "GeneticOptimizer::new failure: missing fitness function"
        unless (defined $args{fitness});

    # Create actual class
    bless ($self, $class);

    ##########################
    # Seed initial population
    #
    $args{pattern}->current_generation (0);
    $args{pattern}->max_generation ($self->{max_generations});

    for (1 .. $args{population}) {
        my $solution             = $args{pattern}->derive();
        my ($fitness, $metadata) = $self->fitness ($solution);

        my $id = $self->{ancestry_tree}->add (
            parents    => [undef, undef],
            genome     => $solution,
            score      => $fitness,
            metadata   => $metadata,
            generation => 0,
        );

        push (@{$self->{solutions}}, {
            id       => $id,
            fitness  => $fitness,
            genome   => $solution,
            metadata => $metadata,
            parents  => [undef, undef],
        });
    }

    return $self->sort_solutions;
}

#########################################
## Convenience functions                #
#########################################

# Accessors
sub solutions   { return @{$_[0]->{solutions}} }
sub best_id     { return   $_[0]->{solutions}[0]{id}      }
sub best_score  { return   $_[0]->{solutions}[0]{fitness} }
sub best_genome { return   $_[0]->{solutions}[0]{genome}  }

sub this_generation { return $_[0]->{this_generation} }
sub max_generations { return $_[0]->{max_generations} }

sub ancestral_tree { return $_[0]->{ancestry_tree} }

sub maxed_out {
    my ($self) = @_;
    return not (
        $self->{this_generation} < $self->{max_generations}
    );
}

sub set_fitness { $_[0]->{fitness} = $_[1] }

# Fitness functions
sub fitness {
    my ($self, $genome) = @_;
    return $self->{fitness}->($genome)
}

# Thank you http://geneticprogramming.us/Fitness.html
sub adjust_fitness { return 1.0 / ($_[0] + 1.0) }

# Sorts solutions by fitness rating
sub sort_solutions {
    my ($self) = @_;

    $self->{solutions} = [
        sort { $a->{fitness} <=> $b->{fitness} } @{$self->{solutions}}
    ];

    return $self;
}

#########################################
## Step functions                       #
#########################################

# Executes a single step in the genetic optimization.
# Returns 0 if the algorithm has completed
# Returns 1 otherwise
sub step {
    my ($self) = @_;

    # Check for passing max iterations
    return 0 if ($self->maxed_out);

    # Check for best possible solution
    return 0 if ($self->best_score == 0);

    # Increment generation number
    $self->{this_generation} += 1;

    # Generate the children
    my @children = ();
    while (scalar @children < $self->{population}) {
        my $parent_1 = tournament_select ($self->{sample_size}, $self->{solutions});
        my $parent_2 = tournament_select ($self->{sample_size}, $self->{solutions});

        my $child   = $parent_1->{genome}->mix($parent_2->{genome});
        my ($fitness, $metadata) = $self->fitness($child);

        my $id = $self->{ancestry_tree}->add (
            parents    => [$parent_1->{id}, $parent_2->{id}],
            genome     => {$child->hash},
            score      => $fitness,
            metadata   => $metadata,
            generation => $self->this_generation,
        );

        push (@children, {
            id       => $id,
            fitness  => $fitness,
            genome   => $child,
            metadata => $metadata,
            parents  => [$parent_1->{id}, $parent_2->{id}],
        });
    }

    $self->{solutions} = \@children;
    $self->sort_solutions;

    return 1;
}

# Selects a tournament of size N randomly, and picks the best solution out of
# that set
sub tournament_select {
    my ($size, $pool) = @_;

    my @candidates = ();

    while (scalar @candidates < $size) {
        my $index = utils::rint (0, scalar @{$pool});

        push (@candidates, $pool->[$index]);
    }

    @candidates = sort { $a->{fitness} <=> $b->{fitness} } @candidates;

    return $candidates[0];
}

1;
