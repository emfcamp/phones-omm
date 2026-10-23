#!/bin/bash

OMM_DIR="/opt/SIP-DECT"
OMM_BIN="$OMM_DIR/bin/SIP-DECT"
OMM_PID_FILE="/var/run/SIP-DECT.pid"
ICS_BIN="$OMM_DIR/bin/ics"
ICS_PID_FILE="/var/run/SIP-ICS.pid"

copy_local_firmware() {
    local firmware_dir="$1"
    local filename

    for filename in SIP-DECT.bin iprfp3G.dnld iprfp4G.dnld; do
        if [ ! -f "$firmware_dir/$filename" ]; then
            echo "Firmware directory $firmware_dir is missing $filename" >&2
            return 1
        fi
    done

    echo "Copying OMM firmware from $firmware_dir"
    for filename in SIP-DECT.bin iprfp3G.dnld iprfp4G.dnld; do
        cp "$firmware_dir/$filename" "$OMM_DIR/$filename" || return 1
    done
}

download_firmware() {
    local work_dir archive member firmware_dir filename wanted found
    local sip_member=""
    local iprfp3g_member=""
    local iprfp4g_member=""
    local -a members

    for filename in SIP-DECT.bin iprfp3G.dnld iprfp4G.dnld; do
        if [ -e "$OMM_DIR/$filename" ] && [ ! -f "$OMM_DIR/$filename" ]; then
            echo "Cannot install firmware: $OMM_DIR/$filename exists but is not a regular file" >&2
            return 1
        fi
    done

    work_dir=$(mktemp -d "$OMM_DIR/.firmware-download.XXXXXX") || return 1
    archive="$work_dir/firmware.zip"

    echo "SIP-DECT.bin not found; downloading the OMM firmware archive from OMM_URL"
    if ! wget -q -O "$archive" -- "$OMM_URL"; then
        echo "Unable to download the OMM firmware archive" >&2
        rm -f "$archive"
        rmdir "$work_dir"
        return 1
    fi

    if ! unzip -Z1 "$archive" > "$work_dir/members"; then
        echo "OMM_URL did not return a readable ZIP archive" >&2
        rm -f "$archive" "$work_dir/members"
        rmdir "$work_dir"
        return 1
    fi
    mapfile -t members < "$work_dir/members"

    # Releases either put these files at the ZIP root or together inside a
    # SIP-DECT* directory. Locate SIP-DECT.bin first, then require its siblings.
    for member in "${members[@]}"; do
        if [[ "$member" != "SIP-DECT.bin" && ! "$member" =~ ^SIP-DECT[-A-Za-z0-9._+]*/SIP-DECT\.bin$ ]]; then
            continue
        fi

        firmware_dir="${member%/*}"
        if [ "$firmware_dir" = "$member" ]; then
            firmware_dir=""
        else
            firmware_dir="$firmware_dir/"
        fi

        found=0
        for wanted in "${firmware_dir}iprfp3G.dnld" "${firmware_dir}iprfp4G.dnld"; do
            for filename in "${members[@]}"; do
                if [ "$filename" = "$wanted" ]; then
                    found=$((found + 1))
                    break
                fi
            done
        done

        if [ "$found" -eq 2 ]; then
            sip_member="$member"
            iprfp3g_member="${firmware_dir}iprfp3G.dnld"
            iprfp4g_member="${firmware_dir}iprfp4G.dnld"
            break
        fi
    done

    if [ -z "$sip_member" ]; then
        echo "The archive does not contain SIP-DECT.bin, iprfp3G.dnld and iprfp4G.dnld in the same supported directory" >&2
        rm -f "$archive" "$work_dir/members"
        rmdir "$work_dir"
        return 1
    fi

    # Extract only the three files that OMM needs, rather than unpacking the
    # complete release archive.
    if ! unzip -p "$archive" "$sip_member" > "$work_dir/SIP-DECT.bin" ||
       ! unzip -p "$archive" "$iprfp3g_member" > "$work_dir/iprfp3G.dnld" ||
       ! unzip -p "$archive" "$iprfp4g_member" > "$work_dir/iprfp4G.dnld"; then
        echo "Unable to extract OMM firmware from the archive" >&2
        rm -f "$work_dir/SIP-DECT.bin" "$work_dir/iprfp3G.dnld" "$work_dir/iprfp4G.dnld" "$archive" "$work_dir/members"
        rmdir "$work_dir"
        return 1
    fi

    for filename in SIP-DECT.bin iprfp3G.dnld iprfp4G.dnld; do
        if ! mv "$work_dir/$filename" "$OMM_DIR/$filename"; then
            echo "Unable to store $filename in $OMM_DIR" >&2
            rm -f "$work_dir/SIP-DECT.bin" "$work_dir/iprfp3G.dnld" "$work_dir/iprfp4G.dnld" "$archive" "$work_dir/members"
            rmdir "$work_dir"
            return 1
        fi
    done
    rm -f "$archive" "$work_dir/members"
    rmdir "$work_dir"
    echo "OMM firmware downloaded successfully"
}

if [ ! -f "$OMM_DIR/SIP-DECT.bin" ]; then
    if [ -f /firmware/SIP-DECT.bin ]; then
        copy_local_firmware /firmware || exit 4
    elif [ -n "${OMM_URL:-}" ]; then
        download_firmware || exit 4
    fi
fi

if [ ! -x "$OMM_DIR/bin/SIP-DECT.sh" ]; then
    if [ ! -f "$OMM_DIR/SIP-DECT.bin" ]; then
        echo "SIP-DECT.bin not found; mount the firmware files or set OMM_URL to a release ZIP URL" >&2
        exit 4
    fi
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
OMM_START_PARAMETER+=(-http "${OMM_HTTP_PORT:-80}")
OMM_START_PARAMETER+=(-https "${OMM_HTTPS_PORT:-443}")
if [ "${OMM_NOROOT+x}" = x ]; then
    OMM_START_PARAMETER+=(-noroot)
fi
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
