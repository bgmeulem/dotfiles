#!/usr/bin/env bash
# Wrapper for catt cast with optional --local-audio flag.
# Usage:
#   cast [catt cast options ...]
#   cast --local-audio [-s subs.srt] movie.mkv
#
# In non-local-audio mode, if a subtitle file with the same basename
# (movie.vtt or movie.srt) exists next to the video, it is auto-added.

set -euo pipefail

if ! command -v catt >/dev/null 2>&1; then
  echo "catt not found. Please install catt (Cast All The Things) and make sure it's on your \$PATH"
  exit 1
fi

# === Config ===
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LOCAL_AUDIO_SCRIPT="$SCRIPT_DIR/main.py"

# === Parse arguments ===
USE_LOCAL_AUDIO=false
ARGS=()


# === Helper: reset Chromecast ===
reset_chromecast() {
  echo "Resetting chromecast device(s) ..."
  uv --project="$SCRIPT_DIR" run python - <<'PYCODE'
import pychromecast
casts, browser = pychromecast.get_chromecasts()
print("Found {} casts".format(len(casts)))
for c in casts:
    try:
        c.wait()
        c.quit_app()
        print(f"→ Chromecast {c.name} reset.")
    except Exception as e:
        print(f"Could not reset {c.name}: {e}")
pychromecast.discovery.stop_discovery(browser)
PYCODE
}

trap reset_chromecast EXIT

for arg in "$@"; do
  case "$arg" in
    --local-audio)
      USE_LOCAL_AUDIO=true
      ;;
    --reset)
      # Cleanup is trapped on exit, so just exit
      exit 0
      ;;
    *)
      ARGS+=("$arg")
      ;;
  esac
done



# === Local-audio mode ===
if $USE_LOCAL_AUDIO; then
  VIDEO=""
  # Extract the first non-option as the video (ignore -s/--subtitles etc.)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--subtitles) shift 2 ;;
      -f|--force-default) shift ;;
      --local-audio) shift ;;
      -*) shift ;;    # skip other options and their single args if present
      *)
        VIDEO="$1"; shift
        ;;
    esac
  done

  if [[ -z "$VIDEO" ]]; then
    echo "Error: you must specify a video file when using --local-audio"
    echo "Example: cast --local-audio -s subs.srt mymovie.mkv"
    exit 1
  fi

  echo "Casting with local audio using: $LOCAL_AUDIO_SCRIPT"
  uv --project="$SCRIPT_DIR" run "$LOCAL_AUDIO_SCRIPT" "$VIDEO"

else
  # 1) Check if user already provided -s/--subtitles
  HAVE_SUB_ARG=false
  for a in "${ARGS[@]}"; do
    if [[ "$a" == "-s" || "$a" == "--subtitles" ]]; then
      HAVE_SUB_ARG=true
      break
    fi
  done

  # 2) Determine the media argument (assume last positional arg)
  #    We’ll take the last ARGS element that doesn’t start with "-".
  MEDIA=""
  for ((i=${#ARGS[@]}-1; i>=0; i--)); do
    if [[ "${ARGS[i]}" != -* ]]; then
      MEDIA="${ARGS[i]}"
      break
    fi
  done

  # 3) If MEDIA is a local file and no explicit subtitles were provided,
  #    auto-detect same-basename .vtt or .srt
  if [[ "$HAVE_SUB_ARG" == false && -n "$MEDIA" && -f "$MEDIA" ]]; then
    dir="$(dirname -- "$MEDIA")"
    base="$(basename -- "$MEDIA")"
    stem="${base%.*}"

    # Prefer .vtt, then .srt; check case-insensitively
    cand_vtt_lower="$dir/$stem.vtt"
    cand_vtt_upper="$dir/$stem.VTT"
    cand_srt_lower="$dir/$stem.srt"
    cand_srt_upper="$dir/$stem.SRT"

    SUBFILE=""
    if [[ -f "$cand_vtt_lower" ]]; then
      SUBFILE="$cand_vtt_lower"
    elif [[ -f "$cand_vtt_upper" ]]; then
      SUBFILE="$cand_vtt_upper"
    elif [[ -f "$cand_srt_lower" ]]; then
      SUBFILE="$cand_srt_lower"
    elif [[ -f "$cand_srt_upper" ]]; then
      SUBFILE="$cand_srt_upper"
    fi

    if [[ -n "$SUBFILE" ]]; then
      echo "Detected subtitle file: $SUBFILE"
      # Append --subtitles <file> just before MEDIA to keep order tidy
      # Find index of MEDIA in ARGS
      new_args=()
      for ((i=0; i<${#ARGS[@]}; i++)); do
        if [[ "${ARGS[i]}" == "$MEDIA" ]]; then
          new_args+=("--subtitles" "$SUBFILE")
        fi
        new_args+=("${ARGS[i]}")
      done
      ARGS=("${new_args[@]}")
    fi
  fi

  echo "Casting via catt..."
  uv --project="$SCRIPT_DIR" run catt cast "${ARGS[@]}"
fi
