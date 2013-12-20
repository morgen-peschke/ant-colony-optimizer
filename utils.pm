package utils;

use strict;
use warnings;

# Similar to map, but operates on runs of adjacent elements.
sub map_nata (&$@){
    my ($sub, $width, @array) = @_;

    $sub = \&{$sub}; # Verify this is CODE

    my @return_values = ();

    my ($s, $e) =

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

# Iterates over a list
sub iter {
    my ($l, $i) = (\@_, 0);

    return sub {
        return ($i < scalar @$l) ? $l->[$i++] : ();
    }
}

# iterates over a list in blocks of n consecutive (overlapping) elements.
sub iter_nata ($@) {
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
# Modified to avoid using a hash unnecessarily.
sub rbiased {
    my @biases = @_;

    my ($sum, $index, $rand) = (0, 0);

    for ( @biases ) {
        $rand = $index
            if (rand($sum += $_) <  $_);
        ++$index;
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


1;
