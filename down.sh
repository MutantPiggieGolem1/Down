#!/usr/bin/bash
set -o errexit -o pipefail -o noclobber -o nounset

# === Argument Parsing & Checks ===

getopt --test > /dev/null && true # ignore errexit
if [[ $? -ne 4 ]]; then
    echo "Argument Parse Error."
    exit 1
fi

# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
# -if getopt fails, it complains itself to stdout
PARSED=$(getopt --options=n:o:has --longoptions=output:,help --name "$0" -- "$@") || exit 2
eval set -- "$PARSED"

LIMIT="-1"
OUTPUT="$HOME/Music"

while true; do
    case "$1" in
        -h|--help)
            printf "down - YT Playlist Downloader & Metadata Extractor [version 2.0.0]

Usage:\tdown <playlist id> [options]

Command options:
  -o, --output dir\tset final file destination (Default ~/Music)
  -n n            \tset number of songs to attempt downloading (Default -1)
  -h, --help      \tprints this message."
            exit 0
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -n)
            LIMIT="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Argument Parse Error."
            exit 3
            ;;
    esac
done

if (! command -v jq &> /dev/null) || (! command -v yt-dlp &> /dev/null) || (! command -v aria2c &> /dev/null); then
    echo "Missing Dependencies. [jq, yt-dlp, aria2]"
    exit 1
fi

if [[ $# -ne 1 ]] || [[ -z $1 ]]; then
    echo "Playlist ID Required."
    exit 4
fi

OUTPUT=${OUTPUT%"/"}
if ! [ -w "$OUTPUT" ]; then
    echo "Output directory missing or unwritable."
    exit 4
fi

# === Operation ===
printf "Downloading.."
# note: the +l flag is not in mainline yt-dlp yet
yt-dlp "https://www.youtube.com/playlist?list=$1" --no-warnings --progress \
    -o "$OUTPUT/%(id)s.%(ext)s" -f "m4a/bestaudio/best" -x --audio-quality 0 --audio-format m4a \
    --embed-metadata --output-na-placeholder "Unknown" \
        --parse-metadata "release_date:%(meta_date)s" \
        --parse-metadata "%(artists.0)s:%(meta_artist)s" \
        --parse-metadata "%(artists)+l:%(meta_artists)s" \
    --embed-thumbnail --ppa "EmbedThumbnail+ffmpeg: -c:v mjpeg -vf crop=\"'if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\"" \
    -N 4 --external-downloader aria2c --external-downloader-args '--max-connection-per-server=16' \
    --no-overwrites -I ":$LIMIT" --lazy-playlist;

printf "\r\033[KScanning [?/? (?%%)].."

# shellcheck disable=SC2207
PLAYLISTITEMS=($(yt-dlp --flat-playlist --dump-single-json "$PLAYLISTURL" | jq -cr '.entries | map(.id) | join(" ")'))
DIRITEMS=("$OUTPUT"/*.m4a)
DIRLEN=${#DIRITEMS[@]}

for i in "${!DIRITEMS[@]}"; do
    item=${DIRITEMS[i]}
    if ! [ -f "$item" ]; then continue; fi
    id=$(basename "$item")
    id="${id##*/}"
    id="${id%.*}"

    # shellcheck disable=SC2076
    if [[ ! "$id" == "EXT_"* ]] && [[ ! " ${PLAYLISTITEMS[*]} " =~ " ${id} " ]]; then
        rm "$item"
        printf "\r\033[KDeleting %s.m4a\n" "$id"
    fi
    printf "\r\033[KScanning [%s/%s (%s%%)].." "$((i+1))" "$DIRLEN" "$((100*(i+1)/DIRLEN))"
done
printf "\r\033[KScanning Complete!\n"