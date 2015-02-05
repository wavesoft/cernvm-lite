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

# Script configuration
CVMU_SERVER_URL="http://test4theory.cern.ch/cvmu"

# Usage helper
function usage {
	echo "CernVM in userland v0.1.0 - Ioannis Charalampidis PH/SFT"
	echo "Usage: cvmu [-b <boot script>] [-c <cvmfs-repositroy>] <command> ..."
}

# Validate the boot script
function is_script_invalid {
	[ "$(cat $1 | head -n1 | tr -d '\n')" != '#!/bin/false' ] && return 0
	[ "$(cat $1 | head -n2 | tail -n1 | tr -d '\n')" != "#BOOT_CONFIG=1.0" ] && return 0
	return 1
}

#
# Detect environment and set the appropriate variables
#
# Exports: ENV_ARCH, ENV_DIST
#
function detect_env {
	# Detect architecture
	ENV_ARCH=$(uname -m)

	# Detect distribution
	ENV_DIST=""
	if [ -f /etc/redhat-release ]; then
		local RELEASE=$(cat /etc/redhat-release)
		if [ $(echo "$RELEASE" | grep -c ' 6\.') -ne 0 ]; then
			ENV_DIST="redhat6"
		elif [ $(echo "$RELEASE" | grep -c ' 5\.') -ne 0 ]; then
			ENV_DIST="redhat5"
		fi
	else
		echo "ERROR: Unsupported linux distribution. We currently support RHEL5 and RHEL6 (or simmilar)."
		return 1
	fi
}

#
# Fetch and install the appropriate parrot version
#
# Requires: ENV_ARCH, ENV_DIST, CVMU_SERVER_URL
# Exports: PARROT_BIN
#
function setup_parrot {

	# Check if we have parrot in environment
	local X_PARROT_BIN=$(which parrot_run 2>/dev/null)
	if [ ! -z "$X_PARROT_BIN" ]; then
		PARROT_BIN=${X_PARROT_BIN}
		return 0
	fi

	# Make sure we have a cache directory
	local CACHE_DIR="${HOME}/.cvmu/bin"
	[ ! -d ${CACHE_DIR} ] && mkdir $CACHE_DIR

	# Check if parrot is cached
	X_PARROT_BIN=${CACHE_DIR}/parrot_run
	if [ -f ${X_PARROT_BIN} ]; then
		PARROT_BIN=${X_PARROT_BIN}
		return 0
	fi

	# Build the URL to use for fetching parrot
	local PARROT_URL="${CVMU_SERVER_URL}/bin/parrot_run-${ENV_ARCH}-${ENV_DIST}.gz"

	# Try to download to cache
	echo "INFO: Downloading required software"
	curl -s -o "${X_PARROT_BIN}.gz" "${PARROT_URL}"
	if [ $? -ne 0 ]; then
		echo "ERROR: Could not download parrot_run binary!"
		rm "${X_PARROT_BIN}.gz"
		return 1
	fi

	# Uncompress parrot
	gunzip "${X_PARROT_BIN}.gz"
	if [ $? -ne 0 ]; then
		echo "ERROR: Could not decompress parrot_run binary!"
		rm "${X_PARROT_BIN}*" 
		return 1
	fi

	# Make sure it's executable
	chmod +x ${X_PARROT_BIN}

	# Export
	PARROT_BIN=${X_PARROT_BIN}
	return 0

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
	local CACHE_DIR="${HOME}/.cvmu/boot"
	[ ! -d ${CACHE_DIR} ] && mkdir $CACHE_DIR

	# Check if this boot script is already cached
	BOOT_FILES=${CACHE_DIR}/files-${BOOT_NAME}.tbz2
	BOOT_CONFIG=${CACHE_DIR}/${BOOT_NAME}.boot
	[ -f ${BOOT_CONFIG} ] && return 0

	# Otherwise download
	curl -s -o "${BOOT_CONFIG}" "${CVMU_SERVER_URL}/boot/${BOOT_NAME}.boot"
	[ $? -ne 0 ] && echo "ERROR: Could not download boot configuration!" && rm ${BOOT_CONFIG} return 1
	curl -s -o "${BOOT_FILES}" "${CVMU_SERVER_URL}/boot/files-${BOOT_NAME}.tbz2"
	[ $? -ne 0 ] && echo "ERROR: Could not download boot files!" && rm ${BOOT_CONFIG} && rm ${BOOT_FILES} && return 1

	# We are good
	return 0
}

