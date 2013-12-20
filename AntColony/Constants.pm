package AntColony::Constants;

use strict;
use warnings;

use Exporter::Tidy
    other => [ qw (
                      TRUE
                      FALSE

                      UPDATE_EACH_MOVE
                      UPDATE_AT_END

                      UPDATE_ALL_ANTS
                      UPDATE_ELITE_ANTS
                      UPDATE_CLOSE_ANTS
                      UPDATE_BEST_ANT

                      STATE_PRE_CYCLE
                      STATE_UPDATE_ANTS
                      STATE_MID_CYCLE
                      STATE_UPDATE_PHEROMONES
                      STATE_EXIT
              ) ];

# These *should* already exist
sub TRUE  () { 1 }
sub FALSE () { 0 }

# Controls when updates to the pheromones are made
sub UPDATE_EACH_MOVE () { 1 }
sub UPDATE_AT_END    () { 2 }

# Controls which ants get to do the updates
# Combining means that ants that match multiple
# criteria get extra update chances.
sub UPDATE_ALL_ANTS   () { 1 }    # Update everybody
sub UPDATE_ELITE_ANTS () { 2 }    # Per iteration best n ants
sub UPDATE_CLOSE_ANTS () { 4 }    # Per iteration, all within x%
sub UPDATE_BEST_ANT   () { 8 }    # Global best

# These will get inlined and save some comparison time inside the state machine
# transitions
sub STATE_PRE_CYCLE         () { 0 }
sub STATE_UPDATE_ANTS       () { 1 }
sub STATE_MID_CYCLE         () { 2 }
sub STATE_UPDATE_PHEROMONES () { 3 }
sub STATE_EXIT              () { 4 }

1;
