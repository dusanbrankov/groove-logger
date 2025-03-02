#!/bin/bash

set -u

: "${SFM_LOG_DIR:=$HOME/sfm-groove-logger}"
: "${SFM_CHECK_INTERVAL:=5m}"
: "${SFM_CHANNELS:=groovesalad,gsclassic}"

IFS=, read -ra CHANNELS <<< "$SFM_CHANNELS"

error() { printf '%s\n' "$*" >&2; }

if ! mkdir -p "$SFM_LOG_DIR"; then
    error "Failed to create directory: $SFM_LOG_DIR"
    exit 1
fi

for channel in "${CHANNELS[@]}"; do
    logfile="$SFM_LOG_DIR/$channel"
    if ! test -f "$logfile" && ! touch "$logfile"; then
        error "Failed to write to $logfile"
        exit 1
    fi
done

if ! command -v hxextract >/dev/null; then
    error "Missing command: hxextract"
    printf "The command is included in the 'html-xml-utils' package\n"
    exit 1
fi

playlist_html() {
    local url html max_retries
    url="https://somafm.com/$1/songhistory.html"
    html="$(curl --max-time 10 -Lfs "$url")"
    max_retries=5

    for (( i = 0; i < max_retries; i++ )); do
        (( retries = max_retries - i - 1 ))
        test -n "$html" && break
        if (( retries == 0 )); then
            error "Failed to get song, exiting script"
            exit 1
        fi
        error "Couldn't get song, retrying ($retries left)..."
        sleep 10
    done

    printf '%s' "$html"
}

playlist_table() {
    hxextract table <(playlist_html "$1") 2>/dev/null | grep -aEA1 '<td>[0-9]{2}:[0-9]{2}:[0-9]{2}.*</td>' | tac
}

last_saved_song() {
    tail -1 "$SFM_LOG_DIR/$1" | awk '{print substr($0, index($0, $3))}'
}

printf 'Starting "SomaFM Groove Logger"...\n\n'
printf "%-21s %s/\n" "Save song names in:" "$SFM_LOG_DIR"
printf "%-21s %s\n" "Included channels:" "${SFM_CHANNELS//,/, }"

for channel in "${CHANNELS[@]}"; do
    printf "\n%-21s %s\n" "Channel:" "$channel"
    printf '%-21s "%s"\n' "Last saved:" "$(last_saved_song "$channel")"
    printf "%-21s %s\n" "Currently saved:" "$(wc -l < "$SFM_LOG_DIR/$channel")"
done

printf "\nListening...\n"

while true; do
    line_count=0
    song=
    for channel in "${CHANNELS[@]}"; do
        while IFS= read -r line; do
            if grep ^- >/dev/null <<< "$line"; then
                line_count=0
                continue
            fi
            (( line_count++ ))
            if (( line_count == 1 )); then
                song="$(sed -En 's:<td>(.*)</td><td>(.*)</td><td>.*$:\1 - \2:p' <<< "$line")"
            fi
            if (( line_count == 2 )); then
                if test -z "$song" || grep -F "$song" <(tail -30 "$SFM_LOG_DIR/$channel") >/dev/null; then
                    continue
                fi
                utc8="$(sed -E 's/^.*<td.*>(..:..).*<\/td>.*$/\1/' <<< "$line")"
                local_time="$(date -d "$utc8 UTC-8" +'%Y-%m-%d %R')"
                printf "%-21s %s\n" "$channel:" "$local_time $song"
                printf "%s\n" "$local_time $song" >> "$SFM_LOG_DIR/$channel"
                song=
            fi
        done < <(playlist_table "$channel")
        sleep 1
    done

    sleep "$SFM_CHECK_INTERVAL"
done
