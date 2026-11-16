#!/bin/bash
# Manual PortMaster launcher for Rune Below.
PORT_ROOT="$(cd -- "$(dirname -- "$0")" && pwd)" || exit 1
GAMEDIR="$PORT_ROOT/rune-below"
GAME="$GAMEDIR/RuneBelow.love"
if [ ! -f "$GAME" ] && [ -f "$PORT_ROOT/main.lua" ] && [ -f "$PORT_ROOT/conf.lua" ]; then
    GAME="$PORT_ROOT"
fi
mkdir -p "$GAMEDIR" || exit 1
cd "$GAMEDIR" || exit 1
exec > log.txt 2>&1

for candidate in /opt/system/Tools/PortMaster /opt/tools/PortMaster \
    "${XDG_DATA_HOME:-$HOME/.local/share}/PortMaster" \
    "$PORT_ROOT/PortMaster" "$PORT_ROOT/portmaster" /roms/ports/PortMaster /roms/ports/portmaster; do
    if [ -f "$candidate/control.txt" ]; then
        controlfolder="$candidate"
        break
    fi
done

if [ -z "$controlfolder" ]; then
    echo "Install or update PortMaster before running Rune Below."
    exit 1
fi
export controlfolder
source "$controlfolder/control.txt" || exit 1
if [ -f "$controlfolder/mod_${CFW_NAME}.txt" ]; then
    source "$controlfolder/mod_${CFW_NAME}.txt"
fi
get_controls

export RUNE_BELOW_HANDHELD=1
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
mkdir -p "$GAMEDIR/conf" || exit 1
export XDG_DATA_HOME="$GAMEDIR/conf"

runtime="$controlfolder/runtimes/love_11.5/love.txt"
if [ ! -f "$runtime" ]; then
    echo "LÖVE 11.5 is missing. Update PortMaster and its runtimes."
    exit 1
fi
source "$runtime" || exit 1
if [ -n "$GPTOKEYB" ] && [ -n "$LOVE_GPTK" ]; then
    $GPTOKEYB "$LOVE_GPTK" &
fi
pm_platform_helper "$LOVE_BINARY"
$LOVE_RUN "$GAME"
status=$?
pm_finish
exit "$status"
