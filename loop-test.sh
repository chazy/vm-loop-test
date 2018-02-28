#!/bin/bash

############################# Init and configuration ##################
RESULT=0
J=1
FS=debian-sid.qcow2

usage() {
	U=""
	if [[ -n "$1" ]]; then
		U="${U}$1\n\n"
	fi
	U="${U}Usage: $0 [options [--]] [arguments]\n\n"
	U="${U}Options:\n"
	U="$U    --fs <image>:          Guest file system (default $FS)\n"
	U="$U    -j <i>:                Run <i> guests in parallel (default: $J)\n"
	U="$U    -h | --help:           Show this output\n"
	U="${U}\n"
	U="${U}Remaining arguments are passed down to the run script.\n"
	U="${U}\n"
	echo -e "$U" >&2
}

while :
do
	case "$1" in
	  --fs)
		FS="$2"
		shift 2
		;;
	  -j)
		if ! [[ "$2" =~ ^[0-9]+$ ]]; then
			usage "Unrecognized number"
			exit 1
		fi
		J=$2
		shift 2
		;;
	  -h | --help)
		usage ""
		exit 1
		;;
	  --) # End of all options
		shift
		break
		;;
	  -*) # Unknown option
		break
		;;
	  *)
		break
		;;
	esac
done
#######################################################################


############################# Trap handler ############################
trap ctrl_c INT
RUN=true

function ctrl_c() {
	if ! $RUN; then
		echo "Pressed ctrl+c twice, killing all guests."
		for i in `seq 0 $((J - 1))`; do
			kill ${pids[$i]}
		done
		exit 1
	fi
	echo "Waiting for guests to exit current round of testing..."
	RUN=false
}
#######################################################################


############################# Main Execution ##########################
EXIT_CODE1=0
EXIT_CODE2=0

mkdir -p /tmp/vm-loop-test
IMGDIR=`mktemp -d -p /tmp/vm-loop-test`

#IMGDIR=tmp-$$
#mkdir -p $IMGDIR

for i in `seq 0 $((J - 1))`; do
	imgs[$i]=$IMGDIR/guest$i.qcow2
	logs[$i]=$IMGDIR/guest$i.log
	qemu-img create -b "`pwd`/${FS}" -F qcow2 -f qcow2 ${imgs[$i]}
done

iter=1
while $RUN;
do
	echo "\n === Running $J guest(s): Round: $iter ==="

	for i in `seq 0 $((J - 1))`; do
		GUEST=$i FS="${imgs[$i]}" IMGDIR="$IMGDIR" setsid ./test-guest.sh $@ &
		pids[$i]=$!
	done

	# Since the wait may be interrupted by the signal handler, we need another loop
	i=0
	while [[ $i -lt $J ]]; do
		wait ${pids[$i]}
		EXIT_CODE=$?

		# The signal handler will return from wait and give us an exit code greater
		# than 128 - see the bash manual and search for 'wait builtin'.
		if [[ $EXIT_CODE -gt 128 ]]; then
			continue
		fi

		exit_codes[$i]=$EXIT_CODE
		i=$(($i+1))
	done

	for i in `seq 0 $((J - 1))`; do
		if [[ ${exit_codes[$i]} != 0 ]]; then
			echo "guest$i had non-zero exit-code: ${exit_codes[$i]}, see ${logs[$i]}"
			RESULT=1
			RUN=false
		fi
	done

	iter=$(($iter+1))
	sleep 1
done
#######################################################################

exit $RESULT
