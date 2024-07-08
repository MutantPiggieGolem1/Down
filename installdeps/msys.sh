#!/usr/bin/bash

# msys - Git For Windows

if ! command -v jq &> /dev/null; then
    echo "Installing Dependency: jq"
    curl -L -o /usr/bin/jq.exe https://github.com/stedolan/jq/releases/latest/download/jq-win64.exe
else
    echo "Dependency Present: jq"
fi

if ! command -v yt-dlp &> /dev/null; then
    echo "Installing Dependency: yt-dlp"
    curl -L -o /usr/bin/yt-dlp.exe https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe
else
    echo "Dependency Present: yt-dlp"
fi

if ! command -v aria2 &> /dev/null; then
    echo "Installing Dependency: aria2"
    resp=$(curl -s -X GET "https://api.github.com/repos/aria2/aria2/releases/latest")
    url=$(jq -r '.assets | map(select(.name|endswith(".zip") and contains("-win-64bit-"))) | .[].browser_download_url' <<< "$resp")
    curl -L -o aria2.zip "$url" && unzip -o -q aria2.zip -d ./aria2
    mv ./aria2/**/aria2c.exe /usr/bin/aria2c.exe
    rm aria2.zip
    rm -r ./aria2
else
    echo "Dependency Present: aria2"
fi