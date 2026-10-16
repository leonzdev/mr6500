#!/usr/bin/env python3
"""Send AT commands to MR6500 AT port 192.168.3.1:5510 and print responses.
Usage: at.py 'AT!BAND=?' 'AT!BAND?' ...   (each arg is one AT command)
"""
import socket, sys, time

HOST, PORT = "192.168.3.1", 5510

def at(cmds, settle=1.2):
    s = socket.create_connection((HOST, PORT), timeout=6)
    s.settimeout(settle)
    # drain
    try:
        while True:
            if not s.recv(1024): break
    except socket.timeout:
        pass
    out = []
    for c in cmds:
        s.sendall((c + "\r\n").encode())
        time.sleep(0.2)
        buf = b""
        t0 = time.time()
        while time.time() - t0 < 6:
            try:
                d = s.recv(4096)
                if not d:
                    break
                buf += d
                if b"OK\r\n" in buf or b"ERROR" in buf or b"\r\nERROR" in buf:
                    # small grace for trailing
                    time.sleep(0.15)
                    try:
                        while True:
                            more = s.recv(4096)
                            if not more: break
                            buf += more
                    except socket.timeout:
                        pass
                    break
            except socket.timeout:
                break
        out.append("$ " + c + "\n" + buf.decode(errors="replace"))
    s.close()
    return "\n".join(out)

if __name__ == "__main__":
    cmds = sys.argv[1:]
    if not cmds:
        cmds = ["ATI"]
    print(at(cmds))
