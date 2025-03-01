#!/bin/bash

trap 'echo "Exiting..."; exit 0' SIGINT SIGTERM

song_history="$HOME/.radiopl"
conn_max_retries=5

if [ ! -f "$song_history" ] || [ ! -w "$song_history" ]; then
    echo "Missing file or not writable: $song_history" >&2
    exit 1
fi

get_song_history() {
    local url html
    url=https://somafm.com/groovesalad/songhistory.html
    html="$(curl --max-time 10 -Lfs "$url")"

    for (( i = 0; i < conn_max_retries; i++ )); do
        (( retries = conn_max_retries - i - 1 ))
        test -n "$html" && break
        if (( retries == 0 )); then
            echo "Failed to get song, exiting script" >&2
            exit 1
        fi
        echo "Couldn't get song, retrying ($retries left)..." >&2
        sleep 10
    done

    printf '%s' "$html"
    # cat /tmp/songhistory.html
}

get_recent_songs() {
    hxextract table <(get_song_history) 2>/dev/null | grep -EA1 '<td>[0-9]{2}:[0-9]{2}:[0-9]{2}</td>'
    # hxextract table <(get_song_history) 2>/dev/null | sed -En 's:<td>(.*)</td><td>(.*)</td><td>.*$:\1 - \2:p' | tac
}

get_last_song() {
    tail -1 "$song_history" | awk '{print substr($0, index($0, $3))}'
}

printf 'Starting "Groove Salad" playlist recorder...\n\n'
printf "%-21s %s\n" "Save song names to:" "$song_history"
printf '%-21s "%s"\n' "Last saved:" "$(get_last_song)"
printf "%-21s %s\n\n" "Currently saved:" "$(wc -l < "$song_history")"

echo "Listening for songs..."

while true; do
    while IFS= read -r song; do
        if ! grep -F "$song" <(tail -30 "$song_history") >/dev/null; then
            # if [ "$song" = ]
            echo "$(date +"%Y-%m-%d %H:%M") $song" | tee -a "$song_history"
        fi
    done < <(get_recent_songs)

    sleep 20m
done
