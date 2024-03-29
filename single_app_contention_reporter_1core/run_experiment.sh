#!/bin/bash

# Need Python version with SciKit Learn installed
PYTHON="/home/tank-cys/anaconda3/envs/pythia-py3/bin/python"

#
# INPUT: suite bmark rep cores
# Ex: bash run_experiment.sh spec_fp 603 1 1
#

#
# OUTPUT: time mean_ipc estimated_bubble_mean median_ipc estimated_bubble_median
#

#
# NOTE: The taskset calls must be updated to reflect the appropriate processor topology
#
REPORTER_CORE=1
BUBBLE_CORE=1

function run_parsec() {
	BMARK=$1
	CORES=$2
        # echo "BUBBLE_CORE : ${BUBBLE_CORE}"
        # echo $BUBBLE_CORE
	# cuiys
	# numactl -m 0 taskset -c "${BUBBLE_CORE}" parsecmgmt -a run -p "${BMARK}" -i native -n "${CORES}" > "${EXPERIMENT_LOG}" 
	# source code
	numactl -m 0 taskset -c $BUBBLE_CORE parsecmgmt -a run -i native -n "${CORES}" -p "${BMARK}" > "${EXPERIMENT_LOG}"
}

function run_spec() {
	BMARK=$1
	numactl -m 0 taskset -c $BUBBLE_CORE runcpu --config=/home/Pythia/cpu2017/config/Ran.cfg --action=run --size=ref "${BMARK}" > "${EXPERIMENT_LOG}"
}

