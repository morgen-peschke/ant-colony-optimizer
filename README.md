ant-colony-optimizer
====================

An implementation of a hybrid Ant Colony Optimization algorithm to find the
shortest path through a graph, run through a genetic algorithm to tweak the
optimization parameters.

About
-----

This project came into being as a way of experimenting with genetic algorithms
and a curiosity about default values. The suggested values for the parameters of
the Ant Colony variants seemed to be too 'neat', but I didn't see a way of
calculating them. Genetic programming techniques provide an effective way of
arriving at sane default values.

This was also a nice chance to get familiar with the Ant Colony variations and
create a hybrid meta version that, with the appropriate parameters, can act as
any of the variants.

Dependencies
------------
Carp::Always
Data::Dumper
Exporter::Tidy

Usage
-----

The intended work flow is to first run optimize.pl, then to run
generate-reports.sh to process the data in raw_data into nice graphs that are
much, much easier to work with.

Be advised that this will take some time, as the whole process runs in about 9
hours on my 2 yr old Dell netbook. If this were adapted to a real-world
application, the algorithm whole be run once to generate the parameters that
would be plugged into a production system, sacrificing a long initial run for
speed gains in each iteration on the production system.
