#!/bin/bash

DATADIR='raw-data'
SCRIPTDIR='report-generation-scripts'

for f in "${DATADIR}/astar"*
do
    graph_num="${f#$DATADIR/astar}"
    graph_num="${graph_num%.txt}"
    echo "$graph_num" "$("${SCRIPTDIR}"/coord-dump-to-length.pl "$f")"
done
