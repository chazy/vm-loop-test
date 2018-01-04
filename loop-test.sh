#!/bin/bash

############################# Init and configuration ##################
RESULT=0
J=1
KERNEL=Image
FS=debian-sid.qcow2
CMDLINE=""

usage() {
	U=""
	if [[ -n "$1" ]]; then
		U="${U}$1\n\n"
	fi
	U="${U}Usage: $0 [options]\n\n"
	U="${U}Options:\n"
	U="$U    -c | --CPU <nr>:       Number of cores (default ${SMP})\n"
	U="$U    -m | --mem <MB>:       Memory size (default ${MEMSIZE})\n"
	U="$U    --kernel <Image>:      Guest kernel image (default ${KERNEL})\n"
	U="$U    --fs <image>:          Guest file system (default $FS)\n"
	U="$U    -a | --append <snip>:  Add <snip> to the kernel cmdline\n"
	U="$U    -j <i>:                Run <i> guests in parallel (default: $J)\n"
	U="$U    -h | --help:           Show this output\n"
	U="${U}\n"
	echo -e "$U" >&2
}

while :
do
	case "$1" in
	  -c | --cpu)
		SMP="$2"
		shift 2
		;;
	  -m | --mem)
		MEMSIZE="$2"
		shift 2
		;;
	  --kernel)
		KERNEL="$2"
		shift 2
		;;
	  --fs)
		FS="$2"
		shift 2
		;;
	  -a | --append)
		CMDLINE="$2"
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
		echo "Error: Unknown option: $1" >&2
		exit 1
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
	echo "Waiting for guests to exit current round of testing..."
        RUN=false
}
#######################################################################


############################# Main Execution ##########################
EXIT_CODE1=0
EXIT_CODE2=0

IMGDIR=tmp-$$
mkdir -p $IMGDIR

for i in `seq 0 $((J - 1))`; do
	imgs[$i]=$IMGDIR/guest$i.qcow2
	logs[$i]=$IMGDIR/guest$i.log
	qemu-img create -b ../debian-sid.qcow2 -F qcow2 -f qcow2 ${imgs[$i]}
done

iter=1
while $RUN;
do
	echo "Running $J guest(s): Round: $iter"

	for i in `seq 0 $((J - 1))`; do
		setsid expect hackbench-shutdown.exp --fs ${imgs[$i]} --alt-console $((5000 + i)) $@ > ${logs[$i]} &
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