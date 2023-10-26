#!/bin/env python3
import pexpect
import time
import logging as log
import sys
import os
import tempfile
import re

# Tested with sh, dash
# prompt = '$'

def clear_buf(p):
	try:
		p.read_nonblocking(9999, timeout=0.1)
	except:
		return


# timeout is in seconds, 1s would be enough for the "default" case
def test_cmd(cmd, expstr=[], lines=1, timeout=1, mintime=None):
	log.info("TESTING:"+cmd)
	clear_buf(p)

	t0 = time.time()
	p.sendline(cmd)
	p.expect(cmd+"\r\n")
	outstr = []
	if expstr != []:
		try:
			p.expect(expstr[0], timeout=timeout)
			outstr.append(p.after)
#			log.info(f"{p.before}-----{p.after}")
		except pexpect.TIMEOUT:
			log.error(f"Timeout waiting for {expstr[0]}")

	t1 = time.time()
	# discard the rest of the output

	# verify whether the command finished too early
	if mintime and (t1 - t0) < mintime:
		log.info(f"{p.before}|{p.after}")
		log.error(f"Test for {cmd} failed: The command finished earlier than expected: {t1-t0} < {mintime}")
		return False

	# expect empty result
	if expstr == []:
	#	p.read_nonblocking(size=9999, timeout=.1)
	#	p.expect(".*\r\n")
		log.info(f"Test for {cmd} passed. {p.after}")
		return True

	# output number of lines is different
	if len(expstr) != len(outstr):
		log.error(f"Test for {cmd} failed: Expected {expstr} but got {outstr} in {p.before}|{p.after}")
		return False

	for ous, exs in zip(outstr, expstr):
		ous = ous.strip().decode()
		if (exs not in ous):
			log.error(f"Test for {cmd} failed: Expected {exs} but got {ous}")
			return False
	log.info(f"Test for {cmd} passed.")
	return True

if __name__ == "__main__":
	if len(sys.argv) != 2:
		log.error(f"Run as: {sys.argv[0]} SHELL_EXEC")
	else:
		shell_exec = os.path.abspath(sys.argv[1])
		log.basicConfig(level=log.INFO)
		with tempfile.TemporaryDirectory() as tmpdir:
			os.chdir(tmpdir)
			log.info(f"Working in {tmpdir}")
			p = pexpect.spawn(shell_exec) #,encoding='utf-8')
			p.read_nonblocking(size=9999, timeout=.1)
			test_cmd('pwd', [tmpdir])
			test_cmd('/bin/pwd', [tmpdir])
			test_cmd('echo \'Hello!\'', ['Hello!'])
			test_cmd('ls -a',['.  ..'])
			test_cmd('touch file1.txt')
			test_cmd('touch file1.txt; ls', ['file1.txt'])
			# test_cmd('echo hello && echo world',['hello','world'],lines=2)
			# test_cmd('sleep 3 && echo world &',['world'],lines=2,timeout=1)
			test_cmd('sleep 3 ; echo hello', ['hello'],timeout=4,mintime=3)
			test_cmd('echo Hi > file2.txt')
			test_cmd('cat < file2.txt', ['Hi'])
			test_cmd('cat < file2.txt > file3.txt; cat file3.txt',['Hi'])
			test_cmd('cat file2.txt | wc -l',['1'])
			test_cmd('cat file2.txt | cat | cat | cat | cat | wc -l',['1'])
			# test_cmd('echo 1 && echo 2',['1\r\n2'], lines=2)
			# test_cmd('echo x | cat | wc -l && echo 2', ['1\r\n2'], lines=2)
			test_cmd('sleep 2; echo Done',['Done'],timeout=3)
			test_cmd('cd /home; cd -; pwd',[tmpdir+'\r\n'+tmpdir], lines=2)
			test_cmd('cd /home; cd -; cd -; cd -',[tmpdir+'\r\n/home\r\n'+tmpdir], lines=3)
			test_cmd('cd .; pwd',[tmpdir])
			test_cmd(f'cd /home; cd ..; pwd; cd {tmpdir}',['/'])
			test_cmd(f'cd /home; cd ..; cd ..; cd ..; pwd; cd {tmpdir}',['/'])
			test_cmd('echo world &',['world'])
