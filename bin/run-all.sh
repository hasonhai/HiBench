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

DIR=`dirname "$0"`
DIR=`cd "${DIR}/.."; pwd`

. $DIR/bin/hibench-config.sh

#if [ -f $HIBENCH_REPORT ]; then
#    rm $HIBENCH_REPORT
#fi

while read benchmark_info; do
    echo "$benchmark_info"
    benchmark=$( echo "$benchmark_info" | cut -d' ' -f1 )
    platform=$( echo "$benchmark_info" | cut -d' ' -f2 )
    if [[ $benchmark == \#* ]]; then
        continue
    fi
    case "$platform" in
      spark)  
        export platform="spark"
        ;;
      *)
        export platform="hadoop"
        ;; # default platform
    esac

    if [ "$benchmark" = "dfsioe" ] ; then
        # dfsioe specific
        $DIR/dfsioe/bin/prepare-read.sh
        if [ "$platform" = "spark"  ]; then
          $DIR/dfsioe/bin/spark-run-read.sh
          $DIR/dfsioe/bin/spark-run-write.sh
        else
          $DIR/dfsioe/bin/run-read.sh
          $DIR/dfsioe/bin/run-write.sh
        fi

    elif [ "$benchmark" = "hivebench" ]; then
        # hivebench specific
        $DIR/hivebench/bin/prepare.sh
        $DIR/hivebench/bin/run-aggregation.sh
        $DIR/hivebench/bin/run-join.sh

    else
        if [ -e $DIR/${benchmark}/bin/prepare.sh ]; then
           $DIR/${benchmark}/bin/prepare.sh
        fi
        $DIR/${benchmark}/bin/run.sh
    fi
done < $DIR/conf/benchmarks.lst

