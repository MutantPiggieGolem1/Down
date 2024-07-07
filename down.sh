#!/usr/bin/bash

PLAYLISTURL=$1
BATCHSIZE=5

if (! command -v jq &> /dev/null) || (! command -v yt-dlp &> /dev/null) || (! command -v aria2c &> /dev/null); then
    echo "Missing Dependencies. Please run installdeps.sh"
    exit 1
fi

PLAYLISTLEN="$(yt-dlp --flat-playlist --dump-single-json "$PLAYLISTURL" | jq '.entries | length' )"

for ((c = 1; c <= PLAYLISTLEN ; c+=BATCHSIZE )); do
    yt-dlp -f "m4a/bestaudio" "$PLAYLISTURL" \
        --playlist-start $c --playlist-end "$((c+BATCHSIZE-1))" \
        --add-metadata -o "./output/%(id)s.%(ext)s" \
        --external-downloader aria2c --external-downloader-args '--max-connection-per-server=16'
    sleep 5000;
done