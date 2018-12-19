#!/usr/bin/env bash

# Copyright (c) 2018, University of Kaiserslautern
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER
# OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Author: Éder F. Zulian

DIR="$(cd "$(dirname "$0")" && pwd)"
TOPDIR=$DIR/../..
source $TOPDIR/common/defaults.in
source $TOPDIR/common/util.in
currtime=$(date "+%Y.%m.%d-%H.%M.%S")

arch="ARM"
mode="opt"
gem5_elf="build/$arch/gem5.$mode"

cd $ROOTDIR/gem5
if [[ ! -e $gem5_elf ]]; then
	build_gem5 $arch $mode
fi

sysver=20180409
imgdir="$FSDIRARM/aarch-system-${sysver}/disks"
img="$imgdir/aarch64-ubuntu-trusty-headless.img"


target="boot_ubuntu"
ncores="2"
script="fs.py"
#script="starter_fs.py"
#tlm_options="--tlm-memory=transactor"

if [ "${script}" == "starter_fs.py" ]; then
	cpu_freq="4GHz"
	mem_size="4GB"
	config_script="configs/example/arm/${script}"
	cpu_options="--cpu=hpi --num-cores=${ncores} --cpu-freq=${cpu_freq}"
	mem_options="--mem-size=${mem_size}"
	disk_options="--disk-image=$img"
	kernel="--kernel=$FSDIRARM/aarch-system-${sysver}/binaries/vmlinux.vexpress_gem5_v1_64"
	dtb="--dtb=$FSDIRARM/aarch-system-${sysver}/binaries/armv8_gem5_v1_${ncores}cpu.dtb"
elif [ "${script}" == "fs.py" ]; then
	mem_size="4GB"
	config_script="configs/example/${script}"
	cpu_options="--cpu-type=TimingSimpleCPU --num-cpu=${ncores}"
	#cpu_options="--cpu-type=HPI --num-cpu=${ncores}"
	other_options="--machine-type=VExpress_GEM5_V1"
	mem_options="--mem-size=${mem_size} --mem-type=DDR3_1600_8x8 --mem-channels=1 --caches --l2cache"
	disk_options="--disk=$img"
	dtb="--dtb-filename=$FSDIRARM/aarch-system-${sysver}/binaries/armv8_gem5_v1_${ncores}cpu.dtb"
	kernel="--kernel=$FSDIRARM/aarch-system-${sysver}/binaries/vmlinux.vexpress_gem5_v1"
	#kernel_cmdline="earlyprintk=pl011,0x1c090000 console=ttyAMA0 lpj=19988480 norandmaps rw loglevel=8 mem=${mem_size} root=/dev/vda1"
	#kernel_cmdline_options="--command-line=${kernel_cmdline}"
else
	printf "\nPlease define options for ${script}\n"
	exit
fi

call_m5_exit="no"
sleep_before_exit="0"
checkpoint_before_exit="no"

bootscript="${target}_${ncores}c.rcS"
printf '#!/bin/bash\n' > $bootscript
printf "echo \"Executing $bootscript now\"\n" >> $bootscript
printf 'echo "Linux is already running."\n' >> $bootscript
if [ "$call_m5_exit" == "yes" ]; then
	if [ "$checkpoint_before_exit" == "yes" ]; then
		printf 'echo "Creating a checkpoint"\n' >> $bootscript
		printf 'm5 checkpoint\n' >> $bootscript
	fi
	printf "echo \"Calling m5 in $sleep_before_exit seconds from now...\"\n" >> $bootscript
	printf "sleep ${sleep_before_exit}\n" >> $bootscript
	printf 'm5 exit\n' >> $bootscript
fi

bootscript_options="--script=$ROOTDIR/gem5/$bootscript"
output_dir="${target}_${ncores}c_$currtime"
mkdir -p ${output_dir}
logfile=${output_dir}/gem5.log
export M5_PATH="$FSDIRARM/aarch-system-${sysver}":${M5_PATH}
$gem5_elf -d $output_dir $config_script $cpu_options $mem_options $tlm_options $kernel $kernel_cmdline_options $dtb $disk_options $bootscript_options $other_options 2>&1 | tee $logfile
