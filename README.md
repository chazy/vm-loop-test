VM Loop Test
============

This is a script to run a number VMs in parallel to perform a basic test of the
KVM/ARM host functionality for AArch64.

Each VM will boot, run hackbench and cyclictest, reboots, runs hackbench and
cyclictest again, and finally shuts down.

This continues in a loop until a failure is detected or the user interrupts the
test with ctrl+C, in which case the script will wait for the VMs to shut down
and exit cleanly.

A number of files are required in this directory to run the test:
* debian-arm64.qcow2: a qcow2 guest file system image used to create shallow
  clones (using the main file system as a backing file for each guest instance).
  This FS must support logging in with root/kvm as the root user/password.
* Image: a guest kernel named 'Image'
* qemu-system-aarch64: A QEMU binary

You can either create these files manually (for example by copying the from
somewhere) or you can run setup-loop-test.sh when you first clone this repo to
have them automatically generated for you (it will attempt to clone and compile
the latest released Linux and QEMU versions and create a Debian sid image).

Usage
-----
Simply run `./loop-test.sh <j>` where `<j>` is the number of parallel guests you
want to run.

Hints
-----
You can enjoy the progress of this test script by following the guest outputs
doing something like this:

```bash
tail -F tmp-$PID/guest0.log
```

Assuming $PID is the PID of the loop-test.sh. script.
