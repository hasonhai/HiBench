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

echo "========== Running dfsioe write on $platform =========="
# configure
DIR=`cd $bin/../; pwd`
. "${DIR}/../bin/hibench-config.sh"
. "${DIR}/conf/configure.sh"

#path check
#$HADOOP_EXECUTABLE dfs -rmr ${OUTPUT_HDFS}
$HADOOP_EXECUTABLE fs -mkdir -p ${INPUT_HDFS}/io_data #fix bug cannot create io_data dir

# pre-running
OPTION="-write -nrFiles ${NUM_OF_FILES} -fileSize ${FILE_SIZE} -bufferSize 4096 -plotInteval 1000 -sampleUnit m -sampleInteval 200 -sumThreshold 0.5 -tputReportTotal"
START_TIME=`timestamp`

#run benchmark
if [ $ENHANCED ]; then
${HADOOP_EXECUTABLE} jar ${DFSIOTOOLS} org.apache.hadoop.fs.dfsioe.TestDFSIOEnh \
    -Dmapreduce.map.java.opts="-Dtest.build.data=${INPUT_HDFS} $MAP_JAVA_OPTS" \
    -Dmapreduce.reduce.java.opts="-Dtest.build.data=${INPUT_HDFS} $RED_JAVA_OPTS" \
    ${OPTION} -resFile ${DIR}/result_write.txt -tputFile ${DIR}/throughput_write.csv
else
${HADOOP_EXECUTABLE} jar ${DFSIOTOOLS} TestDFSIO \
    -Dmapreduce.map.java.opts="-Dtest.build.data=${INPUT_HDFS} $MAP_JAVA_OPTS" \
    -Dmapreduce.reduce.java.opts="-Dtest.build.data=${INPUT_HDFS} $RED_JAVA_OPTS" \
    ${OPTION} -resFile ${DIR}/result_write.txt
fi
# post-running
END_TIME=`timestamp`
SIZE=`dir_size $INPUT_HDFS`
gen_report "DFSIOE-WRITE" ${START_TIME} ${END_TIME} ${SIZE}

