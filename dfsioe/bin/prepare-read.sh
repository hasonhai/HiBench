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

echo "========== preparing dfsioe data =========="
# configure
DIR=`cd $bin/../; pwd`
. "${DIR}/../bin/hibench-config.sh"
. "${DIR}/conf/configure.sh"

# path check
$HADOOP_EXECUTABLE $RMDIR_CMD ${INPUT_HDFS}

# generate data
if [ "$platform" = "spark" ]; then
  JAR_PATH="${DIR}/../common/hibench/sparkdfsio/target/testdfsio-0.0.1-SNAPSHOT.jar"
  # Spark dfsio take file size at 2-bytes unit, need to convert to MegaByte-unit
  # let "FILE_SIZE =  $FILE_SIZE * 500000" #currently the job only work with 256 file less than 100Kb
  $SPARK_SUBMIT_EXECUTABLE --class fr.eurecom.dsg.spark.TestDFSIO \
    --num-executors ${NUM_EXECUTORS} \
    ${JAR_PATH} write ${NUM_OF_FILES} ${FILE_SIZE} $INPUT_HDFS \
    2>&1
else # run on hadoop platform
  # Enhanced version (don't know what did they enhanced)
  if [ $ENHANCED ]; then
  ${HADOOP_EXECUTABLE} jar ${DFSIOTOOLS} org.apache.hadoop.fs.dfsioe.TestDFSIOEnh \
    -Dmapreduce.map.java.opts="-Dtest.build.data=${INPUT_HDFS} $MAP_JAVA_OPTS" \
    -Dmapreduce.reduce.java.opts="-Dtest.build.data=${INPUT_HDFS} $RED_JAVA_OPTS" \
    -write -skipAnalyze -nrFiles ${NUM_OF_FILES} -fileSize ${FILE_SIZE} -bufferSize 4096
  else
  ${HADOOP_EXECUTABLE} jar ${DFSIOTOOLS} TestDFSIO \
    -Dmapreduce.map.java.opts="-Dtest.build.data=${INPUT_HDFS} $MAP_JAVA_OPTS" \
    -Dmapreduce.reduce.java.opts="-Dtest.build.data=${INPUT_HDFS} $RED_JAVA_OPTS" \
    -write -nrFiles ${NUM_OF_FILES} -fileSize ${FILE_SIZE} -bufferSize 4096
  fi
fi
