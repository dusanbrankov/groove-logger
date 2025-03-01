#!/bin/bash

song_history="$HOME/.radiopl"

if [ ! -f "$song_history" ] || [ ! -w "$song_history" ]; then
    echo "Missing file or not writable: $song_history" >&2
    exit 1
fi

if ! command -v hxextract >/dev/null; then
    echo "Missing command: hxextract" <&2
    echo "This command is included in the 'html-xml-utils' package"
    exit 1
fi

song_hist_html() {
    local url html max_retries
    url=https://somafm.com/groovesalad/songhistory.html
    html="$(curl --max-time 10 -Lfs "$url")"
    max_retries=5

    for (( i = 0; i < max_retries; i++ )); do
        (( retries = max_retries - i - 1 ))
        test -n "$html" && break
        if (( retries == 0 )); then
            echo "Failed to get song, exiting script" >&2
            exit 1
        fi
        echo "Couldn't get song, retrying ($retries left)..." >&2
        sleep 10
    done

    printf '%s' "$html"
}

song_hist_table() {
    hxextract table <(song_hist_html) 2>/dev/null | grep -EA1 '<td>[0-9]{2}:[0-9]{2}:[0-9]{2}</td>' | tac
}

get_last_song() {
    tail -1 "$song_history" | awk '{print substr($0, index($0, $3))}'
}

printf 'Starting "Groove Salad" playlist recorder...\n\n'
printf "%-21s %s\n" "Save song names to:" "$song_history"
printf '%-21s "%s"\n' "Last saved:" "$(get_last_song)"
printf "%-21s %s\n\n" "Currently saved:" "$(wc -l < "$song_history")"

echo "Listening for songs..."

t=0
local_time=
song=
while true; do
    while IFS= read -r line; do
        if grep ^- >/dev/null <<< "$line"; then
            t=0
            local_time=
            continue
        fi
        (( t++ ))
        if (( t == 1 )); then
            song="$(sed -En 's:<td>(.*)</td><td>(.*)</td><td>.*$:\1 - \2:p' <<< "$line")"
        fi
        if (( t == 2 )); then
            if [ -z "$song" ] || grep -F "$song" <(tail -30 "$song_history") >/dev/null; then
                continue
            fi
            utc8="$(sed -E 's/^.*<td.*>(..:..).*<\/td>.*$/\1/' <<< "$line")"
            local_time="$(date -d "$utc8 UTC-8" +'%Y-%m-%d %R')"
            echo "$local_time $song" | tee -a "$song_history"
            song=
        fi
    done < <(song_hist_table)

    sleep 10m
done
