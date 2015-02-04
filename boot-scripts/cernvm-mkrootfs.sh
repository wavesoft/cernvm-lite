#!/bin/bash
#
# CernVM Lite Boot Script 
# Copyright (C) 2014-2015  Ioannis Charalampidis, PH-SFT, CERN

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

# Usage helper
function usage {
	echo "Usage: cernvm-mkrootfs.sh <cvmfs base> <root> <boot script>"
}

# Validate the boot script
function is_script_invalid {
	[ "$(cat $1 | head -n1 | tr -d '\n')" != "#!/bin/false" ] && return 1
	[ "$(cat $1 | head -n1 | tail -n1 | tr -d '\n')" != "#BOOT_CONFIG=1.0" ] && return 1
	return 0
}

# Read-only mount from $1 in host to $1 in guest
function MACRO_RO {

	# Pre-expand read-only mounts are used only
	# by userboot.sh
	[ "$CHAIN" == "pre" ] && return

	# Bind-mount overlaying the basic CVMFS mount
	mount --bind ${BASE_DIR}/$1 ${GUEST_DIR}/$1

}
# Create writable directory in $1
function MACRO_RW {

	# Create a new temporary directory
	local DIR_NAME=$(basename $1)
	local TMPDIR=$(mktemp -d /tmp/rw-${DIR_NAME}.XXXXXXXXXX)

	# Bind-mount to that
	mount --bind ${TMPDIR} ${GUEST_DIR}/$1

}
# Create directoriy in $*
function MACRO_MKDIR {
	mkdir -p ${GUEST_DIR}/$1
}
# Import files from the current OS
function MACRO_IMPORT {
	# Not used for mkrootfs
	return
}
# Expand archive with the tag id in $1
function MACRO_EXPAND {

	# The archive file should be in cvmfs
	ARCHIVE_FILE="${CVMFS_RO_DIR}/lite/files-$1.tbz2"

	# Override with files archive that exist in the
	# same directory as the boot script
	BOOT_SCRIPT_DIR=$(dirname ${BOOT_SCRIPT})
	if [ -f "${BOOT_SCRIPT_DIR}/files-$1.tbz2" ]; then
		ARCHIVE_FILE="${BOOT_SCRIPT_DIR}/files-$1.tbz2"
	fi

	# Expand the files archive
	tar -C ${BASE_DIR} -jxf ${ARCHIVE_FILE}

}
################################################

# Require a path to the boot script
[ -z "$1" ] && echo "ERROR: Please specify the path to the mounted CernVM CVMFS repository!" && usage && exit 1
[ -z "$2" ] && echo "ERROR: Please specify the path to the root directory!" && usage && exit 1
[ -z "$3" ] && echo "ERROR: Please specify the path to the boot script!" && usage && exit 1
CVMFS_RO_DIR=$1; shift
GUEST_DIR=$1; shift
BOOT_SCRIPT=$1; shift

# Validate boot script
is_script_invalid ${BOOT_SCRIPT} && echo "ERROR: This is not a valid boot script!" && exit 2

# Base directory is the /cvm3 inside cvmfs
BASE_DIR="${CVMFS_RO_DIR}/cvm3"

# Make sure guest directory exists
[ ! -d $GUEST_DIR ] && mkdir $GUEST_DIR

# Bind-mount the base read-only filesystem
mount --bind ${BASE_DIR} ${GUEST_DIR}

# Source boot script
. ${BOOT_SCRIPT}

# Prepare filesystem
prepare_root ${GUEST_DIR}

