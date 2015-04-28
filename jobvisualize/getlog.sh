#!/bin/bash

# Command syntax: ./getlog.sh [HADOOP_CMD]
DIR=`dirname "$0"`
DIR=`cd "$DIR"; pwd`
source $DIR/conf/configure.sh
HADOOP_CMD=$*

mkdir -p $DATAOUT
# GENERATING LOGS
if [ $PACKAGE_COLLECT = "TRUE" ]; then
    # Copy script controlling tcpdump to all the hosts in the cluster
    echo "Package collect is enable. We are setting-up tcpdump for listenning on each node."
    echo "It will cost lot of space to store dump file"
    for SERVER in `cat $CLUSTER`; do
        scp -i $KEY controltcpdump.sh $USER@$SERVER:~/controltcpdump.sh
        ssh -i $KEY $USER@$SERVER "chmod a+x controltcpdump.sh"
    done
    # Start tcpdump on all hosts
    for SERVER in `cat $CLUSTER`; do
        ssh -i $KEY $USER@$SERVER "./controltcpdump.sh start dump_$SERVER.pcap"
    done
else
    echo "Package collect is disable. We only collect log from services for each job."
fi
# Run hadoopjob
time $HADOOP_CMD &> /dev/stdout | tee $DATAOUT/tee.tmp
export id=`gawk -F "_" ' /Submitting tokens for job/ {print $(NF-1) "_" $NF}' $DATAOUT/tee.tmp`
export jobid="job_$id"
export applicationid="application_$id"
finished=$( grep -c "Job $jobid completed successfully" $DATAOUT/tee.tmp )
if [ $finished -lt 1 ]; then echo 'Job fail!'; exit 1 ; fi

# Stop tcpdump on all hosts
if [ $PACKAGE_COLLECT = "TRUE" ]; then
    for SERVER in `cat $CLUSTER`; do
        ssh -i $KEY $USER@$SERVER "./controltcpdump.sh stop"
    done
fi

# COLLECTING LOGS
if [ $PACKAGE_COLLECT = "TRUE" ]; then
    echo "Collecting all pcap files from all hosts" # Some nodes may get data from other nodes
    for SERVER in `cat $CLUSTER`; do
        scp -i $KEY $USER@$SERVER:~/dump_$SERVER.pcap $DATAOUT/dump_$SERVER.pcap
        ssh -i $KEY $USER@$SERVER "rm -f *.pcap"
        tcpdump -nn -tttt -r $DATAOUT/dump_$SERVER.pcap | sed 's/\./,/' > $DATAOUT/dump_$SERVER.log
    done
fi

# Collect ResourceManager LOGS
ssh -i $KEY $USER@$YARNRM "tail -n $MAXLINE $YARNRMLOGFILE > yarn_$YARNRM.log"
scp -i $KEY $USER@$YARNRM:~/yarn_$YARNRM.log $DATAOUT/
ssh -i $KEY $USER@$YARNRM "rm -f yarn_$YARNRM.log"

# Collect NodeManager LOGS
for SERVER in `cat $CLUSTER`; do
    file_exist=$( ssh -i $KEY $USER@$SERVER "if [ -f $YARNNMLOGFILE ]; then echo 'existed'; fi" )
    if [ "$file_exist" = "existed" ]; then
        ssh -i $KEY $USER@$SERVER "tail -n $MAXLINE $YARNNMLOGFILE > nodemanager_$SERVER.log"
        scp -i $KEY $USER@$SERVER:~/nodemanager_$SERVER.log $DATAOUT/nodemanager_$SERVER.log
        ssh -i $KEY $USER@$SERVER "rm -f nodemanager_$SERVER.log"
    else echo "Datanode log not existed on $SERVER"
    fi
    file_exist="not_existed" # reset variable
done

# Collect NameNode LOGS
ssh -i $KEY $USER@$HADOOPNN "tail -n $MAXLINE $HADOOPNNLOGFILE > namenode_$HADOOPNN.log"
scp -i $KEY $USER@$HADOOPNN:~/namenode_$HADOOPNN.log $DATAOUT/
ssh -i $KEY $USER@$HADOOPNN "rm -f namenode_$HADOOPNN.log"

# Collect DataNode LOGS
for SERVER in `cat $CLUSTER`; do
    file_exist=$( ssh -i $KEY $USER@$SERVER "if [ -f $HADOOPDNLOGFILE ]; then echo 'existed'; fi" )
    if [ "$file_exist" = "existed" ]; then
        ssh -i $KEY $USER@$SERVER "tail -n $MAXLINE $HADOOPDNLOGFILE > datanode_$SERVER.log"
        scp -i $KEY $USER@$SERVER:~/datanode_$SERVER.log $DATAOUT/datanode_$SERVER.log
        ssh -i $KEY $USER@$SERVER "rm -f datanode_$SERVER.log"
    else echo "Datanode log not existed on $SERVER"
    fi
    file_exist="not_existed" # reset variable
