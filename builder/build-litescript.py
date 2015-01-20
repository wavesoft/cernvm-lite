#!/usr/bin/python

import os
import sys
import tempfile

class Builder:
	"""
	The configuration builder class
	"""

	def __init__(self):
		"""
		Initialize the configuration builder
		"""

		# -- Configurable parameters ----

		# The base filesystem location
		self.baseDir = "/mnt/.ro/cvm3/"

		# -- Internal properties ---------

		# Which directories to include in the file archive
		self.dirInclude = []
		# Which directories to exclude from the file archive
		self.dirExclude = []
		# Actions to be performed
		self.actions = []
		# Configurable parameters
		self.parameters = {}

		# Pre-expand and post-expand script
		self.script_pre = []
		self.script_post = []

	def saveScript(self, filename):
		"""
		Save the script into a file
		"""

		# Get the name of the output filename without the extension
		outName = filename
		if '.' in outName:
			outName = ".".join(os.path.basename(filename).split(".")[0:-1])

		# Get the output directory
		outDir = os.path.dirname(filename)
		if outDir:
			outDir += "/"

		# Calculate the name of the file archive
		archiveName = "%s-files.tbz2" % outName

		# Run tar to create the binary payload
		ans = os.system("tar -zcf %s%s -C %s %s %s" % (
			outDir,
			archiveName,
			self.baseDir,
			" ".join(map(lambda x: "--exclude='%s'" % x, self.dirExclude)),
			" ".join(self.dirInclude)
			)
		)

		# Open output file
		with open(filename, "w") as f:

			# Encapsulate all actions in function
			f.write("#\n")
			f.write("# Proceduraly generated function for setting-up the CernVM\n")
			f.write("# filesystem before final chroot.\n")
			f.write("#\n")
			f.write("function MACRO_PREPARE_FS {\n")
			f.write("\tlocal GUEST_DIR=$1\n")
			f.write("\tlocal SCRIPT_DIR=$( cd \"$( dirname \"${BASH_SOURCE[0]}\" )\" && pwd )\n")
			f.write("\t\n")

			# Write pre-expand script
			for line in self.script_pre:
				f.write("\t%s\n" % line)

			# Write expand code
			f.write("\ttar -C ${GUEST_DIR} -zxf ${SCRIPT_DIR}/%s\n" % archiveName)

			# Write post-expand script
			for line in self.script_post:
				f.write("\t%s\n" % line)

			# Close function
			f.write("}\n")

	def loadActions(self, filename):
		"""
		This function reads the ruleset from the filename specified
		and returns an array with the sequence of actions to perform
		"""

		# Reset actions
		self.actions = []

		# Read file
		with open(filename, 'r') as f:

			# Read lines
			for l in f.readlines():

				# Skip comments and blank lines
				l = l.strip()
				if not l or l[0] == "#":
					continue

				# Store action
				self.actions.append( l.split(":") )

	def compile(self):
		"""
		Compile the script by preparing the boilerplace and
		running the actions defined.
		"""

		# Run the actions
		for args in self.actions:

			# Unshift action from the arguments
			action = args.pop(0).lower()

			# Check if this is a post-action
			script = self.script_pre
			if action[0:5] == "post-":

				# Switch target script array to post
				action = action[5:]
				script = self.script_post


			# [copy]
			#
			# Copy the directory specified in the first
			# argument, excluding all the directories in
			# the second argument.
			#
			if action == "copy":

				# Store directory to copy in dirInclude
				self.dirInclude.append( args[0] )

				# Process exclude arguments
				if len(args) > 1:
					self.dirExclude.extend( args[1].split(" ") )

			# [readonly]
			# 
			# Create a read-only, bind-mount the directory specified
			# in the first argument from the base OS to the guest.
			#
			elif action == "readonly":

				# Append a MACRO_RO action
				script.append("MACRO_RO %s" % args[0])

			# [writable]
			# 
			# Create a new, writable directory in the location specified
			# by the first argument. Optionally create the directory
			# structure defined in the second argument.
			#
			elif action == "writable":

				# Append a MACRO_RW action
				script.append("MACRO_RW %s" % args[0])

				# Process directory structure arguments
				if len(args) > 1:

					# Append a MACRO_MKDIR action for every directory
					script.append("for XDIR in %s; do" % args[1])
					script.append("\tMACRO_MKDIR %s/${XDIR}" % args[0])
					script.append("done")

			# [touch]
			# 
			# Create a new, blank file in the first argument, using permissions
			# optionally specified in the second argument.
			#
			elif action == "touch":

				# Append a touch command
				script.append("touch ${GUEST_DIR}/%s" % args[0])

				# If we have a second argument, run chmod afterwards
				if len(args) > 1:
					script.append("chmod %s ${GUEST_DIR}/%s" % (args[1], args[0]))

			# [set]
			# 
			# Set a value to a configurable parameter
			#
			elif action == "set":

				# Update configurable parameter value
				self.parameters[ args[0] ] = args[1]


def showHelp():
	"""
	Display the help screen
	"""
	print "CernVM Litescript Build Utility v1.0"
	print "Usage:"
	print ""
	print "  build-litescript.py <ruleset> <output>"
	print ""
	print "Parameters:"
	print " <ruleset> : The ruleset to use for building the LiteScript"
	print "  <output> : The resulting configuration file"
	print ""
	print " This script creates a configuration file which is used by the"
	print " cernvm-liteboot.sh in order to boot into a particular CernVM"
	print " distribution in userland or in restricted environments"
	print ""

# Entry point
if __name__ == "__main__":

	# Check for missing arguments
	if len(sys.argv) < 3:
		print "ERROR: Missing arguments"
		showHelp()
		sys.exit(0)

	# Load ruleset
	builder = Builder()
	builder.loadActions( sys.argv[1] )

	# Compile script
	builder.compile()

	# Write it down
	builder.saveScript( sys.argv[2] )