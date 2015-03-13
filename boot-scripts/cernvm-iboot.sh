#!/cvmfs/cernvm-prod.cern.ch/cvm3/bin/bash
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

# Script configuration
CVMU_SERVER_URL="http://test4theory.cern.ch/cvmu"

# Usage helper
function usage {
	echo "Usage: cernvm-iboot.sh [<boot tag>]"
}

#
# Setup boot configuration files
#
# Requires: CVMU_SERVER_URL
# Exports: BOOT_FILES, BOOT_CONFIG
#
function setup_boot {
	local BOOT_NAME=$1

	# Make sure we have a cache directory
	local CACHE_BOOT_DIR="${GUEST_CACHE_FILES}/boot"
	[ ! -d ${CACHE_BOOT_DIR} ] && mkdir -p $CACHE_BOOT_DIR

	# If BOOT_NAME is already a file, we are done
	if [ -f ${BOOT_NAME} ]; then
		BOOT_CONFIG=${BOOT_NAME}
		return 0
	fi

	# Check if this boot script is already cached
	BOOT_FILES=${CACHE_BOOT_DIR}/files-${BOOT_NAME}.tbz2
	BOOT_CONFIG=${CACHE_BOOT_DIR}/${BOOT_NAME}.boot
	[ -f ${BOOT_CONFIG} ] && return 0

	# Otherwise download
	echo "CernVM-Lite: Downloading ${BOOT_NAME} CVMU boot specifications"
	curl -s -o "${BOOT_CONFIG}" "${CVMU_SERVER_URL}/boot/${BOOT_NAME}.boot"
	[ $? -ne 0 ] && echo "ERROR: Could not download boot configuration!" && rm ${BOOT_CONFIG} return 1
	curl -s -o "${BOOT_FILES}" "${CVMU_SERVER_URL}/boot/files-${BOOT_NAME}.tbz2"
	[ $? -ne 0 ] && echo "ERROR: Could not download boot files!" && rm ${BOOT_CONFIG} && rm ${BOOT_FILES} && return 1

	# We are good
	return 0
}

################################################

# Validate the boot script
function is_script_invalid {
	[ "$(cat $1 | head -n1 | tr -d '\n')" != "#!/bin/false" ] && return 1
	[ "$(cat $1 | head -n1 | tail -n1 | tr -d '\n')" != "#BOOT_CONFIG=1.0" ] && return 1
	return 0
}

# Read-only mount from $1
function MACRO_RO {
	ln -s "${CVMFS_RO_BASE}/$1" "${GUEST_ROOT}/$1"
}
# Create writable directory in $1
function MACRO_RW {
	mkdir -p ${GUEST_ROOT}/$1 2>/dev/null 1>/dev/null
	[ $? -ne 0 ] && echo "ERROR: Cannot make ${GUEST_ROOT}/$i writable"
}
# Create directoriy in $1
function MACRO_MKDIR {
	mkdir -p ${GUEST_ROOT}/$1 2>/dev/null 1>/dev/null
	[ $? -ne 0 ] && echo "ERROR: Cannot create ${GUEST_ROOT}/$i"
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

# The pre-mounted CVMFS directory to use for read-only mounts
CVMFS_RO_DIR="/cvmfs/cernvm-prod.cern.ch"
CVMFS_RO_BASE="${CVMFS_RO_DIR}/cvm3"

# Prepare iboot specifics
IBOOT_DIR="/iboot"
GUEST_CACHE_RW="${IBOOT_DIR}/rw"
GUEST_CACHE_FILES="${IBOOT_DIR}/cache"
GUEST_ROOT="${IBOOT_DIR}/boot"

# Make sure guest root exists
mkdir -p ${GUEST_ROOT}

# Require a path to the boot script
BOOT_TAG="latest"
[ ! -z "$1" ] && BOOT_TAG="${BOOT_TAG}"
shift

# Boot that particular tag
setup_boot ${BOOT_TAG}

# Validate boot script
is_script_invalid ${BOOT_CONFIG} && echo "ERROR: This is not a valid boot script!" && exit 2

# Source boot script
. ${BOOT_CONFIG}

# Prepare filesystem
echo "CernVM-Lite: Preparing root filesystem"
prepare_root ${GUEST_DIR}