done

# Parsing containers' logs
# Using "yarn logs -applicationId $applicationid" to get the log on HDFS
echo Collect application logs from HDFS...
applicationlog="$DATAOUT/$applicationid.log" # Log from all container will be stored here
yarn logs -applicationId $applicationid > $applicationlog 2> /dev/null #TODO: be careful when using executable directly
# List of containers and servers executing them
grep "Container:" $applicationlog | cut -d' ' -f2,4 --output-delimiter='_' | cut -d'_' -f1,2,3,4,5,6 > $DATAOUT/containername
grep "Container:" $applicationlog | cut -d' ' -f2,4,6 --output-delimiter='_' | cut -d'_' -f7 > $DATAOUT/container_server
# Starting line of each container
grep -n "Container:" $applicationlog | cut -d':' -f1 > $DATAOUT/lineindexstart   # Find where the container's log start
tail -n +2 $DATAOUT/lineindexstart | gawk '{print $1-1}' > $DATAOUT/lineindexend # Find where the container's log end
wc -l $applicationlog | cut -d' ' -f1 >> $DATAOUT/lineindexend
paste -d' ' $DATAOUT/containername $DATAOUT/lineindexstart $DATAOUT/lineindexend $DATAOUT/container_server > $DATAOUT/containers # Merge to onefile
rm -f $DATAOUT/containername $DATAOUT/lineindexstart $DATAOUT/lineindexend $DATAOUT/container_server
echo Seperate each container\'s logs to one syslog file
while read containerinfo; do
    containername=`echo "$containerinfo" | gawk '{print $1}'`
    servername=`echo "$containerinfo" | gawk '{print $4}'`
    startline=`echo "$containerinfo" | gawk '{print $2}'`
    endline=`echo "$containerinfo" | gawk '{print $3}'`
    sed -n "${startline},${endline}p" $applicationlog > $DATAOUT/${containername}_${servername}.log
    num=`grep -n -m 3 "Log Contents:" $DATAOUT/${containername}_${servername}.log | cut -d':' -f1 | tail -n 1 | gawk '{ print $1+1 }'`
    tail -n +$num $DATAOUT/${containername}_${servername}.log > $DATAOUT/${containername}_${servername}.syslog
    rm -f $DATAOUT/${containername}_${servername}.log
done < $DATAOUT/containers

echo Start to process logs
echo Combine all logs to one file per service
echo Combine yarn logs
gawk -v svr="$YARNRM" '{ print $0,svr}' $DATAOUT/yarn_$YARNRM.log > $DATAOUT/combined_yarn.log
YARNRMLOGFILE="$DATAOUT/combined_yarn.log"
echo Combine namenode logs
gawk -v svr="$HADOOPNN" '{ print $0,svr}' $DATAOUT/namenode_$HADOOPNN.log > $DATAOUT/combined_namenode.log
HADOOPNNLOGFILE="$DATAOUT/combined_namenode.log"

echo Combine datanode logs
for server in `cat $CLUSTER`; do
    if [ -f $DATAOUT/datanode_$server.log  ]; then
        gawk -v svr="$server" '{ print $0,svr}' $DATAOUT/datanode_$server.log >> $DATAOUT/combined_datanode.log
    fi
done
HADOOPDNLOGFILE="$DATAOUT/combined_datanode.log"

echo Combine nodemanager logs
for server in `cat $CLUSTER`; do
    if [ -f $DATAOUT/datanode_$server.log  ]; then
        gawk -v svr="$server" '{ print $0,svr}' $DATAOUT/nodemanager_$server.log >> $DATAOUT/combined_nodemanager.log
    fi
done
YARNNMLOGFILE="$DATAOUT/combined_nodemanager.log"

if [ "$PACKAGE_COLLECT" = "TRUE" ]; then
    for server in `cat $CLUSTER`; do
        # Before combining log, should separate between packet send and packet received
        gawk -v svr="$server" '{ print $0,svr}' $DATAOUT/dump_$server.log >> $DATAOUT/combined_pcap.log
    done
    PCAPLOG="$DATAOUT/combined_pcap.log"
fi

