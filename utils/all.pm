package utils::all;

use strict;
use warnings;
use Data::Dumper;

use Exporter::Tidy
    list => [qw(
                   map_nata
                   itr_group
                   l_itr
                   i_itr_by_n
                   l_itr_by_n
           )],
    random => [qw(
                     rbiased
                     rint
                     rfloat
             )],
    other => [qw (
                     round
                     dumper
                     center
            )];

# Similar to map, but operates on runs of adjacent elements.
sub map_nata (&$@){
    my ($sub, $width, @array) = @_;

    $sub = \&{$sub}; # Verify this is CODE

    my @return_values = ();

    my @args = ();
    push (@args, shift @array)
        for (0..$width - 2);

    while (scalar @array) {
        push (@args, shift @array);
        push (@return_values, $sub->(@args));
        shift @args;
    }

    return @return_values;
}

# Iterates over a group of iterators in parallel.
sub itr_group {
    my @iters = @_;

    return sub {
        my @values = ();

        for my $i (@iters) {
            my @v = $i->();
            push (@values, [@v])
                if (scalar @v);
        }
        return @values;
    }
}

# Iterates over a list
sub l_itr {
    my ($l, $i) = (\@_, 0);

    return sub {
        return ($i < scalar @$l) ? $l->[$i++] : ();
    }
}

# iterates over an iterator in blocks of n consecutive (overlapping) elements.
sub i_itr_by_n ($@) {
    my ($width, $itr) = @_;

    my @args = ();
    push (@args, $itr->())
        for (0..$width - 2);

    return sub {
        my $v = $itr->();
        return () unless (defined $v);

        push  (@args, $v);
        shift  @args if (scalar @args > $width);

        return @args;
    }
}

# iterates over a list in blocks of n consecutive (overlapping) elements.
sub l_itr_by_n ($@) {
    my ($width, @array) = @_;

    my @args = ();
    push (@args, shift @array)
        for (0..$width - 2);

    return sub {
        return ()
            unless (scalar @array);

        push (@args, shift @array);
        shift @args if (scalar @args > $width);

        return @args;
    }
}

# Code from here: http://www.perlmonks.org/?node_id=158490
# Better explanation here: http://www.perlmonks.org/?node_id=1910
sub rbiased {
    my %bias = @_;

    my $sum = 0;
    my $rand;

    while ( my ($k, $v) = each %bias) {
        $rand = $k if (rand($sum += $v) < $v);
    }

    return $rand;
}

# Gets a random int between $min and $max
sub rint (;$$) {
    my ($min, $max) = @_;

    return int (rfloat ($min, $max));
}

# Gets a random float between $min and $max
sub rfloat (;$$) {
    my ($min, $max) = @_;

    if (!defined $min and !defined $max) { ($min, $max) = (0, 1)    }
    elsif                (!defined $max) { ($min, $max) = (0, $min) }

    return rand ($max - $min) + $min;
}

# Round to the nearest 10^n
sub round {
    my ($number, $n) = @_;

    $n = 1 unless defined $n;
    $n = 10 ** $n;

    return sprintf ('%.1f', $number / $n) * $n;
}

# Wrapper around Dumper to allow setting the depth
sub dumper {
    my ($depth, @vars) = @_;

    my $d = Data::Dumper->new (\@vars);
    $d->Maxdepth($depth);
    $d->Terse(1);

    return $d->Dump;
}

# Centers text in a column of a specified width
sub center {
    my ($text, $width) = @_;

    return sprintf (
        '%*s%*s',
        floor (($width + length ($text)) / 2),
        $text,
        ceil (($width - length ($text))/ 2), ''
    );
}

1;
