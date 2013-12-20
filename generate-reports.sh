#!/bin/bash
SCRIPTS='./report-generation-scripts'

rm data/*

echo "$(date)" '| Calculating A* path lengths'
"$SCRIPTS"/calculate-astar-lengths.sh > data/astar-lengths.txt

echo "$(date)" '| Aggregating node and edge counts'
"$SCRIPTS"/generate-nodes-and-edges-data.sh > data/nodes-and-edges.data

echo "$(date)" '| Calculating top 10% data sets'
"$SCRIPTS"/calculate-colony-stats.pl  > data/colony-scores.data

echo "$(date)" '| Make the graph for part 2'
"$SCRIPTS"/make-part-2-graph.gplot

echo "$(date)" '| Make the graphs for part 3'
"$SCRIPTS"/make-part-3-graph.gplot

echo "$(date)" '| Make the graph for part 4'
"$SCRIPTS"/make-part-4-graph.gplot

echo "$(date)" '| Make the graph for part 5'
"$SCRIPTS"/make-part-5-graph.gplot

echo "$(date)" '| Make the graph for part 6'
"$SCRIPTS"/make-part-6-graph.gplot

echo "$(date)" '| Converting ps to pdf'
ps2pdf data/part-2.ps data/part-2.pdf
ps2pdf data/part-3.1.ps data/part-3.1.pdf
ps2pdf data/part-3.2.ps data/part-3.2.pdf
ps2pdf data/part-4.ps data/part-4.pdf
ps2pdf data/part-5.ps data/part-5.pdf
ps2pdf data/part-6.ps data/part-6.pdf

echo "$(date)" '| Cleaning up'
rm fit.log
rm data/*.ps
rm data/astar-lengths.txt
rm data/colony-scores.data
rm data/nodes-and-edges.data
