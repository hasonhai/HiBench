#!/bin/bash
# Set environment variable for spark shell
export YARN_CONF_DIR="$HADOOP_CONF_DIR"
export SPARK_YARN_MODE=true
export SPARK_WORKER_MEMORY=1G
export SPARK_MASTER_MEMORY=1G
export NUM_EXECUTORS=15 #TODO: should get from YARN config
export MASTER=yarn-cluster ## Set the mode
export LOCAL_DIRS=/tmp

# compress
# for best performance set COMPRESS=1 for MR1 and COMPRESS=0 for MR2 (for WordCount)
COMPRESS=$COMPRESS_GLOBAL
COMPRESS_CODEC=$COMPRESS_CODEC_GLOBAL

# paths
INPUT_HDFS=${DATA_HDFS}/SparkWordcount/Input
OUTPUT_HDFS=${DATA_HDFS}/SparkWordcount/Output

if [ $COMPRESS -eq 1 ]; then
    INPUT_HDFS=${INPUT_HDFS}-comp
    OUTPUT_HDFS=${OUTPUT_HDFS}-comp
fi

# for preparation (per node) - 32G
#DATASIZE=32000000000
DATASIZE=3200000000
NUM_MAPS=16

# for control nulber of reducer running (in total) should use 'partition' or 'coalesce'
# NUM_REDS=48