echo Parsing containers\' logs...
while read containerinfo; do
    containername=`echo $containerinfo | gawk '{ print $1 }'`
    containerid=`echo $containername | gawk -F "_" '{ print $6 }'`
    server=`echo $containerinfo | gawk '{ print $4 }'`
    if [ "$containerid" = "000001" ]; then
        echo Container $containername is Application Master
        gawk -v svr="$server" '{ print $0,svr}' $DATAOUT/${containername}_${server}.syslog > $DATAOUT/am.syslog
    else
        mapper_test=`grep -m 1 -c -e "Task 'attempt_${id}_m_[0-9]*_[0-9]*' done" $DATAOUT/${containername}_${server}.syslog`
        reducer_test=`grep -m 1 -c -e "Task 'attempt_${id}_r_[0-9]*_[0-9]*' done" $DATAOUT/${containername}_${server}.syslog`
        if [ "$mapper_test" = "1" ]; then
            echo "Container $containername is mapper -> append mapper logs to map.syslog"
            gawk -v svr="$server" '{ print $0,svr}' $DATAOUT/${containername}_${server}.syslog >> $DATAOUT/map.syslog
        elif [ "$reducer_test" = "1" ]; then
            echo "Container $containername is reducer -> append reducer logs to reduce.syslog"
            gawk -v svr="$server" '{ print $0,svr}' $DATAOUT/${containername}_${server}.syslog >> $DATAOUT/reduce.syslog
        else echo "Container $containername is not recognizable"
        fi
        #TODO: Distinguise between mapper to see if the job is running in parallel.
    fi
done < $DATAOUT/containers

echo Finding start time and end time from YARN logs file
export startline=`grep -n -s "Storing application with id $applicationid" $YARNRMLOGFILE | gawk -F ":" '{print $1}'`
export startdate=`gawk 'NR=='$startline-2' {print $0}' $YARNRMLOGFILE | gawk '{print $1}'`
export starttime=`gawk 'NR=='$startline-2' {print $0}' $YARNRMLOGFILE | gawk '{print $2}'`
echo "starttime"=$startdate $starttime
# old version
# export enddate=`grep -m 1 "Application removed - appId: $applicationid" $YARNRMLOGFILE | gawk '{print $1}'`
# export endtime=`grep -m 1 "Application removed - appId: $applicationid" $YARNRMLOGFILE | gawk '{print $2}'`
# new version
export enddate=`grep -m 1 "$applicationid unregistered successfully." $YARNRMLOGFILE | gawk '{print $1}'`
export endtime=`grep -m 1 "$applicationid unregistered successfully." $YARNRMLOGFILE | gawk '{print $2}'`
echo "endtime="$enddate $endtime

echo Filter only log records related to job $applicationid...
if [ "$PACKAGE_COLLECT" = "TRUE" ] ; then
gawk -v startd=$startdate -v startt=$starttime -v endd=$enddate -v endt=$endtime ' BEGIN {start=startd " " startt;end=endd " " endt}  $1 ~ startd {if ($1 " " $2 >= start) {if ($1 " " $2 <= end) print $0;}} ' $PCAPLOG > $DATAOUT/pcap.syslog
fi
gawk -v startd=$startdate -v startt=$starttime -v endd=$enddate -v endt=$endtime ' BEGIN {start=startd " " startt;end=endd " " endt}  $1 ~ startd {if ($1 " " $2 >= start) {if ($1 " " $2 <= end) print $0;}} ' $YARNRMLOGFILE > $DATAOUT/yarn.syslog
gawk -v startd=$startdate -v startt=$starttime -v endd=$enddate -v endt=$endtime ' BEGIN {start=startd " " startt;end=endd " " endt}  $1 ~ startd {if ($1 " " $2 >= start) {if ($1 " " $2 <= end) print $0;}} ' $YARNNMLOGFILE > $DATAOUT/nodemanager.syslog
gawk -v startd=$startdate -v startt=$starttime -v endd=$enddate -v endt=$endtime ' BEGIN {start=startd " " startt;end=endd " " endt}  $1 ~ startd {if ($1 " " $2 >= start) {if ($1 " " $2 <= end) print $0;}} ' $HADOOPNNLOGFILE > $DATAOUT/namenode.syslog
gawk -v startd=$startdate -v startt=$starttime -v endd=$enddate -v endt=$endtime ' BEGIN {start=startd " " startt;end=endd " " endt}  $1 ~ startd {if ($1 " " $2 >= start) {if ($1 " " $2 <= end) print $0;}} ' $HADOOPDNLOGFILE > $DATAOUT/datanode.syslog

# Add event mark at the beginning of line
if [ "$PACKAGE_COLLECT" = "TRUE" ] ; then
    gawk '{$1="PCAP     ";print $0}' $DATAOUT/pcap.syslog > $DATAOUT/PCAP.out
