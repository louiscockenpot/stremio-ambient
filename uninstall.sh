#!/usr/bin/env bash
# Retire le remplissage flouté : Stremio retrouve son lecteur d'origine au
# prochain lancement.
set -euo pipefail

app=com.stremio.Stremio
dest=$HOME/.var/app/$app/config/stremio-ambient

flatpak override --user --unset-env=LD_PRELOAD "$app"
rm -f "$dest/ambient-fill.glsl" "$dest/libstremio-ambient.so" "$dest/stremio-ambient.c"
[ -d "$dest" ] && rmdir --ignore-fail-on-non-empty "$dest"

echo "Désinstallé. Quitte complètement Stremio puis relance-le."
