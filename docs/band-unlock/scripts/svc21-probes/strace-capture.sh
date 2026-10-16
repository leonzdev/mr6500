# Capture swiapp startup QMI/QRTR traffic via strace.
# Kill supervisor first (so it won't relaunch), then swiapp, then run swiapp under strace.
kill -9 602 2>/dev/null
kill -9 604 2>/dev/null
sleep 1
# make sure no swiapp lingers
kill -9 $(pgrep -x swiapp) 2>/dev/null
sleep 1
: > /tmp/swi_start.strace
: > /tmp/swi_start.err
setsid strace -f -tt -e trace=network -x -s 65536 -o /tmp/swi_start.strace /usr/bin/swiapp </dev/null >/dev/null 2>/tmp/swi_start.err &
echo "launched strace+swiapp"
sleep 20
# stop the traced swiapp + strace
kill -9 $(pgrep -f 'strace') 2>/dev/null
kill -9 $(pgrep -x swiapp) 2>/dev/null
sleep 1
# restore supervisor (detached so it survives telnet close)
setsid sh -c 'nice -n -19 /usr/sbin/restart_swiapp >/dev/null 2>&1' &
sleep 1
echo "=== capture done ==="
echo "strace lines:"; wc -l < /tmp/swi_start.strace
echo "err head:"; head -8 /tmp/swi_start.err
echo "supervisor back?"; pgrep -x restart_swiapp | head -1
echo "swiapp back?"; pgrep -x swiapp | head -1
