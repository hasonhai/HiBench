#!/bin/bash
# Set environment variable for spark shell
export YARN_CONF_DIR="$HADOOP_CONF_DIR"
export SPARK_YARN_MODE=true
export SPARK_WORKER_MEMORY=1G
export SPARK_MASTER_MEMORY=1G
export NUM_EXECUTORS=15 #TODO: should get from YARN config
export MASTER=yarn-cluster ## Set the mode
export LOCAL_DIRS=/tmp

