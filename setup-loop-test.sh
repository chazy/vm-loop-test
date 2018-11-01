#!/bin/bash

PROGNAME=loop-test.sh

function error_exit
{
	#	----------------------------------------------------------------
	#	Function for exit due to fatal program error
	#		Accepts 1 argument:
	#			string containing descriptive error message
	#	----------------------------------------------------------------

	echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
		exit 1
}

# Check we have the tools we need
declare -a tools=("expect")
for tool in "${tools[@]}"
do
	if ! tool_loc="$(type -p "$tool")" || [ -z "$tool_loc" ]; then
		  error_exit "$tool is required, please install, aborting"
	fi
done

# Let's make sure we have a guest file system
if [[ ! -e debian-arm64.qcow2 ]]; then
	./create-guest-image.sh debian-arm64 || exit $?
fi

# Let's make sure we have a guest kernel
if [[ ! -e Image ]]; then
	read -p "No guest kernel Image detected. I can build one for you. Proceed? [Y/n]" -n 1 -r
	if [[ -z "$REPLY" || "$REPLY" == "Y" || "$REPLY" == "y" ]]; then
		echo ""
		./create-guest-kernel.sh || exit $?
	else
		echo ""
		error_exit "No guest kernel, please put one here and name it Image"
	fi
fi

# Let's make sure we have a QEMU version for you
if [[ ! -e qemu-system-aarch64 ]]; then
	read -p "No qemu binary detected. I can build one for you. Proceed? [Y/n]" -n 1 -r
	if [[ -z "$REPLY" || "$REPLY" == "Y" || "$REPLY" == "y" ]]; then
		echo ""
		./build-qemu.sh || exit $?
	else
		echo ""
		error_exit "No qemu binary, please put one here and name it qemu-system-aarch64"
	fi
fi

echo "Loop test ready"
