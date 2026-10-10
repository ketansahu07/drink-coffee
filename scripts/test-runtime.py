#!/usr/bin/env python3
"""Bounded integration checks for the app and only its own child processes."""
import fcntl
import os
import pty
import select
import signal
import struct
import subprocess
import termios
import time
import sys
from pathlib import Path

BINARY = str(Path(sys.argv[1] if len(sys.argv) > 1 else '.build/debug/drink').resolve())
if not Path(BINARY).is_file():
    raise SystemExit('Build the app first with swift test or swift build.')


def child_of(parent):
    for _ in range(30):
        result = subprocess.run(['/usr/bin/pgrep', '-P', str(parent), '-x', 'caffeinate'], text=True, capture_output=True)
        if result.returncode not in (0, 1):
            raise AssertionError(result.stderr)
        if result.stdout.strip():
            return int(result.stdout.strip().splitlines()[0])
        time.sleep(0.03)
    raise AssertionError('No owned caffeinate child')


def absent(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return True
    return False


def cleanup(process):
    if process.poll() is None:
        process.terminate()
        process.communicate(timeout=4)


for sig in [signal.SIGINT, signal.SIGTERM, signal.SIGHUP]:
    process = subprocess.Popen([BINARY, 'coffee', '10s', '--no-animation'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        child = child_of(process.pid)
        command = subprocess.run(['/bin/ps', '-p', str(child), '-o', 'command='], text=True, capture_output=True).stdout
        assert '-w ' + str(process.pid) in command, command
        process.send_signal(sig)
        out, err = process.communicate(timeout=4)
        assert process.returncode == 128 + sig, (sig, process.returncode, out, err)
        assert absent(child), ('child survived', child)
        print('PASS', sig.name, 'cleans and reaps owned child')
    finally:
        cleanup(process)

process = subprocess.Popen([BINARY, 'coffee', '10s', '--no-animation'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
try:
    child = child_of(process.pid)
    os.kill(child, signal.SIGTERM)
    out, err = process.communicate(timeout=4)
    assert process.returncode == 1 and 'stopped unexpectedly' in err, (process.returncode, out, err)
    assert absent(child)
    print('PASS unexpected early child exit reports failure')
finally:
    cleanup(process)


def tty_run(extra_env, interrupt=None):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 30, 90, 0, 0))
    env = dict(os.environ)
    env['TERM'] = 'xterm-256color'
    env.update(extra_env)
    duration = '10s' if interrupt else '1s'
    process = subprocess.Popen([BINARY, 'coffee', duration, '--demo'], stdin=slave, stdout=slave, stderr=slave, env=env)
    os.close(slave)
    data = bytearray()
    interrupted = False
    try:
        while True:
            ready, _, _ = select.select([master], [], [], 2)
            if ready:
                try:
                    chunk = os.read(master, 65536)
                    if not chunk:
                        break
                    data.extend(chunk)
                    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', 22, 60, 0, 0))
                    if interrupt and b'\x1b[?25l' in data and not interrupted:
                        process.send_signal(interrupt)
                        interrupted = True
                except OSError:
                    break
            elif process.poll() is not None:
                break
        assert process.wait(timeout=3) == (128 + interrupt if interrupt else 0)
    finally:
        cleanup(process)
        os.close(master)
    return bytes(data)


plain = tty_run({'NO_COLOR': '1'})
assert b'\x1b[?1049h' in plain and b'\x1b[?25l' in plain
assert b'\x1b[?25h\x1b[?1049l' in plain and b'\x1b[38;' not in plain
assert b'Demo finished.' in plain
print('PASS animated TTY resize, NO_COLOR, cursor and alternate-screen restoration')

dumb = tty_run({'TERM': 'dumb'})
assert b'\x1b' not in dumb and b'Demo finished.' in dumb
print('PASS TERM=dumb emits no animation escapes')

for sig in [signal.SIGINT, signal.SIGTERM, signal.SIGHUP]:
    interrupted = tty_run({}, sig)
    assert b'\x1b[?25h\x1b[?1049l' in interrupted and b'Demo ended.' in interrupted
    print('PASS', sig.name, 'restores animated terminal')
