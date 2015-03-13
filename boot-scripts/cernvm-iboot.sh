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
	echo "Usage: cernvm-iboot.sh <boot script>"
}

# Validate the boot script
function is_script_invalid {
	[ "$(cat $1 | head -n1 | tr -d '\n')" != "#!/bin/false" ] && return 1
	[ "$(cat $1 | head -n1 | tail -n1 | tr -d '\n')" != "#BOOT_CONFIG=1.0" ] && return 1
	return 0
}

# Read-only mount from $1
function MACRO_RO {
	ln -s "${GUEST_CVMFS_BASE}/$1" "${GUEST_ROOT}/$1"
}
# Create writable directory in $1
function MACRO_RW {
	TMP_DIR="${GUEST_CACHE}/$i"
	mkdir -p ${TMP_DIR}
	ln -s "${TMP_DIR}" "${GUEST_ROOT}/$1"
}
# Create directoriy in $1
function MACRO_MKDIR {
	mkdir -p ${GUEST_ROOT}/$1
}
# Import files from the current OS
function MACRO_IMPORT {
	return
}
# Expand archive with the tag id in $1
function MACRO_EXPAND {

	# The archive file should be in cvmfs
	ARCHIVE_FILE="${CVMFS_RO_DIR}/lite/files-$1.tbz2"

	# Override with files archive that exist in the
	# same directory as the boot script
	BOOT_CONFIG_DIR=$(dirname ${BOOT_CONFIG})
	if [ -f "${BOOT_CONFIG_DIR}/files-$1.tbz2" ]; then
		ARCHIVE_FILE="${BOOT_CONFIG_DIR}/files-$1.tbz2"
	fi

	# Expand the files archive
	tar -C ${GUEST_ROOT} -jxf ${ARCHIVE_FILE}

}

################################################

# 
CVMFS_RO_DIR="/iboot/cvmfs/cernvm-devel.cern.ch"
GUEST_CVMFS_BASE="${CVMFS_RO_DIR}/cvm3"
GUEST_CACHE="/iboot/cache"
GUEST_ROOT=""

# Require a path to the boot script
[ -z "$1" ] && echo "ERROR: Please specify the boot script to use!" && usage && exit 1
BOOT_SCRIPT=$1
shift

# Validate boot script
is_script_invalid ${BOOT_SCRIPT} && echo "ERROR: This is not a valid boot script!" && exit 2

# Source boot script
. ${BOOT_SCRIPT}