#
# Setup a CERN-Specific CVMFS repository
#
# Exports: CVMFS_PUB_KEY, CVMFS_CACHE, CVMFS_REPOS, CVMFS_URL, CVMFS_PROXY
#
function setup_cvmfs_cern {
	local CONFIG_DIR=$1
	local REPOS_NAME=$1

	# This works *only* for .cern.ch
	[ $(echo "$REPOS_NAME" | grep -c '.cern.ch$') ]

	# Configurable parameters
	local CFG_CVMFS_SERVER_URL="http://cvmfs-stratum-one.cern.ch/cvmfs/@fqrn@;http://cernvmfs.gridpp.rl.ac.uk/cvmfs/@fqrn@;http://cvmfs.racf.bnl.gov/cvmfs/@fqrn@;http://cvmfs.fnal.gov/cvmfs/@fqrn@;http://cvmfs02.grid.sinica.edu.tw/cvmfs/@fqrn@"
	local CFG_CVMFS_PROXY="auto;DIRECT"

	# [CVMFS_PUB_KEY] : CERN Public Key
	CVMFS_PUB_KEY=${CONFIG_DIR}/cern.ch.pub
	if [ ! -f ${CVMFS_PUB_KEY} ]; then
		echo "LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUEyc2I4U25WVklCZVlrN2YyYmhtbgp1b2laN1dqZ0taOTBERVY1T0picXJWVXNuNlMrSkpSRSs1dThPY0xZMHdyY3BkcE5yazlZc3NTZVRmMzA1bk83CkloS1J3VG9pYzNuL0l0RW93MUluYzZQZG44aFFJZVFIYno4cjdHZUN3dktuU0dvSmYvVTQvSmh0ZG54THpZeGUKN3h2VUw4dG1wVUM5QjRxZTM0aFhhRmxVYnpxZHVldjJobmRGbkt4MmNNeVdKbkVWVWtTNzVPQXlNNkFzRFRyeApIV3prZlg3TmFjcUZONndnd3RZK0dhOU5WMHhBT2p6RHdtY2xDMnV4RC9iZmdhOGo2ZDBjUU9zWnIwTDF0RUhRCnFTdzV6YWVRaWpPeDhZYVpDN3llUDdyS2NGTHkxUEkrK0psV1RibkN0NnFrZm1LTGpTQmwwd2pycUxIZ29nUW4KUndJREFRQUIKLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0tCg==" | base64 -d > ${CVMFS_PUB_KEY}
	fi

	# [CVMFS_REPOS] : Repository name
	CVMFS_REPOS="${REPOS_NAME}"

	# [CVMFS_CACHE] : Cache directory
	CVMFS_CACHE="${CONFIG_DIR}/${CVMFS_REPOS}-cache"
	[ ! -d ${CVMFS_CACHE} ] && mkdir ${CVMFS_CACHE}

	# [CVMFS_PROXY] : Proxy URLs
	if [ -z "${CVMFS_HTTP_PROXY}" ]; then
		CVMFS_PROXY=${CFG_CVMFS_PROXY}
	else
		CVMFS_PROXY="${CVMFS_HTTP_PROXY}"
	fi

	# [CVMFS_URL] : Server URL
	CVMFS_URL=$(echo "$CFG_CVMFS_SERVER_URL" | sed "s/@fqrn@/${CVMFS_REPOS}/g")

}

#
# Cleanup temporary directory
#
function cleanup {
	# Cleanup temp dir if specified
	[ ! -z "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
	# Return always 0
	return 0
}

# ----------------------------------------------
# Boot script macro implementation
# ----------------------------------------------

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

# Get options from command-line
options=$(getopt -o hc:b: -l cvmfs:,boot: -- "$@")
if [ $? -ne 0 ]; then
	usage
	exit 1
fi
eval set -- "$options"

# Default options
BOOT_CONFIG=""
CVMFS_REPOS=""

# Process options
while true
do
	case "$1" in
		-h|--help)          usage && exit 0;;
		-b|--boot)          BOOT_CONFIG="$2"; shift 2;;
		-c|--cvmfs)         CVMFS_REPOS="${CVMFS_REPOS} $2"; shift 2;;
		--)                 shift 1; break ;;
		*)                  break ;;
	esac
done

# Detect environment
detect_env || exit 1

# Download boot script if not specified
if [ -z "$BOOT_CONFIG" ]; then
	echo "INFO: Downloading latest CVMU boot specifications"
	setup_boot "latest" || exit 1
fi

# Validate boot script
is_script_invalid ${BOOT_CONFIG} && { echo "ERROR: Invalid boot specifications found!"; exit 1 }

# Download/obtain parrot_run utility
setup_parrot || { echo "ERROR: Could not find/download parrot_run utility!"; exit 1 }

# Base directory (inside parrot environment)
BASE_DIR="/cvmfs/cernvm-devel.cern.ch/cvm3"

# Create temporary working directory and internal structure
TEMP_DIR=$(mktemp -d)
GUESTRW_DIR="${TEMP_DIR}/root" && mkdir ${GUESTRW_DIR}
CVMFS_DIR="${TEMP_DIR}/cvmfs" && mkdir ${CVMFS_DIR}
PARROT_DIR="${TEMP_DIR}/parrot" && mkdir ${PARROT_DIR}

# Setup basic parrot args
PARROT_ARGS="${PARROT_ARGS} -f -t '${PARROT_DIR}'"

# Setup CVMFS 
setup_cvmfs_cern ${CVMFS_DIR} cernvm-devel.cern.ch || { echo "ERROR: Could not configure cernvm-devel.cern.ch CVMFS repository!"; cleanup; exit 1 }
PARROT_CVMFS_REPO="${CVMFS_REPOS}:url=${CVMFS_URL},proxies=${CVMFS_PROXY},pubkey=${CVMFS_PUB_KEY},cachedir=${CVMFS_CACHE},mountpoint=/cvmfs/${CVMFS_REPOS}"

# Setup additional CVMFS directories
REPOS=""
for REPO in $CVMFS_REPOS; do
	setup_cvmfs_cern ${CVMFS_DIR} ${REPO} || { echo "ERROR: Could not configure ${REPO} CVMFS repository!"; cleanup; exit 1 }
	PARROT_CVMFS_REPO="${PARROT_CVMFS_REPO} ${CVMFS_REPOS}:url=${CVMFS_URL},proxies=${CVMFS_PROXY},pubkey=${CVMFS_PUB_KEY},cachedir=${CVMFS_CACHE},mountpoint=/cvmfs/${CVMFS_REPOS}"
done

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
export PARROT_CVMFS_REPO=${PARROT_CVMFS_REPO}
eval "${PARROT_BIN} ${PARROT_ARGS} -w /home/${USERNAME} $* /home/${USERNAME}/.bootstrap"

# Remove directory upon exit
echo "CernVM-Lite: Cleaning-up environment"
rm -rf ${TEMP_DIR}
