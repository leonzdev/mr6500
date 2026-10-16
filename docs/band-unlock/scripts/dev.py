#!/usr/bin/env python3
"""Run commands on the MR6500 device root shell over telnet (192.168.3.1:23).
Usage:
  dev.py 'command; command2'          # run one shell command batch
  dev.py -f script.sh                 # run contents of a file
Reads commands from argv or -f, executes on device, prints output.
Handles telnet IAC negotiation and uses a sentinel to delimit output.
"""
import socket, sys, time, os

HOST, PORT = "192.168.3.1", 23
IAC, DONT, DO, WONT, WILL, SB, SE = 255,254,253,252,251,250,240

def negotiate(sock, data, out):
    i = 0
    resp = bytearray()
    while i < len(data):
        b = data[i]
        if b == IAC and i+1 < len(data):
            cmd = data[i+1]
            if cmd in (DO, DONT) and i+2 < len(data):
                opt = data[i+2]
                resp += bytes([IAC, WONT if cmd==DO else WONT, opt])
                i += 3; continue
            if cmd in (WILL, WONT) and i+2 < len(data):
                opt = data[i+2]
                resp += bytes([IAC, DONT if cmd==WILL else DONT, opt])
                i += 3; continue
            if cmd == SB:
                j = data.find(bytes([IAC,SE]), i)
                i = (j+2) if j!=-1 else len(data); continue
            i += 2; continue
        out.append(b); i += 1
    if resp:
        sock.sendall(bytes(resp))

def run(cmd, timeout=25):
    s = socket.create_connection((HOST, PORT), timeout=10)
    s.settimeout(1.5)
    out = bytearray()
    # drain banner / negotiation
    t0 = time.time()
    while time.time()-t0 < 3:
        try:
            d = s.recv(4096)
            if not d: break
            negotiate(s, d, out)
        except socket.timeout:
            break
    out.clear()
    SENT = "___DONE_%d___" % (int(time.time()*1000) % 100000)
    payload = (cmd + "\n" + "echo " + SENT + "\n")
    s.sendall(payload.encode())
    t0 = time.time()
    buf = bytearray()
    while time.time()-t0 < timeout:
        try:
            d = s.recv(4096)
            if not d: break
            negotiate(s, d, buf)
            if SENT.encode() in bytes(buf).split(b"echo",1)[-1] or bytes(buf).count(SENT.encode())>=1:
                # ensure we got the echoed marker as output line (not the command echo)
                if bytes(buf).count(SENT.encode()) >= 2 or (b"\n"+SENT.encode() in bytes(buf)):
                    break
        except socket.timeout:
            if bytes(buf).count(SENT.encode()) >= 2:
                break
            continue
    s.close()
    text = bytes(buf).decode(errors="replace")
    # strip everything up to and including the command echo, and the sentinel tail
    # Print raw-ish but cleaned
    lines = text.replace("\r","").split("\n")
    cleaned = []
    for ln in lines:
        if SENT in ln:
            # stop at the marker echo
            break
        cleaned.append(ln)
    # drop the first line if it's the echoed command
    result = "\n".join(cleaned)
    return result

if __name__ == "__main__":
    args = sys.argv[1:]
    tmo = 25
    if args and args[0] == "-t":
        tmo = int(args[1]); args = args[2:]
    if args and args[0] == "-f":
        cmd = open(args[1]).read()
    else:
        cmd = " ".join(args)
    sys.stdout.write(run(cmd, tmo))
    sys.stdout.flush()
