# stremio-ambient

![C](https://img.shields.io/badge/C-glibc%202.34%2B-A8B9CC?logo=c&logoColor=white) ![GLSL](https://img.shields.io/badge/GLSL-shader%20mpv-5586A4?logo=opengl&logoColor=white) ![libmpv](https://img.shields.io/badge/libmpv-0.41-691F69?logo=mpv&logoColor=white) ![Stremio](https://img.shields.io/badge/Stremio-1.2-8A5AAB?logo=stremio&logoColor=white) ![Flatpak](https://img.shields.io/badge/Flatpak-Flathub-4A90D9?logo=flatpak&logoColor=white) ![GNOME Platform](https://img.shields.io/badge/GNOME%20Platform-50-4A86CF?logo=gnome&logoColor=white) ![Linux](https://img.shields.io/badge/Linux-x86__64-FCC624?logo=linux&logoColor=white)

Sur un écran ultra-large (32:9), Stremio laisse de grandes bandes noires à gauche et à droite d'un film en 16:9. Ce repo les remplit avec un prolongement flouté et assombri de l'image, façon « ambilight » : l'image elle-même reste intacte, centrée, pixel pour pixel.

Pour le **Stremio flatpak de Flathub** (`com.stremio.Stremio`, testé en version 1.2.2 avec son libmpv 0.41, GNOME Platform 50) sur Linux x86_64. Testé avec une puce graphique Intel Iris Xe et une carte Nvidia GeForce RTX 3060 Ti.

## Contenu

| Fichier | Rôle |
| --- | --- |
| `ambient-fill.glsl` | Shader mpv qui fabrique le remplissage flouté |
| `libstremio-ambient.so` | Bibliothèque préchargée dans Stremio qui active le shader (déjà compilée) |
| `stremio-ambient.c` | Source de la bibliothèque |
| `install.sh` / `uninstall.sh` | Installation et retrait pour l'utilisateur courant |
| `Makefile` | Recompilation de la bibliothèque |

## Installation sur une autre machine

1. Installer Stremio depuis Flathub, si ce n'est pas déjà fait :

   ```bash
   flatpak install flathub com.stremio.Stremio
   ```

2. Cloner le repo et lancer le script :

   ```bash
   git clone https://github.com/louiscockenpot/stremio-ambient.git ~/Documents/stremio-ambient
   cd ~/Documents/stremio-ambient
   ./install.sh
   ```

3. Quitter complètement Stremio, puis le relancer.

Aucun compilateur n'est nécessaire : la bibliothèque fournie tourne dans le runtime du flatpak (glibc 2.42), pas sur la glibc de la machine, et marche donc sur n'importe quelle distribution x86_64. Ni `sudo` ni droits administrateur : tout se passe dans le dossier personnel.

Pour mettre à jour après un `git pull`, relancer `./install.sh` puis Stremio.

### Ce que fait `install.sh`

Le bac à sable de Stremio n'a pas accès au dossier personnel, donc le script copie les fichiers dans le dossier de configuration du flatpak, puis demande à flatpak de précharger la bibliothèque. À la main, ça donne :

```bash
dest=~/.var/app/com.stremio.Stremio/config/stremio-ambient
mkdir -p "$dest"
cp ambient-fill.glsl libstremio-ambient.so "$dest"/
flatpak override --user --env=LD_PRELOAD="$dest/libstremio-ambient.so" com.stremio.Stremio
```

Le chemin de `LD_PRELOAD` doit être absolu (`/home/<utilisateur>/…`, pas `~`).

## Vérifier que ça marche

Lancer Stremio depuis un terminal et ouvrir une vidéo :

```bash
flatpak run com.stremio.Stremio 2>&1 | grep stremio-ambient
```

La ligne `stremio-ambient: remplissage activé` doit apparaître. `flatpak override --user --show com.stremio.Stremio` doit montrer la ligne `LD_PRELOAD=…`.

Sur un film en 16:9, les côtés doivent montrer le prolongement flouté. Si l'image est au contraire étirée sur toute la largeur, la bibliothèque est bien chargée mais le shader n'a pas pu être compilé par le pilote graphique (Stremio n'affiche pas les messages de mpv).

## Quand le remplissage est actif

- **Seulement si un écran externe est allumé** : la bibliothèque regarde `/sys/class/drm/*/enabled` et ignore la dalle interne d'un portable (connecteurs `eDP`, `LVDS`, `DSI`). Sur un portable seul, le lecteur reste celui d'origine. Sur un **PC fixe**, tous les écrans sont « externes » (DP, HDMI) : le remplissage est donc toujours actif.
- L'état des écrans est relu à chaque action dans le lecteur (lecture, pause, volume…) : brancher l'écran pendant un film est pris en compte à la commande suivante.
- Le mode « Rogner » de Stremio coupe le remplissage.
- Le shader ne travaille que si la fenêtre est plus large que la vidéo. Dans le cas inverse (film plus large que la fenêtre, comme un 2.39:1 sur un écran 16:9), il remet de simples bandes noires en haut et en bas, comme le lecteur d'origine.

## Réglages

En haut de la passe « composite » de `ambient-fill.glsl` :

```glsl
#define GAIN_NEAR 0.80   // luminosité du remplissage contre l'image (1.0 = identique)
#define GAIN_FAR 0.45    // luminosité au bord de l'écran
#define SATURATION 1.0   // 1.0 = couleurs inchangées, 0.0 = gris
```

Modifier le fichier du repo, relancer `./install.sh`, puis relancer Stremio.

## Désinstallation

```bash
./uninstall.sh
```

Ou à la main : `flatpak override --user --unset-env=LD_PRELOAD com.stremio.Stremio`, puis supprimer `~/.var/app/com.stremio.Stremio/config/stremio-ambient`.

## Recompiler la bibliothèque

Seulement si `stremio-ambient.c` a été modifié :

```bash
make -B                                           # avec gcc ou clang
make -B CC="zig cc -target x86_64-linux-gnu.2.34" # sans compilateur : toolchain zig décompressée n'importe où
./install.sh
```

## Fonctionnement

Le Stremio flatpak (stremio-linux-shell : GTK + libmpv par l'API de rendu) crée son lecteur mpv sans `config=yes` et ne laisse passer qu'une liste fixe de propriétés : aucun `mpv.conf` n'est lu, impossible d'y déclarer un shader.

`libstremio-ambient.so`, chargée par `LD_PRELOAD`, s'intercale sur deux fonctions de libmpv :

- `mpv_initialize` : une fois mpv prêt, charge le shader (`glsl-shaders`) si un écran externe est allumé ;
- `mpv_set_property` : Stremio remet `keepaspect=yes` à chaque lecture ; la bibliothèque le garde à `no` tant que le shader est actif, et suit le mode « Rogner » (`panscan > 0`).

Avec `keepaspect=no`, mpv étire la vidéo sur toute la fenêtre. Le shader intervient avant cette mise à l'échelle, au stade `MAIN` : il agrandit l'image au ratio de la fenêtre, recopie l'original au centre et remplit les marges avec un miroir de ses bords, flouté (deux niveaux de flou mélangés selon la distance) et assombri vers le bord de l'écran. L'étirement de mpv devient une mise à l'échelle uniforme, sans déformation. Une source plus haute que la fenêtre (4K sur un écran 1440p) est réduite par le shader lui-même, pour ne pas doubler le coût.

La bibliothèque retire `LD_PRELOAD` de l'environnement une fois chargée dans le lecteur, pour ne pas le transmettre au serveur node et aux processus WebKit.

## Limites connues

- **Performances** : sur un Intel Iris Xe, une source 4K HDR passe d'environ 23 ms à 34 ms de rendu par image (budget 42 ms à 24 i/s). Ça tient, sans grande marge. Une carte graphique plus récente n'aura pas de souci.
- **Sous-titres ASS positionnés** (option « style ASS » de Stremio) : placés par rapport à la fenêtre entière, ils peuvent tomber dans les marges. Les sous-titres texte ordinaires ne bougent pas.
- Une ligne `ERROR: ld.so: object '…libstremio-ambient.so' cannot be preloaded … ignored` dans les journaux vient des sous-processus WebKit isolés, qui ne voient pas le fichier. Elle est sans effet.
- **Cartes Nvidia** : vérifié sur une GeForce RTX 3060 Ti (pilote propriétaire 580.178.04, KDE Plasma sous Wayland, écran 5120×1440). Le remplissage s'affiche et la carte reste peu chargée, environ 20 % en lecture, bureau compris. Le flatpak a besoin de l'extension `org.freedesktop.Platform.GL.nvidia-<version du pilote>`, que `flatpak update` installe normalement toute seule ; `flatpak list --runtime | grep GL.nvidia` doit montrer la même version que `nvidia-smi`. Les cartes AMD n'ont pas été testées.
- Une mise à jour de Stremio qui changerait sa façon de piloter mpv pourrait désactiver le remplissage (le lecteur redevient alors celui d'origine).
