import pexpect
import sys
import time

child = pexpect.spawn('npx -y skills add supabase/agent-skills', encoding='utf-8', timeout=30)
child.logfile = sys.stdout

try:
    child.expect('Ok to proceed')
    child.sendline('y')
except:
    pass

try:
    child.expect('Select skills to install')
    time.sleep(2)
    child.send(" ")
    time.sleep(0.5)
    child.send("\x1b[B")
    time.sleep(0.5)
    child.send(" ")
    time.sleep(0.5)
    child.send("\r")
    child.expect(pexpect.EOF, timeout=60)
except Exception as e:
    print("Error:", e)
