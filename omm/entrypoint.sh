#!/bin/bash

OMM_DIR="/opt/SIP-DECT"
OMM_BIN="$OMM_DIR/bin/SIP-DECT"
OMM_PID_FILE="/var/run/SIP-DECT.pid"
ICS_BIN="$OMM_DIR/bin/ics"
ICS_PID_FILE="/var/run/SIP-ICS.pid"

if [ ! -x "$OMM_DIR/bin/SIP-DECT.sh" ]; then
    sh "$OMM_DIR/SIP-DECT.bin"
fi

if [ ! -x "$OMM_BIN" ]; then
    echo "OMM, $OMM_BIN not installed!" >&2
    exit 5
fi

rm -f "$OMM_DIR"/*.log 2>/dev/null || true

cd "$OMM_DIR"
ulimit -n 32768 -c unlimited

# Fix library path so we can run the binary outside of /opt/SIP-DECT
export LD_LIBRARY_PATH="$OMM_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [ -f /etc/sysconfig/SIP-DECT ]; then
    . /etc/sysconfig/SIP-DECT
fi

OMM_START_PARAMETER=()
ICS_START_PARAMETER=()
if [ -n "$OMM_IF" ]; then
    OMM_START_PARAMETER+=(-i "$OMM_IF")
    ICS_START_PARAMETER+=(-i "$OMM_IF")
fi
if [ -n "$OMM_CONFIG_FILE" ]; then
    OMM_START_PARAMETER+=(-file "$OMM_CONFIG_FILE")
fi
if [ -n "$OMM_IPV4_ADDR" ]; then
    OMM_START_PARAMETER+=(-ipv4 "$OMM_IPV4_ADDR")
fi
if [ -n "$OMM_IPV6_ADDR" ]; then
    OMM_START_PARAMETER+=(-ipv6 "$OMM_IPV6_ADDR")
fi

start_omm() {
    echo "Starting SIP-DECT: $OMM_BIN ${OMM_START_PARAMETER[*]} -d"
    "$OMM_BIN" "${OMM_START_PARAMETER[@]}" -d
    /sbin/pidof -s "$OMM_BIN" -o %PPID > "$OMM_PID_FILE"
    echo "SIP-DECT started, pid $(cat "$OMM_PID_FILE" 2>/dev/null)"
}

start_ics() {
    if [ -x "$ICS_BIN" ]; then
        echo "Starting ics: $ICS_BIN ${ICS_START_PARAMETER[*]} -d"
        "$ICS_BIN" "${ICS_START_PARAMETER[@]}" -d
        /sbin/pidof -s "$ICS_BIN" -o %PPID > "$ICS_PID_FILE"
        echo "ics started, pid $(cat "$ICS_PID_FILE" 2>/dev/null)"
    else
        echo "ics binary not found at $ICS_BIN, skipping"
    fi
}

term_handler() {
    trap - TERM INT
    PID=$(cat "$OMM_PID_FILE" 2>/dev/null)
    [ -n "$PID" ] && kill -TERM "$PID" 2>/dev/null
    ICS_PID=$(cat "$ICS_PID_FILE" 2>/dev/null)
    [ -n "$ICS_PID" ] && kill -TERM "$ICS_PID" 2>/dev/null
    exit 0
}
trap term_handler TERM INT

start_omm
start_ics

while :; do
    PID=$(cat "$OMM_PID_FILE" 2>/dev/null)
    if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
        echo "SIP-DECT (pid $PID) is no longer running, exiting" >&2
        exit 1
    fi
    if [ -x "$ICS_BIN" ]; then
        ICS_PID=$(cat "$ICS_PID_FILE" 2>/dev/null)
        if [ -z "$ICS_PID" ] || ! kill -0 "$ICS_PID" 2>/dev/null; then
            echo "ICS (pid $ICS_PID) is no longer running, exiting" >&2
            exit 1
        fi
    fi
    sleep 3
done
