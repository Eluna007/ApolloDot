#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scripts_dir=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=scripts/lib/apollo-paths.sh
source "$scripts_dir/lib/apollo-paths.sh"
apollo_paths_init

wallpaper=${1:-$APOLLO_STATE_HOME/wallpaper/current}
if [[ -z "$wallpaper" || ! -e "$wallpaper" ]]; then
    mkdir -p "$APOLLO_STATE_HOME/logs"
    printf '%s - ERROR: no wallpaper path found\n' "$(date -Is)" \
        >> "$APOLLO_STATE_HOME/logs/wallpaper-overview.log"
    exit 1
fi
if ! command -v magick >/dev/null 2>&1; then
    printf 'ImageMagick (magick) is required for overview wallpaper caches\n' >&2
    exit 127
fi

blur_dir=$APOLLO_CACHE_HOME/wallpaper/blur
overview_dir=$APOLLO_CACHE_HOME/wallpaper/overview
state_dir=$APOLLO_STATE_HOME/wallpaper
mkdir -p "$blur_dir" "$overview_dir" "$state_dir" "$APOLLO_STATE_HOME/logs"

filename=$(basename -- "$wallpaper")
blurred=$blur_dir/blurred_$filename
overview=$overview_dir/overview_$filename
if [[ ! -f "$blurred" || ! -f "$overview" ]]; then
    magick "$wallpaper" -blur 0x15 -fill black -colorize 40% "$overview"
    magick "$wallpaper" -blur 0x30 "$blurred"
fi

ln -sfn -- "$wallpaper" "$state_dir/current"
ln -sfn -- "$blurred" "$state_dir/blurred"
ln -sfn -- "$overview" "$state_dir/overview"
printf '%s - linked %s\n' "$(date -Is)" "$filename" \
    >> "$APOLLO_STATE_HOME/logs/wallpaper-overview.log"
