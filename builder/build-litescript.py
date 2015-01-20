#!/usr/bin/python
import sys

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
		# The output configuration script
		self.output = "output.sh"

		# -- Internal properties ---------

		# Which directories to include in the file archive
		self.dirInclude = []
		# Which directories to exclude from the file archive
		self.dirExclude = []
		# The lines of code to append in the config file
		self.script = []

	def loadRulesetActions(self, filename):
		"""
		This function reads the ruleset from the filename specified
		and returns an array with the sequence of actions to perform
		"""

		# Actions to be performed
		actions = []

		# Read file
		with open(filename, 'r') as f:

			# Read lines
			for l in f.readlines():

				# Skip comments and blank lines
				l = l.strip()
				if not l or l[0] == "#":
					continue

				# Store action
				actions.append( l.split(":") )

		# Return actions
		return actions

	def expandBrackets(self, expression):
		"""
		Expand the brackets in the expression in the same
		way bash does. For example:

		this{ is, was} : "this is", "this was"
		"""

		# Start by expanding the outer macro
		


	def runActions(self, actions):
		"""
		Run the specified set of actions
		"""
		for args in actions:

			# Unshift action from the arguments
			action = args.pop(0).lower()

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
				self.script.append("MACRO_RO ${BASE_DIR}/%s ${GUEST_DIR}/%s" % (args[0], args[0]))

			# [writable]
			# 
			# Create a new, writable directory in the location specified
			# by the first argument. Optionally create the directory
			# structure defined in the second argument.
			#
			elif action == "bind":

				# Append a MACRO_RW action
				self.script.append("MACRO_RW ${GUEST_DIR}/%s" % args[0])

				# Process directory structure arguments
				if len(args) > 1:

					# Each one individually
					for structDir in args[1].split(" "):

						# Append a MACRO_MKDIR action
						self.script.append("MACRO_MKDIR ${GUEST_DIR}/%s" % args[0])


def showHelp():
	"""
	Display the help screen
	"""
	print "CernVM Litescript Build Utility v1.0"
	print "This script creates a configuration file which is used by the"
	print "cernvm-liteboot.sh in order to boot into a particular CernVM"
	print "distribution in userland or in restricted environments"
	print ""
	print "Usage:"
	print ""
	print "  build-litescript.py <ruleset> <output>"
	print ""
	print "Parameters:"
	print " <ruleset> : The ruleset to use for building the LiteScript"
	print "  <output> : The resulting configuration file"
	print ""

# Entry point
if __name__ == "__main__":

	# Check for missing arguments
	if len(sys.argv) < 2:
		showHelp()
		sys.exit(0)

	# Load ruleset 