fi
gawk '{$1="AM       ";print $0}' $DATAOUT/am.syslog > $DATAOUT/AM.out
gawk '{$1="REDUCE   ";print $0}' $DATAOUT/reduce.syslog > $DATAOUT/REDUCE.out
gawk '{$1="MAP      ";print $0}' $DATAOUT/map.syslog > $DATAOUT/MAP.out
gawk '{$1="YARN     ";print $0}' $DATAOUT/yarn.syslog > $DATAOUT/YARN.out
gawk '{$1="DATAN    ";print $0}' $DATAOUT/datanode.syslog > $DATAOUT/DATAN.out
gawk '{$1="NAMEN    ";print $0}' $DATAOUT/namenode.syslog > $DATAOUT/NAMEN.out
gawk '{$1="NODEM    ";print $0}' $DATAOUT/nodemanager.syslog > $DATAOUT/NODEM.out

echo "Combine all logs from diffrent service to one Job Logs File"
sort -k 2,2 $DATAOUT/AM.out  $DATAOUT/MAP.out  $DATAOUT/REDUCE.out  $DATAOUT/YARN.out $DATAOUT/DATAN.out $DATAOUT/NAMEN.out $DATAOUT/NODEM.out > $DATAOUT/jobsorted
cp $DATAOUT/jobsorted $DATAOUT/JobAllLogs.txt
if [ "$PACKAGE_COLLECT" = "TRUE" ] ; then sort -k 2,2 $DATAOUT/PCAP.out > $DATAOUT/pcapsorted; fi
echo "Genereate .delays file for drawing Job Visual Map" 
# generate timing of MR jobs for gnuplot: Jobsumm obtained from syslogs under hadoop/logs for job
export T00=$(echo $starttime | sed 's/,/./' | gawk -F: -vOFMT=%.6f '{ print ($2 * 60) + $3 }')
echo $T00
# We should convert starttime and logs time to second, then shift the log time to the beginning of the figure.

sed 's/,/./' $DATAOUT/jobsorted |  gawk '{print $0, $1}' | gawk -F ":" -vOFMT=%.6f '!(t>0) {t=($2 * 60) + $3} {nt=($2 * 60) + $3-'$T00'; if (nt > 0) print nt ,$0}' > $DATAOUT/jobtmp1.delays
# This line to map the server name to a number to present it on the y-axis of the figure
gawk '{print $1,$(NF-1),$0}' $DATAOUT/jobtmp1.delays > $DATAOUT/jobtmp.delays
rm $DATAOUT/jobtmp1.delays
cat $MAPFILE | while read line; do
neww=${line##* }
oldw=${line%% *}
sed -i "s/$oldw/$neww/" $DATAOUT/jobtmp.delays
done 

if [ "$PACKAGE_COLLECT" = "TRUE" ] ; then
    sed 's/,/./' $DATAOUT/pcapsorted |  gawk '{print $0, $1}' | gawk -F ":" -vOFMT=%.6f '!(t>0) {t=($2 * 60) + $3} {nt=($2 * 60) + $3-'$T00'; if (nt > 0) print nt ,$0}' > $DATAOUT/pcaptmp1.delays
    # This line to map the server name to a number to present it on the y-axis of the figure
    gawk '{print $1,$(NF-1),$0}' $DATAOUT/pcaptmp1.delays > $DATAOUT/pcaptmp.delays
    rm $DATAOUT/pcaptmp1.delays
    cat $MAPFILE | while read line; do
    neww=${line##* }
    oldw=${line%% *}
    sed -i "s/$oldw/$neww.1/" $DATAOUT/pcaptmp.delays
    done
fi
  
grep "YARN$" $DATAOUT/jobtmp.delays > $DATAOUT/yarn.delays
grep "AM$" $DATAOUT/jobtmp.delays > $DATAOUT/am.delays
grep "MAP$" $DATAOUT/jobtmp.delays > $DATAOUT/map.delays
grep "REDUCE$" $DATAOUT/jobtmp.delays > $DATAOUT/reduce.delays
grep "DATAN$" $DATAOUT/jobtmp.delays > $DATAOUT/datanode.delays
grep "NAMEN$" $DATAOUT/jobtmp.delays > $DATAOUT/namenode.delays
grep "NODEM$" $DATAOUT/jobtmp.delays > $DATAOUT/nodemanager.delays
if [ "$PACKAGE_COLLECT" = "TRUE" ] ; then  
    grep "PCAP$" $DATAOUT/pcaptmp.delays | grep -v "length 0" > $DATAOUT/pcap.delays # remove packet of length 0
    rm $DATAOUT/pcaptmp.delays
fi
rm $DATAOUT/jobtmp.delays
mv $DATAOUT $DATAOUT/../${applicationid} #rename tmp dir to application_id
echo "Done!"
