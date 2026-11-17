// ambient-fill.glsl — remplit les bandes noires latérales par un prolongement flouté de l'image.
//
// Principe : avec keepaspect=no, mpv étire la vidéo sur toute la fenêtre. Ce
// shader intervient avant la mise à l'échelle et agrandit la texture au ratio
// de la fenêtre : l'image d'origine est recopiée au centre, pixel pour pixel,
// et les marges reçoivent un miroir flouté et assombri de ses bords. L'étirement
// de mpv devient alors une simple mise à l'échelle uniforme, sans déformation.
// Pour une source plus haute que la fenêtre (4K sur 1440p), le shader réduit
// lui-même l'image à la taille de la fenêtre.
//
// Quand la fenêtre est plus étroite que la vidéo (bandes en haut et en bas),
// la dernière passe complète simplement avec du noir, comme le fait mpv.
//
// Réglages : les #define de la passe « composite » (luminosité, saturation).

//!HOOK MAIN
//!BIND HOOKED
//!SAVE AMB_D1
//!DESC ambient fill: 1/4
//!WIDTH HOOKED.w 4 /
//!HEIGHT HOOKED.h 4 /
//!WHEN OUTPUT.w OUTPUT.h / NATIVE_CROPPED.w NATIVE_CROPPED.h / / 1.005 >

vec4 hook()
{
    vec2 d = HOOKED_pt;
    return 0.25 * (HOOKED_tex(HOOKED_pos + d * vec2(-1.0, -1.0)) +
                   HOOKED_tex(HOOKED_pos + d * vec2( 1.0, -1.0)) +
                   HOOKED_tex(HOOKED_pos + d * vec2(-1.0,  1.0)) +
                   HOOKED_tex(HOOKED_pos + d * vec2( 1.0,  1.0)));
}

//!HOOK MAIN
//!BIND AMB_D1
//!SAVE AMB_D2
//!DESC ambient fill: 1/16
//!WIDTH AMB_D1.w 4 /
//!HEIGHT AMB_D1.h 4 /
//!WHEN OUTPUT.w OUTPUT.h / NATIVE_CROPPED.w NATIVE_CROPPED.h / / 1.005 >

vec4 hook()
{
    vec2 d = AMB_D1_pt;
    return 0.25 * (AMB_D1_tex(AMB_D1_pos + d * vec2(-1.0, -1.0)) +
                   AMB_D1_tex(AMB_D1_pos + d * vec2( 1.0, -1.0)) +
                   AMB_D1_tex(AMB_D1_pos + d * vec2(-1.0,  1.0)) +
                   AMB_D1_tex(AMB_D1_pos + d * vec2( 1.0,  1.0)));
}

//!HOOK MAIN
//!BIND AMB_D2
//!SAVE AMB_H2
//!DESC ambient fill: blur near (h)
//!WIDTH AMB_D2.w
//!HEIGHT AMB_D2.h
//!WHEN OUTPUT.w OUTPUT.h / NATIVE_CROPPED.w NATIVE_CROPPED.h / / 1.005 >

#define SIGMA 2.0
#define RADIUS 5

vec4 hook()
{
    vec4 acc = vec4(0.0);
    float sum = 0.0;
    for (int i = -RADIUS; i <= RADIUS; i++) {
        float w = exp(-0.5 * float(i * i) / (SIGMA * SIGMA));
        acc += w * AMB_D2_tex(AMB_D2_pos + vec2(float(i), 0.0) * AMB_D2_pt);
        sum += w;
    }
    return acc / sum;
}

//!HOOK MAIN
//!BIND AMB_H2
//!SAVE AMB_NEAR
//!DESC ambient fill: blur near (v)
//!WIDTH AMB_H2.w
//!HEIGHT AMB_H2.h
//!WHEN OUTPUT.w OUTPUT.h / NATIVE_CROPPED.w NATIVE_CROPPED.h / / 1.005 >

#define SIGMA 2.0
#define RADIUS 5

vec4 hook()
{
    vec4 acc = vec4(0.0);
    float sum = 0.0;
    for (int i = -RADIUS; i <= RADIUS; i++) {
        float w = exp(-0.5 * float(i * i) / (SIGMA * SIGMA));
        acc += w * AMB_H2_tex(AMB_H2_pos + vec2(0.0, float(i)) * AMB_H2_pt);
        sum += w;
    }
    return acc / sum;
}

//!HOOK MAIN
//!BIND AMB_NEAR
//!SAVE AMB_D3
//!DESC ambient fill: 1/64
//!WIDTH AMB_NEAR.w 4 /
//!HEIGHT AMB_NEAR.h 4 /
//!WHEN OUTPUT.w OUTPUT.h / NATIVE_CROPPED.w NATIVE_CROPPED.h / / 1.005 >

vec4 hook()
{
    vec2 d = AMB_NEAR_pt;
    return 0.25 * (AMB_NEAR_tex(AMB_NEAR_pos + d * vec2(-1.0, -1.0)) +
                   AMB_NEAR_tex(AMB_NEAR_pos + d * vec2( 1.0, -1.0)) +
                   AMB_NEAR_tex(AMB_NEAR_pos + d * vec2(-1.0,  1.0)) +
                   AMB_NEAR_tex(AMB_NEAR_pos + d * vec2( 1.0,  1.0)));
}

//!HOOK MAIN
//!BIND AMB_D3
//!SAVE AMB_H3
//!DESC ambient fill: blur far (h)
//!WIDTH AMB_D3.w
//!HEIGHT AMB_D3.h
//!WHEN OUTPUT.w OUTPUT.h / NATIVE_CROPPED.w NATIVE_CROPPED.h / / 1.005 >

