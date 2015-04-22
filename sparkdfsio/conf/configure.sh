#!/bin/bash
# Set environment variable for spark shell
export YARN_CONF_DIR="$HADOOP_CONF_DIR"
export SPARK_YARN_MODE=true
export SPARK_WORKER_MEMORY=512m
export SPARK_MASTER_MEMORY=512m
export MASTER=yarn-client ## Set the mode
export LOCAL_DIRS=/tmp