if [ $# -ne 4 ]; then
	echo "Error: Invalid number of arguments"
	echo "run_experiment.sh suite bmark rep cores"
	exit 1
fi

SUITE=$1
shift
BMARK=$1
shift
REP=$1
shift
CORES=$1
shift

# echo "----------------------------Test output-------------------------------"
# echo "print SUITE BMARK REP CORES"
# echo "SUITE: ${SUITE} BMARK:${BMARK} REP:${REP} CORES:${CORES}"


EXPERIMENT_NAME="${SUITE}.${BMARK}.${REP}"
# echo "EXPERIMENT_NAME : ${EXPERIMENT_NAME}"
PID_FILE="logs/${EXPERIMENT_NAME}.pid"
# echo "PID_FILE:${PID_FILE}"
OUTPUT_NAME="data/${EXPERIMENT_NAME}.reporter.perf_counters"
EXPERIMENT_LOG="logs/${EXPERIMENT_NAME}.log"
# echo "----------------------------------------------------------------------"
# Launch the reporter in the background
# Skip the first 15 seconds of performance counter data since that is unpacking inputs, etc
# Intervals of 1 seconds for the outputs
#

../scripts/bin/time 2> "${OUTPUT_NAME}" | 3>>"${OUTPUT_NAME}" numactl -m 0 taskset -c ${REPORTER_CORE} perf stat -I 1000 -D 20000 -e cycles,instructions --append --log-fd=3 -x ' ' ../scripts/bin/reporter 1> "${PID_FILE}" & 
#../scripts/bin/time 2> "${OUTPUT_NAME}" | 3>>"${OUTPUT_NAME}" numactl -m 0 taskset -c ${REPORTER_CORE} perf stat -I 1000 -D 20000 -e cycles,instructions --append --log-fd=3 -x ' ' ../scripts/bin/reporter 1> "${PID_FILE}" 
if [ $? -ne 0 ]; then
    echo "Error: Failed to start perf and reporter"
    exit 1
fi

#
# Cuiys Test
#
# echo "cuiys Test Launch the reporter"

# Run the batch application
if [ "x${SUITE}" == "xparsec" ]; then
    run_parsec "${BMARK}" "${CORES}" &
    if [ $? -ne 0 ]; then
        echo "Error: Failed to run benchmark"
        kill `cat "${PID_FILE}"`
        rm "${PID_FILE}"
        exit 2
	fi

elif [ "x${SUITE}" == "xspec_int" -o "x${SUITE}" == "xspec_fp" ]; then
	run_spec "${BMARK}" &
	if [ $? -ne 0 ]; then
        echo "Error: Failed to run benchmark"
        kill `cat "${PID_FILE}"`
        rm "${PID_FILE}"
        exit 2
	fi
fi
# cuiystest 
# echo "------------------------------------------------------------------------"
# echo "batch end"
# echo "------------------------------------------------------------------------" 
# Wait for 80 seconds
sleep 80

# Terminate the reporter as needed
echo `cat "${PID_FILE}"`
kill `cat "${PID_FILE}"`
rm "${PID_FILE}"
# cys test
# pkill -f "run_base_refspeed"
# pkill -f "cpu2017"
# pkill -f "runcpu"
# pkill -f "parsec-3.0"
sleep 5
rm -rf ~/cpu2017/benchspec/CPU/*/run
rm -rf ~/PARSEC-3.0/parsec-3.0/pkgs/apps/*/run

# Perform processing out the output data
# echo "-------------------cys test--------------------------------------------------------------------------------"
# echo " data/{EXPERIMENT_NAME}.reporter: data/${EXPERIMENT_NAME}.reporter"
# echo "EXPERIMENT_NAME : ${EXPERIMENT_NAME}"
# echo "{OUTPUT_NAME}: ${OUTPUT_NAME}"
# echo "{EXPERIMENT_LOG}: ${EXPERIMENT_LOG}"
# echo "-----------------------------------------------------------------------------------------------------------"
python ../processing/process_perf.py "data/${EXPERIMENT_NAME}.reporter" "${OUTPUT_NAME}" >> "${EXPERIMENT_LOG}"
if [ $? -ne 0 ]; then
	echo "Error: Failed to process timeseries"
	echo "cys test end"
	exit 3
	
fi

# Compute both the mean and median of the timeseries IPC
# values to determine the different values have
MEAN_IPC=`python ../processing/average_timeseries.py "data/${EXPERIMENT_NAME}.reporter.ipc" "mean" 2>> "${EXPERIMENT_LOG}"`
if [ $? -ne 0 ]; then
	echo "Error: Failed to average timeseries 4"
	exit 4
fi

MEDIAN_IPC=`python ../processing/average_timeseries.py "data/${EXPERIMENT_NAME}.reporter.ipc" "median" 2>> "${EXPERIMENT_LOG}"`
if [ $? -ne 0 ]; then
    echo "Error: Failed to average timeseries 5"
    exit 5
fi

P95_IPC=`python ../processing/average_timeseries.py "data/${EXPERIMENT_NAME}.reporter.ipc" "95th" 2>> "${EXPERIMENT_LOG}"`
if [ $? -ne 0 ]; then
    echo "Error: Failed to average timeseries 6"
    exit 6
fi

P99_IPC=`python ../processing/average_timeseries.py "data/${EXPERIMENT_NAME}.reporter.ipc" "99th" 2>> "${EXPERIMENT_LOG}"`
if [ $? -ne 0 ]; then
    echo "Error: Failed to average timeseries 7"
    exit 7
fi

REPORTER_CURVE="./data/reporter_curve.bubble_size.ipc.medians"
BUBBLE_MEAN=`"${PYTHON}" ../processing/estimate_bubble.py ${REPORTER_CURVE} ${MEAN_IPC} 2>> "${EXPERIMENT_LOG}"`
if [ $? -ne 0 ]; then
	echo "Error: Failed to estimate bubble size 8"
	exit 8
fi
BUBBLE_MEDIAN=`"${PYTHON}" ../processing/estimate_bubble.py ${REPORTER_CURVE} ${MEDIAN_IPC} 2>> "${EXPERIMENT_LOG}"`
if [ $? -ne 0 ]; then
	echo "Error: Failed to estimate bubble size 9"
	exit 9
fi
BUBBLE_P95=`"${PYTHON}" ../processing/estimate_bubble.py ${REPORTER_CURVE} ${P95_IPC} 2>> "${EXPERIMENT_LOG}"`
if [ $? -ne 0 ]; then
	echo "Error: Failed to estimate bubble size 10"
	exit 10
fi
BUBBLE_P99=`"${PYTHON}" ../processing/estimate_bubble.py ${REPORTER_CURVE} ${P99_IPC} 2>> "${EXPERIMENT_LOG}"`
if [ $? -ne 0 ]; then
	echo "Error: Failed to estimate bubble size 11"
	exit 11
fi


# Output final result over stdout
echo "0 ${MEAN_IPC} ${BUBBLE_MEAN} ${MEDIAN_IPC} ${BUBBLE_MEDIAN} ${P95_IPC} ${BUBBLE_P95} ${P99_IPC} ${BUBBLE_P99}"

exit 0
