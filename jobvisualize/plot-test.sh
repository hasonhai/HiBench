#!/bin/bash
# To plot the figure
# plot-test [input-dir] [output] [duration] [number_of_nodes]
echo "set term png size 800,800
set mxtics 1
set mytics 1
set xlable 'Time (s)'
set ylable 'Server index'
set xrange [0:$3]
set yrange [0:$4]
set grid
set output '$2'
plot '${1}/am.delays' title 'Application Master', '${1}/datanode.delays' title 'Datanode', '${1}/map.delays' title 'Mapper', '${1}/namenode.delays' title 'Namenode', '${1}/nodemanager.delays' title 'NodeManager',  '${1}/reduce.delays' title 'Reducer',  '${1}/yarn.delays' title 'Resource Manager'" | gnuplot

