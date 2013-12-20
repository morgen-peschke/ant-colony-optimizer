#!/bin/bash

DATADIR='raw-data'
SCRIPTDIR='report-generation-scripts'

for f in "${DATADIR}/graph"*
do
    graph_num="${f#$DATADIR/graph}"
    graph_num="${graph_num%.txt}"
    echo "$graph_num" "$("${SCRIPTDIR}"/graph-dump-to-node-count.pl "$f")"
done
