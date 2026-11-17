// libstremio-ambient.so — préchargée dans Stremio via LD_PRELOAD.
//
// Le shell Linux de Stremio pilote un mpv embarqué qui ne lit aucun fichier de
// configuration. Cette bibliothèque s'intercale sur deux fonctions de libmpv
// pour activer le shader ambient-fill.glsl (posé à côté d'elle) quand un écran
// externe est allumé :
//   - le shader est chargé et keepaspect passe à « no », ce qui lui confie le
//     cadrage de l'image (Stremio remet keepaspect=yes à chaque lecture) ;
//   - sans écran externe, ou en mode « Rogner » (panscan > 0), le shader est
//     retiré et les réglages de Stremio s'appliquent tels quels.
// L'état des écrans est relu à chaque réglage envoyé au lecteur (lecture,
// pause, volume…), donc un branchement en cours de séance est pris en compte.
//
// Compilation : zig cc -shared -fPIC -O2 -target x86_64-linux-gnu.2.34 \
//                   -o libstremio-ambient.so stremio-ambient.c
//           ou : gcc -shared -fPIC -O2 -o libstremio-ambient.so stremio-ambient.c

#define _GNU_SOURCE
#include <dirent.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef struct mpv_handle mpv_handle;

#define MPV_FORMAT_FLAG 3
#define MPV_FORMAT_DOUBLE 5

static char shader[4096]; // vide : bibliothèque inactive
static int ready;         // mpv initialisé
static int wanted_keep = 1; // dernier keepaspect demandé par Stremio
static int cropping;        // mode « Rogner » de Stremio (panscan > 0)
static int active = -1;     // shader chargé ? (-1 : pas encore décidé)
static int applied_keep = -1;

static int (*real_set)(mpv_handle *, const char *, int, void *);
static int (*real_set_string)(mpv_handle *, const char *, const char *);

__attribute__((constructor)) static void setup(void)
{
    // Seul le processus du lecteur est concerné : ne pas propager le
    // préchargement à ses enfants (serveur node, processus WebKit).
    char exe[4096];
    ssize_t n = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
    if (n > 0) {
        exe[n] = '\0';
        const char *base = strrchr(exe, '/');
        if (base && !strcmp(base + 1, "stremio"))
            unsetenv("LD_PRELOAD");
    }

    const char *config = getenv("XDG_CONFIG_HOME");
    if (config && *config) {
        snprintf(shader, sizeof(shader), "%s/stremio-ambient/ambient-fill.glsl", config);
        if (access(shader, R_OK) != 0)
            shader[0] = '\0';
    }
}

// Un connecteur vidéo autre que la dalle interne est-il allumé ?
static int external_display(void)
{
    const char *root = getenv("STREMIO_AMBIENT_SYSFS"); // pour les tests
    if (!root || !*root)
        root = "/sys/class/drm";

    DIR *dir = opendir(root);
    if (!dir)
        return 0;

    int found = 0;
    struct dirent *entry;
    while (!found && (entry = readdir(dir))) {
        // « card1-DP-1 » → « DP-1 »
        const char *connector = strchr(entry->d_name, '-');
        if (strncmp(entry->d_name, "card", 4) || !connector)
            continue;
        connector++;
        if (!strncmp(connector, "eDP", 3) || !strncmp(connector, "LVDS", 4) ||
            !strncmp(connector, "DSI", 3))
            continue;

        char path[4096], state[16] = "";
        snprintf(path, sizeof(path), "%s/%s/enabled", root, entry->d_name);
        FILE *file = fopen(path, "r");
        if (!file)
            continue;
        if (fgets(state, sizeof(state), file) && !strncmp(state, "enabled", 7))
            found = 1;
        fclose(file);
    }
    closedir(dir);
    return found;
}

static void apply(mpv_handle *ctx)
{
    if (!ready || !shader[0])
        return;

    int want = !cropping && external_display();
    if (want != active) {
        real_set_string(ctx, "glsl-shaders", want ? shader : "");
        active = want;
        fprintf(stderr, "stremio-ambient: remplissage %s\n", want ? "activé" : "désactivé");
    }

    int keep = want ? 0 : wanted_keep;
    if (keep != applied_keep) {
        real_set(ctx, "keepaspect", MPV_FORMAT_FLAG, &keep);
        applied_keep = keep;
    }
}

int mpv_initialize(mpv_handle *ctx)
{
    int (*real)(mpv_handle *) = dlsym(RTLD_NEXT, "mpv_initialize");
    real_set = dlsym(RTLD_NEXT, "mpv_set_property");
    real_set_string = dlsym(RTLD_NEXT, "mpv_set_property_string");

    int ret = real(ctx);
    if (ret >= 0 && real_set && real_set_string) {
        ready = 1;
        apply(ctx);
    }
    return ret;
}

int mpv_set_property(mpv_handle *ctx, const char *name, int format, void *data)
{
    if (!real_set)
        real_set = dlsym(RTLD_NEXT, "mpv_set_property");
    if (!ready || !shader[0] || !name || !data)
        return real_set(ctx, name, format, data);

    if (format == MPV_FORMAT_FLAG && !strcmp(name, "keepaspect")) {
        wanted_keep = *(int *)data != 0;
        apply(ctx);
        return 0;
    }

    int ret = real_set(ctx, name, format, data);
    if (format == MPV_FORMAT_DOUBLE && !strcmp(name, "panscan"))
        cropping = *(double *)data > 0.0;
    apply(ctx);
    return ret;
}
