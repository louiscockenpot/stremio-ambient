#!/usr/bin/env bash
# Installe (ou met à jour) le remplissage flouté des bandes noires dans le
# Stremio flatpak de l'utilisateur courant. Relançable sans risque.
#
# Le bac à sable de Stremio ne voit pas le dossier personnel : le shader et la
# bibliothèque sont donc copiés dans son dossier de configuration
# (~/.var/app/com.stremio.Stremio/config, son XDG_CONFIG_HOME), puis la
# bibliothèque y est préchargée par un override flatpak de l'utilisateur.
set -euo pipefail

app=com.stremio.Stremio
repo=$(cd "$(dirname "$0")" && pwd)
dest=$HOME/.var/app/$app/config/stremio-ambient
lib=$dest/libstremio-ambient.so

if ! command -v flatpak >/dev/null 2>&1; then
  echo "install.sh : la commande flatpak est introuvable" >&2
  exit 1
fi
if ! flatpak info "$app" >/dev/null 2>&1; then
  echo "install.sh : Stremio n'est pas installé en flatpak ($app)" >&2
  echo "  flatpak install flathub $app" >&2
  exit 1
fi

mkdir -p "$dest"
install -m 644 "$repo/ambient-fill.glsl" "$dest/"
install -m 755 "$repo/libstremio-ambient.so" "$dest/"

previous=$(flatpak override --user --show "$app" | sed -n 's/^LD_PRELOAD=//p')
if [ -n "$previous" ] && [ "$previous" != "$lib" ]; then
  echo "install.sh : LD_PRELOAD valait « $previous », il est remplacé" >&2
fi
flatpak override --user --env=LD_PRELOAD="$lib" "$app"

echo "Installé dans $dest"
echo "Quitte complètement Stremio puis relance-le."
