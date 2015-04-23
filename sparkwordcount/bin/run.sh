#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

echo "========== running spark wordcount bench =========="
# configure
DIR=`cd $bin/../; pwd`
. "${DIR}/../bin/hibench-config.sh"
. "${DIR}/conf/configure.sh"

SUBDIR=$1
if [ -n "$SUBDIR" ]; then
  OUTPUT_HDFS=$OUTPUT_HDFS"/"$SUBDIR
  TMPLOGFILE=$TMPLOGFILE$SUBDIR
fi
JAR_PATH="${DIR}/../common/hibench/sparkwordcount/target/sparkwordcount-0.0.1-SNAPSHOT.jar"
check_compress

# path check
$HADOOP_EXECUTABLE $RMDIR_CMD $OUTPUT_HDFS

START_TIME=`timestamp`

# run bench
$SPARK_SUBMIT_EXECUTABLE --class com.orange.sparkwordcount.SparkWordCount \
  --num-executors ${NUM_EXECUTORS} \
  ${JAR_PATH} $INPUT_HDFS $OUTPUT_HDFS \
  2>&1 | tee ${DIR}/$TMPLOGFILE
#TODO: Integrate compress option

# post-running
END_TIME=`timestamp`
echo Get processed size
if [ "x"$HADOOP_VERSION == "xhadoop1" ]; then
  SIZE=$($HADOOP_EXECUTABLE job -history $INPUT_HDFS | grep 'org.apache.hadoop.examples.RandomTextWriter$Counters.*|BYTES_WRITTEN')
  SIZE=${SIZE##*|}
  SIZE=${SIZE//,/}
else
  SIZE=`grep "Bytes Read" ${DIR}/$TMPLOGFILE | sed 's/Bytes Read=//'`
fi
echo Remove log files
rm -rf ${DIR}/$TMPLOGFILE
 
if [ ! $SIZE ]; then 
  SIZE="0"
  echo "Cannot get Bytes Read!"
fi
echo Generate report
gen_report "SPARKWORDCOUNT" ${START_TIME} ${END_TIME} ${SIZE}