#define SIGMA 1.5
#define RADIUS 4

vec4 hook()
{
    vec4 acc = vec4(0.0);
    float sum = 0.0;
    for (int i = -RADIUS; i <= RADIUS; i++) {
        float w = exp(-0.5 * float(i * i) / (SIGMA * SIGMA));
        acc += w * AMB_D3_tex(AMB_D3_pos + vec2(float(i), 0.0) * AMB_D3_pt);
        sum += w;
    }
    return acc / sum;
}

//!HOOK MAIN
//!BIND AMB_H3
//!SAVE AMB_FAR
//!DESC ambient fill: blur far (v)
//!WIDTH AMB_H3.w
//!HEIGHT AMB_H3.h
//!WHEN OUTPUT.w OUTPUT.h / NATIVE_CROPPED.w NATIVE_CROPPED.h / / 1.005 >

#define SIGMA 1.5
#define RADIUS 4

vec4 hook()
{
    vec4 acc = vec4(0.0);
    float sum = 0.0;
    for (int i = -RADIUS; i <= RADIUS; i++) {
        float w = exp(-0.5 * float(i * i) / (SIGMA * SIGMA));
        acc += w * AMB_H3_tex(AMB_H3_pos + vec2(0.0, float(i)) * AMB_H3_pt);
        sum += w;
    }
    return acc / sum;
}

//!HOOK MAIN
//!BIND HOOKED
//!BIND AMB_NEAR
//!BIND AMB_FAR
//!DESC ambient fill: composite
//!WIDTH OUTPUT.w NATIVE_CROPPED.h OUTPUT.h > * NATIVE_CROPPED.h OUTPUT.w * OUTPUT.h / NATIVE_CROPPED.h OUTPUT.h > ! * +
//!HEIGHT OUTPUT.h NATIVE_CROPPED.h OUTPUT.h > * HOOKED.h NATIVE_CROPPED.h OUTPUT.h > ! * +
//!WHEN OUTPUT.w OUTPUT.h / NATIVE_CROPPED.w NATIVE_CROPPED.h / / 1.005 >

// Luminosité du remplissage contre l'image, puis au bord de l'écran (1.0 = identique à l'image).
#define GAIN_NEAR 0.80
#define GAIN_FAR 0.45
// Saturation du remplissage (1.0 = inchangée, 0.0 = gris).
#define SATURATION 1.0

vec4 hook()
{
    vec2 vs = HOOKED_size;
    // Taille de cette passe (mêmes formules que WIDTH/HEIGHT ci-dessus) et
    // largeur qu'y occupe l'image. Source plus haute que la fenêtre : on
    // travaille directement à la taille de la fenêtre, sinon le coût double.
    bool reduce = input_size.y > target_size.y;
    vec2 os = reduce ? target_size
                     : vec2(floor(input_size.y * target_size.x / target_size.y + 0.5), vs.y);
    float vw = reduce ? floor(os.y * input_size.x / input_size.y + 0.5) : vs.x;
    float off = floor((os.x - vw) * 0.5);
    float u = (HOOKED_pos.x * os.x - off) / vw;

    if (u >= 0.0 && u <= 1.0) {
        vec2 uv = vec2(u, HOOKED_pos.y);
        if (!reduce)
            return HOOKED_tex(uv);
        // Réduction par moyenne de surface : n x n prises bilinéaires.
        vec2 ratio = vs / vec2(vw, os.y);
        int n = max(ratio.x, ratio.y) > 2.0 ? 4 : 2;
        vec2 delta = ratio * HOOKED_pt / float(n);
        vec4 sum = vec4(0.0);
        for (int j = 0; j < n; j++)
            for (int i = 0; i < n; i++)
                sum += HOOKED_tex(uv + (vec2(float(i), float(j)) - 0.5 * float(n - 1)) * delta);
        return sum / float(n * n);
    }

    // Distance au bord de l'image, de 0 (contre l'image) à 1 (bord de l'écran).
    float t = clamp(max(-u, u - 1.0) * vw / max(off, 1.0), 0.0, 1.0);

    // Répétition en miroir : continuité exacte des couleurs au bord de l'image.
    float m = mod(u, 2.0);
    vec2 pos = vec2(m > 1.0 ? 2.0 - m : m, HOOKED_pos.y);

    vec4 c = mix(AMB_NEAR_tex(pos), AMB_FAR_tex(pos), smoothstep(0.0, 0.6, t));
    float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    c.rgb = mix(vec3(luma), c.rgb, SATURATION);
    c.rgb *= mix(GAIN_NEAR, GAIN_FAR, smoothstep(0.0, 1.0, t));
    c.a = 1.0;
    return c;
}

//!HOOK MAIN
//!BIND HOOKED
//!DESC ambient fill: bandes haut/bas noires
//!WIDTH HOOKED.w
//!HEIGHT NATIVE_CROPPED.w OUTPUT.h * OUTPUT.w /
//!WHEN OUTPUT.w OUTPUT.h / NATIVE_CROPPED.w NATIVE_CROPPED.h / / 0.995 <

vec4 hook()
{
    vec2 vs = HOOKED_size;
    float h = floor(input_size.x * target_size.y / target_size.x + 0.5);
    float off = floor((h - vs.y) * 0.5);
    float v = (HOOKED_pos.y * h - off) / vs.y;

    if (v < 0.0 || v > 1.0)
        return vec4(0.0, 0.0, 0.0, 1.0);
    return HOOKED_tex(vec2(HOOKED_pos.x, v));
}
