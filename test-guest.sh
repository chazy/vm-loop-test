#!/bin/bash

guest_num=${GUEST:=0}
fs=${FS:=debian-sid.qcow2}
imgdir=${IMGDIR:=/tmp}

conport=$((5000 + (guest_num * 2) ))
altconport=$((conport + 1))

function error_handler() {
	echo "$1" >&2
	if [[ ! -z "$qemu_pid" ]]; then
		kill $qemu_pid
	fi
}

############################# Trap handler ############################
trap ctrl_c INT TERM
RUN=true

function ctrl_c() {
	error_handler "$guest_num: Received fatal signal, killing VM "
	exit 1
}
#######################################################################

setsid ./run-guest.sh \
	--fs "$fs" \
	--console-log $imgdir/guest${guest_num}.log \
	--console $conport \
	--alt-console $altconport \
	$@ > $imgdir/qemu${guest_num}.log &
qemu_pid=$!

tries=10
while ! nc -z localhost $conport; do
	sleep 0.5
	tries=$((tries - 1))
	if [[ $tries == 0 ]]; then
		error_handler "$guest_num: Could not connect to console on port $conport"
		exit 1
	fi
done

# $1: expect script
# $2: telnet port for console
# #3: logfile path
function interact_with_guest() {
	expect $1 $guest_num $2 > $3 &
	exp_pid=$!

	# Wait for completion, ignore trap handler runs
	wait $exp_pid
	if [[ $? -gt 128 ]]; then
		wait $exp_pid
	fi

	if [ $? -ne 0 ]; then
		exit $?
	fi
}

interact_with_guest linux-boots.exp $conport $imgdir/guest${guest_num}.log
interact_with_guest run-tests.exp $altconport $imgdir/test${guest_num}.log

wait $qemu_pid
exit $?
