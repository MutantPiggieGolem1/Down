#!/usr/bin/bash

PLAYLISTURL=$1
BATCHSIZE=5

if ! command -v jq &> /dev/null; then
    echo "Installing Dependency: jq"
    curl -L -o /usr/bin/jq.exe https://github.com/stedolan/jq/releases/latest/download/jq-win64.exe
fi

if ! command -v yt-dlp &> /dev/null; then
    echo "Installing Dependency: yt-dlp"
    curl -L -o /usr/bin/yt-dlp.ext https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe
fi

PLAYLISTLEN="$(yt-dlp --flat-playlist --dump-single-json "$PLAYLISTURL" | jq '.entries | length' )"

for ((c = 1; c <= PLAYLISTLEN ; c+=BATCHSIZE )); do
    yt-dlp -f "m4a/bestaudio" "$PLAYLISTURL" \
        --playlist-start $c --playlist-end "$((c+BATCHSIZE-1))" \
        --add-metadata -o "./output/%(id)s.%(ext)s" \
        --external-downloader aria2c --external-downloader-args '--max-connection-per-server=16'
    sleep 5000;
done