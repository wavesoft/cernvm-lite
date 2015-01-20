#!/bin/bash

# Configuration
BASE_DIR=/mnt/.ro/cvm3/

# Require a path to the boot script
[ -z "$1" ] && echo "ERROR: Please specify the boot script to use!" && exit 0

# Check if we have proot utility, otherwise download it
PROOT_BIN=$(which proot)
if [ -z "${PROOT_BIN}" ]; then
	PROOT_BIN="./proot"
	if [ ! -f "${PROOT_BIN}" ]; then
		echo -n "Downloading proot utility..."
		wget -q -O ${PROOT_BIN} http://static.proot.me/proot-x86_64
		[ $? -ne 0 ] && echo "error" && rm ${PROOT_BIN} && exit 1
		echo "ok"
	fi
fi

# Read-only mount from $1 to $2
BIND_ARGS=""
function MACRO_RO {
	BIND_ARGS="${BIND_ARGS} -b $1:$2"
}
# Create writable directory in $1
function MACRO_RW {
	mkdir -p $1
}
# Create directoriy in $*
function MACRO_MKDIR {
	mkdir -p $*
}

# Source boot script
. $1

# Create a temporary destination directory
GUEST_DIR=$(mktemp -d)

# Prepare filesystem
MACRO_PREPARE_FS ${GUEST_DIR} ${BASE_DIR}

# PRoot
${PROOT_BIN} ${BIND_ARGS} -r ${GUEST_DIR}
