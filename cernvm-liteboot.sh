#!/bin/bash

# Configuration
BASE_DIR=/mnt/.ro/cvm3

# Require a path to the boot script
[ -z "$1" ] && echo "ERROR: Please specify the boot script to use!" && exit 0

# Create a temporary destination directory
GUEST_DIR=$(mktemp -d)

# Read-only mount from $1 in host to $1 in guest
function MACRO_RO {
	ln -s ${BASE_DIR}/$1 ${GUEST_DIR}/$1
}
# Create writable directory in $1
function MACRO_RW {
	mkdir -p ${GUEST_DIR}/$1
}
# Create directoriy in $*
function MACRO_MKDIR {
	mkdir -p ${GUEST_DIR}/$1
}

# Source boot script
. $1

# Prepare filesystem
MACRO_PREPARE_FS ${GUEST_DIR}

# Chroot
chroot ${GUEST_DIR}
