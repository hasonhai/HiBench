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

dir=`dirname "$0"`
dir=`cd "$dir"; pwd`

if [ $platform ]; then
  if [ "$platform" = "spark" ]; then
    source ${dir}/../conf/spark-configure.sh
    # paths
    INPUT_HDFS=${DATA_HDFS}/benchmarks/TestDFSIO-Spark
  else
    platform="hadoop"
    # paths
    INPUT_HDFS=${DATA_HDFS}/benchmarks/TestDFSIO-Enh
  fi
else
  platform="hadoop"
  # paths
  INPUT_HDFS=${DATA_HDFS}/benchmarks/TestDFSIO-Enh
fi

export HADOOP_OPTS="$HADOOP_OPTS -Dtest.build.data=${INPUT_HDFS}"
MAP_JAVA_OPTS=`cat $HADOOP_CONF_DIR/mapred-site.xml | grep "mapreduce.map.java.opts" | awk -F\< '{print $5}' | awk -F\> '{print $NF}'`
RED_JAVA_OPTS=`cat $HADOOP_CONF_DIR/mapred-site.xml | grep "mapreduce.reduce.java.opts" | awk -F\< '{print $5}' | awk -F\> '{print $NF}'`

# Select the tool
# export DFSIOTOOLS=${dir}/../../common/SPOTools/target/spotools-0.0.1-SNAPSHOT.jar #DFSIO-Enh compile with Hadoop 2.6
# export DFSIOTOOLS=${DATATOOLS} # DFSIO-Enh from HiBench compile with Hadoop 1, got bug
export DFSIOTOOLS=${LEGACY_TESTDFSIO_JAR} #legacy version

# combine variable of read and write to one 
NUM_OF_FILES=64
FILE_SIZE=200 # MBs

if [ "$DFSIOTOOLS" = "${LEGACY_TESTDFSIO_JAR}" ]; then
  INPUT_HDFS=/benchmarks/TestDFSIO # Cannot change directory when using legacy tools
fi
