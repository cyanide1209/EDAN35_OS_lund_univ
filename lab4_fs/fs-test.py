#!/bin/env python3
import pexpect
import time
import logging as log
import sys
import os
import tempfile
import re

def clear_buf(p):
	try:
		p.read_nonblocking(9999, timeout=0.1)
	except:
		return

def run_cmd(cmd, expstr=None, exitcode=None):
	outstr, exitstatus = pexpect.run(cmd, withexitstatus=True)
	if exitcode is not None and exitcode != exitstatus:
		log.error(f"Test for {cmd} failed. The expected exit code was {exitcode}, but got {exitstatus}.")
		return False

	# expect empty result
	if expstr is None:
		log.info(f"Test for '{cmd}' passed.")
		return True

	# compare the output
	if expstr != outstr.strip().decode():
		log.error(f"Test for '{cmd}' failed: Expected {expstr} but got {outstr.strip().decode()}.")
		return False

	log.info(f"Test for '{cmd}' passed.")
	return True

def check_c_time(file, start_time, end_time):
	t = os.path.getctime(file)
	if not t0 - 1 < t < t1 + 1:
		log.error(f"Creation time for {file} should be between {time.ctime(t0)} and {time.ctime(t1)}, but is {time.ctime(t)}")
	else:
		log.info(f"Test for {file} creation time passed")

def check_m_time(file, start_time, end_time):
	t = os.path.getatime(file)
	if not t0 - 1 < t < t1 + 1:
		log.error(f"Modification time for {file} should be between {time.ctime(t0)} and {time.ctime(t1)}, but is {time.ctime(t)}")
	else:
		log.info(f"Test for {file} modification time passed")

if __name__ == "__main__":
	log.basicConfig(level=log.INFO)
	current_dir = os.getcwd()
	with tempfile.TemporaryDirectory() as tmpdir:
		# Format everything
		_, exitcode = pexpect.run("./format_myfs", withexitstatus=True)
		if exitcode != 0:
			log.error("Error while formatting.")
		# Start the file system
		p = pexpect.spawn(f"./ssfs -f {tmpdir}")
		# Check that the directory is in the mounting table
		output = pexpect.run("mount")
		if str(tmpdir) not in str(output):
			log.error(f"The file system was not mounted at {tmpdir}.")
			exit(1)
		# Change directory to the mountpoint
		os.chdir(tmpdir)
		log.info(f"Working in {tmpdir}")
		# Create a file and check its creation timestamp
		t0 = time.time()
		run_cmd("touch file1.txt", exitcode=0)
		t1 = time.time()
		check_c_time("file1.txt", t0, t1)
		# Modify a file and check its modification timestamp
		t0 = time.time()
		if os.path.exists("file1.txt"):
			print("Hello!", file=open("file1.txt", "w"))
		t1 = time.time()
		check_m_time("file1.txt", t0, t1)
		# Rename the file
		run_cmd("mv file1.txt file2.txt", exitcode=0)
		# Check that the old name does not exist
		run_cmd("cat file1.txt", exitcode=1)
		# Check that the contents are correct
		run_cmd("cat file2.txt", "Hello!", exitcode=0)
		# Remove a file
		run_cmd("rm file2.txt", exitcode=0)
		run_cmd("cat file2.txt", exitcode=1)
		# Modify the size of the file
		run_cmd("truncate -s 100 file1.txt", exitcode=0)
		run_cmd("du -b file1.txt", "100\tfile1.txt", exitcode=0)
		# Reduce the size
		run_cmd("truncate -s 50 file1.txt", exitcode=0)
		run_cmd("du -b file1.txt", "50\tfile1.txt", exitcode=0)
		# Increase the size
		run_cmd("truncate -s 200 file1.txt", exitcode=0)
		run_cmd("du -b file1.txt", "200\tfile1.txt", exitcode=0)
		# Check that reading with ofsset works (read the last 16 bytes)
		BLOCK_SIZE = 512
		with open("file3.txt", "w") as f:
			for i in range(BLOCK_SIZE//2):
				f.write("{:02x}".format(i))
		run_cmd("tail -c 16 file3.txt", "f8f9fafbfcfdfeff", exitcode=0)

		fd =  os.open("file4.txt", os.O_WRONLY | os.O_CREAT)
		for i in range(4):
			os.write(fd, (str(i) * BLOCK_SIZE).encode("utf-8"))
		# The last number written to the file should be hex(0200) = 512
		run_cmd("du -b file4.txt", str(4 * BLOCK_SIZE) + "\tfile4.txt", exitcode=0)
		run_cmd("tail -c 4 file4.txt", "3333", exitcode=0)

		os.chdir(current_dir)
		# print(pexpect.run("./info_myfs").decode())
		p.close(force=True)
