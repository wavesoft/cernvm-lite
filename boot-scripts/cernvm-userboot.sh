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

# Helper function to set-up CVMFS
function mount_cvmfs {
	local MOUNTPOINT=$1
	local TEMP=$2

	# Setup cache
	local CVMFS_CACHE="${TEMP}/cache"
	mkdir ${CVMFS_CACHE}

	# Setup CVMFS URL
	local CVMFS_SERVER="hepvm.cern.ch"
	local CVMFS_REPOS="cernvm-devel.cern.ch"
	local CVMFS_URL=http://${CVMFS_SERVER}/cvmfs/${CVMFS_REPOS}

	# Setup CVMFS key
	local CVMFS_KEYS="${TEMP}/keys"
	mkdir -p ${CVMFS_KEYS}
	cat <<EOF > ${CVMFS_KEYS}/${CVMFS_REPOS}.pub
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2sb8SnVVIBeYk7f2bhmn
uoiZ7WjgKZ90DEV5OJbqrVUsn6S+JJRE+5u8OcLY0wrcpdpNrk9YssSeTf305nO7
IhKRwToic3n/ItEow1Inc6Pdn8hQIeQHbz8r7GeCwvKnSGoJf/U4/JhtdnxLzYxe
7xvUL8tmpUC9B4qe34hXaFlUbzqduev2hndFnKx2cMyWJnEVUkS75OAyM6AsDTrx
HWzkfX7NacqFN6wgwtY+Ga9NV0xAOjzDwmclC2uxD/bfga8j6d0cQOsZr0L1tEHQ
qSw5zaeQijOx8YaZC7yeP7rKcFLy1PI++JlWTbnCt6qkfmKLjSBl0wjrqLHgogQn
RwIDAQAB
-----END PUBLIC KEY-----
EOF

	# Setup configuration
	local CMVFS_CONFIG=${TEMP}/${CVMFS_REPOS}.conf
	cat <<EOF > ${CMVFS_CONFIG}
CVMFS_CACHE_BASE=${CVMFS_CACHE}
CVMFS_NFILES=65536
CVMFS_RELOAD_SOCKETS=${CVMFS_CACHE}
CVMFS_SERVER_URL=${CVMFS_URL}
CVMFS_HTTP_PROXY="auto;DIRECT"
CVMFS_KEYS_DIR=${CVMFS_KEYS}
CVMFS_CHECK_PERMISSIONS=yes
CVMFS_IGNORE_SIGNATURE=no
CVMFS_AUTO_UPDATE=no
CVMFS_NFS_SOURCE=no
CVMFS_PROXY_RESET_AFTER=1800
CVMFS_MAX_RETRIES=2
CVMFS_TIMEOUT=10
CVMFS_TIMEOUT_DIRECT=10
CVMFS_BACKOFF_INIT=2
CVMFS_BACKOFF_MAX=12
CVMFS_USYSLOG=${CVMFS_CACHE}/usyslog
EOF
	
	# Mount the CVMFS repository
	cvmfs2 -o allow_other,config=${CMVFS_CONFIG} ${CVMFS_REPOS} ${MOUNTPOINT}
}

# Read-only mount from $1 to $2
function MACRO_RO {
	BIND_ARGS="${BIND_ARGS} -b ${BASE_DIR}/$1:/$1"
	mkdir -p ${GUEST_DIR}/$1
}
# Create writable directory in $1
function MACRO_RW {
	mkdir -p ${GUEST_DIR}/$1
}
# Create directoriy in $*
function MACRO_MKDIR {
	mkdir -p ${GUEST_DIR}/$1
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
	tar -C ${GUEST_DIR} -jxf ${ARCHIVE_FILE}

}
################################################

# Reset Properties
BASE_DIR=""
GUEST_DIR=""

# Parameters to be populated by the macros
BIND_ARGS=""

# Require a path to the boot script
[ -z "$1" ] && echo "ERROR: Please specify the boot script to use!" && exit 0
BOOT_SCRIPT=$1
shift

# Check if we have proot utility, otherwise download it
PROOT_BIN=$(which proot 2>/dev/null)
if [ -z "${PROOT_BIN}" ]; then
	PROOT_BIN="./proot"
	if [ ! -f "${PROOT_BIN}" ]; then
		echo -n "CernVM-Lite: Downloading proot utility..."
		wget -q -O ${PROOT_BIN} http://static.proot.me/proot-x86_64
		[ $? -ne 0 ] && echo "error" && rm ${PROOT_BIN} && exit 1
		chmod +x ${PROOT_BIN}
		echo "ok"
	fi
fi

# Create a temporary destination directory
TEMP_DIR=$(mktemp -d)
GUEST_DIR="${TEMP_DIR}/root"
CVMFS_RO_DIR="${TEMP_DIR}/ro"
BASE_DIR="${CVMFS_RO_DIR}/cvm3"

# Make directories
mkdir ${TEMP_DIR}/{root,ro,cvmfs}

# Mount CVMFS repository in $BASE_DIR,
# using the ${TEMP_DIR}/cvmfs as cache
mount_cvmfs ${CVMFS_RO_DIR} "${TEMP_DIR}/cvmfs"

# Get the latest update pack version
CVMFS_VERSION=$(cat ${CVMFS_RO_DIR}/update-packs/cvm3/latest | grep version | awk -F'=' '{print $2}')

# Source boot script
. ${BOOT_SCRIPT}

# Prepare filesystem
echo "CernVM-Lite: Preparing root filesystem"
prepare_root ${GUEST_DIR}

# PRoot
echo "CernVM-Lite: Starting CernVM in userland v${CVMFS_VERSION}"
${PROOT_BIN} ${BIND_ARGS} -R ${GUEST_DIR} -w / $*

# Remove directory upon exit
echo "CernVM-Lite: Cleaning-up environment"
fusermount -u ${CVMFS_RO_DIR}
rm -rf ${TEMP_DIR}
