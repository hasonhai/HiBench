#!/bin/bash

# get current directory
DIR=`dirname "$0"`
DIR=`cd "$DIR"; pwd`
#
export KEY="${DIR}/shk_eurecom.pem"         # Key to access each host. Should be one key only for every host.

# Get all nodes in the cluster
export DOMAINNAME="novalocal" #should be careful, domain name may be difference between services
# nodemanager nodes, we assume that datanodes and nodemanagers is install on same group of machines.
${MAPRED_EXECUTABLE} job -list-active-trackers | sort | cut -d'_' -f2 | cut -d':' -f1 | sed "s/$/.${DOMAINNAME}/" > ${DIR}/servers.lst
#TODO: get datanode list then append to servers.lst
#TODO: get namenode address then assign to HADOOPNN and append to servers.lst
#TODO: get yarn resource manager address then assign to YARNRM and append to servers.lst
#TODO: sort servers.lst and remove duplicated nodes if one node run many services
export CLUSTER="${DIR}/servers.lst"         # List of host in the cluster
#TODO: auto generate map.txt from servers.lst
gawk '{ print $0 "->" i++ }' ${CLUSTER} > ${DIR}/map.txt
export MAPFILE="${DIR}/map.txt"             # for replacing server name by number to display on y-axis when visualizing
export DATAOUT="${DIR}/../logs/tmp"         # firstly storing in tmp, later change into application_id dir
export PACKAGE_COLLECT="FALSE"              # TRUE or FALSE, remember to use upper case. To collect network package or not.

# variable to get logs (specific for HDP from Hortonworks, should change if run with Cloudera CHD)
export MAXLINE=4000 # We will take only max 4000 last lines in the logs of service
export YARNUSER=yarn
export HDFSUSER=hdfs
export YARNRM="master.$DOMAINNAME"                                                     # Resource Manager Location
export HADOOPNN="master.$DOMAINNAME"                                                   # Namenode Location
export YARNLOGBASE=/var/log/hadoop-yarn/yarn
export HDFSLOGBASE=/var/log/hadoop/hdfs
export YARNRMLOGFILE="$YARNLOGBASE/yarn-$YARNUSER-resourcemanager-$YARNRM.log"       # On master node
export YARNNMLOGFILE="$YARNLOGBASE/yarn-$YARNUSER-nodemanager-*.$DOMAINNAME.log"     # On slave nodes
export HADOOPNNLOGFILE="$HDFSLOGBASE/hadoop-$HDFSUSER-namenode-$HADOOPNN.log"        # On master node
export HADOOPDNLOGFILE="$HDFSLOGBASE/hadoop-$HDFSUSER-datanode-*.$DOMAINNAME.log"    # On slave nodes
