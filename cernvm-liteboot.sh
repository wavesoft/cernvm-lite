#!/bin/bash

# Configuration
BASE_DIR=/mnt/.ro/cvm3

# Require a path to the boot script
[ -z "$1" ] && echo "ERROR: Please specify the boot script to use!" && exit 0

# Read-only mount from $1 to $2
function MACRO_RO {
	ln -s $1 $2
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

# Chroot
chroot ${GUEST_DIR}
