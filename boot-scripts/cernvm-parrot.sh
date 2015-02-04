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
	echo "Usage: cernvm-parrot.sh <boot script>"
}

# Validate the boot script
function is_script_invalid {
	[ "$(cat $1 | head -n1 | tr -d '\n')" != "#!/bin/false" ] && return 1
	[ "$(cat $1 | head -n1 | tail -n1 | tr -d '\n')" != "#BOOT_CONFIG=1.0" ] && return 1
	return 0
}

# Setup CVMFS configuration
function setup_cvmfs {
	local CONFIG_DIR=$1

	# Setup cache (expose CVMFS_CACHE)
	CVMFS_CACHE="${CONFIG_DIR}/cache"
	mkdir -p ${CVMFS_CACHE}

	# Setup default CVMFS proxy
	if [ -z "${CVMFS_HTTP_PROXY}" ]; then
		CVMFS_PROXY="auto;DIRECT"
	else
		CVMFS_PROXY="${CVMFS_HTTP_PROXY}"
	fi

	# Setup CVMFS URL (expose CVMFS_SERVER, CVMFS_REPOS, CVMFS_URL)
	CVMFS_SERVER="hepvm.cern.ch"
	CVMFS_REPOS="cernvm-devel.cern.ch"
	CVMFS_URL=http://${CVMFS_SERVER}/cvmfs/${CVMFS_REPOS}

	# Setup CVMFS key (expose CMVFS_CONFIG)
	CVMFS_KEYS="${CONFIG_DIR}/keys"
	CVMFS_PUB_KEY="${CVMFS_KEYS}/${CVMFS_REPOS}.pub"
	mkdir -p ${CVMFS_KEYS}
	cat <<EOF > ${CVMFS_PUB_KEY}
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

}

# Read-only mount from $1 to $2
function MACRO_RO {
	PARROT_ARGS="${PARROT_ARGS} -M '/$1=${BASE_DIR}/$1'"
}
# Create writable directory in $1
function MACRO_RW {
	PARROT_ARGS="${PARROT_ARGS} -M '/$1=${GUESTRW_DIR}/$1'"
	mkdir -p ${GUESTRW_DIR}/$1
}
# Create directoriy in $*
function MACRO_MKDIR {
	mkdir -p ${GUESTRW_DIR}/$1
}
# Import files from the current OS
function MACRO_IMPORT {
	cp /$1 ${GUESTRW_DIR}/$1
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
	tar -C ${GUESTRW_DIR} -jxf ${ARCHIVE_FILE}

}
################################################

# Base directory (inside parrot environment)
BASE_DIR="/cvmfs/cernvm-devel.cern.ch/cvm3"

# Require a path to the boot script
[ -z "$1" ] && echo "ERROR: Please specify the boot script to use!" && usage && exit 1
BOOT_SCRIPT=$1
shift

# Validate boot script
is_script_invalid ${BOOT_SCRIPT} && echo "ERROR: This is not a valid boot script!" && exit 2

# Check if we have proot utility, otherwise download it
PARROT_BIN=$(which parrot_run 2>/dev/null)
if [ -z "${PARROT_BIN}" ]; then
	# We need to simplify this...
	PARROT_BIN="./cctools-4.3.2-x86_64-redhat6/bin/parrot_run"
	if [ ! -f "${PARROT_BIN}" ]; then
		echo -n "CernVM-Lite: Downloading CCTools..."
		wget -q http://ccl.cse.nd.edu/software/files/cctools-4.3.2-x86_64-redhat6.tar.gz
		[ $? -ne 0 ] && echo "error" && rm cctools-4.3.2-x86_64-redhat6.tar.gz && exit 1
		tar -zxf cctools-4.3.2-x86_64-redhat6.tar.gz
		[ $? -ne 0 ] && echo "error" && rm cctools-4.3.2-x86_64-redhat6.tar.gz && exit 1
		echo "ok"
	fi
fi

# Create a temporary working directory
TEMP_DIR=$(mktemp -d)
GUESTRW_DIR="${TEMP_DIR}/root" && mkdir ${GUESTRW_DIR}
CVMFS_DIR="${TEMP_DIR}/cvmfs" && mkdir ${CVMFS_DIR}
PARROT_DIR="${TEMP_DIR}/parrot" && mkdir ${PARROT_DIR}

# Setup basic parrot args
PARROT_ARGS="${PARROT_ARGS} -f -t '${PARROT_DIR}'"

# Setup CVMFS 
setup_cvmfs ${CVMFS_DIR}
PARROT_ARGS="${PARROT_ARGS} --cvmfs-repos='${CVMFS_REPOS}:url=${CVMFS_URL},proxies=${CVMFS_PROXY},pubkey=${CVMFS_PUB_KEY},cachedir=${CVMFS_CACHE},mountpoint=/cvmfs/${CVMFS_REPOS}'"

# Source boot script
. ${BOOT_SCRIPT}

# Prepare filesystem
echo "CernVM-Lite: Preparing root filesystem"
prepare_root ${GUESTRW_DIR}

# Create a home directory for the user
USERNAME=$(whoami)
mkdir -p ${GUESTRW_DIR}/home/${USERNAME}

# Create bootstrap script
BOOTSTRAP_BIN=${GUESTRW_DIR}/home/${USERNAME}/.bootstrap
cat <<EOF > ${BOOTSTRAP_BIN}
#!/bin/bash

# Display banner
CVMFS_VERSION=\$(cat /cvmfs/cernvm-devel.cern.ch/update-packs/cvm3/latest | grep version | awk -F'=' '{print \$2}')
echo "CernVM-Lite: Welcome to CernVM v\${CVMFS_VERSION}"

# Prepare environment
export HOME=/home/${USERNAME}
export TMPDIR=/tmp

/bin/bash
EOF
chmod +x ${BOOTSTRAP_BIN}

# PRoot
echo "CernVM-Lite: Starting CernVM in userland"
eval "${PARROT_BIN} ${PARROT_ARGS} -w /home/${USERNAME} $* /home/${USERNAME}/.bootstrap"

# Remove directory upon exit
echo "CernVM-Lite: Cleaning-up environment"
rm -rf ${TEMP_DIR}
