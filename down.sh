#!/usr/bin/bash
set -o errexit -o pipefail -o noclobber -o nounset

# === Argument Parsing & Checks ===

getopt --test > /dev/null && true # ignore errexit with `&& true`
if [[ $? -ne 4 ]]; then
    echo "Argument Parse Error."
    exit 1
fi

# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
# -if getopt fails, it complains itself to stdout
PARSED=$(getopt --options=b:o:h --longoptions=batch:,output:,help --name "$0" -- "$@") || exit 2
eval set -- "$PARSED"

BATCHSIZE=5
OUTPUT="./media"

while true; do
    case "$1" in
        -h|--help)
            printf "YT Playlist Downloader & Metadata Extractor"
            exit 0
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -b|--batch)
            BATCHSIZE="$2"
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

if [[ $# -ne 1 ]] || [[ -z $1 ]]; then
    echo "Playlist URL Required."
    exit 4
fi

if ! [ -d "$OUTPUT" ]; then
    echo "Output directory missing."
    exit 4
fi

if ! [ -w "$OUTPUT" ]; then
    echo "Output directory unwritable."
    exit 4
fi

if ! [ -w "$(pwd)" ]; then
    echo "Working directory unwritable."
    exit 4
fi

PLAYLISTURL=$1
OUTPUT=${OUTPUT%"/"}

if (! command -v jq &> /dev/null) || (! command -v yt-dlp &> /dev/null) || (! command -v aria2c &> /dev/null); then
    echo "Missing Dependencies. Please run ./installdeps/$OSTYPE.sh"
    exit 1
fi

# === Operation ===

echo "Fetching Info.."

# shellcheck disable=SC2207
PLAYLISTITEMS=($(yt-dlp --flat-playlist --dump-single-json "$PLAYLISTURL" | jq -cr '.entries | map(.id) | join(" ")'))
PLAYLISTLEN=${#PLAYLISTITEMS[@]}

for i in "${!PLAYLISTITEMS[@]}"; do
    ITEM=${PLAYLISTITEMS[i]}
    str="Downloading [$i/$PLAYLISTLEN ($((100*i/PLAYLISTLEN))%)].."
    if [ $(( i % BATCHSIZE )) == 0 ]; then
        read -r -p "$str [Enter to continue]"; #wait for input
    else
        echo "$str" #just spit out progress
    fi

    yt-dlp -f "m4a/bestaudio" "https://www.youtube.com/watch?v=$ITEM" --no-warnings -q --progress \
        --download-archive "./inprog/archive.txt" \
        --add-metadata --write-description -o "./inprog/%(id)s.%(ext)s" \
        --external-downloader aria2c --external-downloader-args '--max-connection-per-server=16' \
        -x --audio-quality 0 --audio-format m4a
    dfile="./inprog/$ITEM.description"
    afile="$ITEM.m4a"
    if ! [ -f "./inprog/$afile" ]; then # If the associated audio file is no longer present (i.e. info already written)
        if [ -f "$dfile" ]; then rm "$dfile"; fi
        continue
    fi
    description="$(cat "$dfile")"
    if [[ $description == *"Auto-generated by YouTube." ]]; then
        # shellcheck disable=SC2207
        res=($(python extractinfo.py "$dfile")) # split by spaces
        if (( ${#res[@]} != 0 )); then # if not empty (i.e. parse success)
            rm "$dfile"
            echo "Writing info for $ITEM"
            ffmpeg -i "./inprog/$afile" -hide_banner -loglevel warning \
                -metadata "date=${res[0]}" -metadata "year=${res[1]}" \
            -c copy -y "$OUTPUT/$afile"
            rm "./inprog/$afile"
            continue;
        else
            echo "Failed to extract info from $dfile"
        fi
    else
        echo "Couldn't parse info from $dfile"
    fi
done

echo "Downloading Complete!"