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

echo "========== Running dfsioe write on ${platform}=========="
# configure
DIR=`cd $bin/../; pwd`
. "${DIR}/../bin/hibench-config.sh"
. "${DIR}/conf/configure.sh"

#path check
$HADOOP_EXECUTABLE $RMDIR_CMD ${INPUT_HDFS}

# pre-running

START_TIME=`timestamp`
# run bench
JAR_PATH="${DIR}/../common/hibench/sparkdfsio/target/testdfsio-0.0.1-SNAPSHOT.jar"
# Spark dfsio take file size at 2-bytes unit, need to convert to MegaByte-unit
# let "FILE_SIZE = $FILE_SIZE * 500000" #job cannot run with file size > 100KBs
  $SPARK_SUBMIT_EXECUTABLE --class fr.eurecom.dsg.spark.TestDFSIO \
    --num-executors ${NUM_EXECUTORS} \
    ${JAR_PATH} write ${NUM_OF_FILES} ${FILE_SIZE} $INPUT_HDFS \
    2>&1
# post-running

END_TIME=`timestamp`
SIZE=`dir_size $INPUT_HDFS`
gen_report "DFSIOE-WRITE" ${START_TIME} ${END_TIME} ${SIZE} ${platform}
