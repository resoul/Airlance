#include <metal_stdlib>
using namespace metal;

struct ThemeRevealOut {
    float4 position [[position]];
};

struct ThemeRevealUniforms {
    float2 viewport;
    float scale;
    float radius;
    float2 origin;
    float time;
    float seed;
};

constexpr sampler revealSampler(coord::normalized, address::clamp_to_edge, filter::linear);

static float revealHash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float revealNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 w = f * f * (3.0 - 2.0 * f);
    return mix(mix(revealHash(i), revealHash(i + float2(1, 0)), w.x),
               mix(revealHash(i + float2(0, 1)), revealHash(i + float2(1, 1)), w.x), w.y);
}

static float revealFbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; ++i) {
        value += amplitude * revealNoise(p);
        p = p * 2.03 + 11.7;
        amplitude *= 0.5;
    }
    return value;
}

static float revealSmin(float a, float b, float k) {
    float h = saturate(0.5 + 0.5 * (b - a) / k);
    return mix(b, a, h) - k * h * (1.0 - h);
}

vertex ThemeRevealOut theme_reveal_vertex(uint vid [[vertex_id]]) {
    float2 pos = float2((vid << 1) & 2, vid & 2);
    ThemeRevealOut out;
    out.position = float4(pos * 2.0 - 1.0, 0.0, 1.0);
    return out;
}

fragment float4 theme_reveal_fragment(ThemeRevealOut in [[stage_in]],
                                      texture2d<float> oldScreen [[texture(0)]],
                                      constant ThemeRevealUniforms &u [[buffer(0)]]) {
    float2 size = u.viewport / u.scale;
    float2 p = in.position.xy / u.scale;
    float2 v = p - u.origin;
    float dist = length(v);
    float angle = atan2(v.y, v.x);
    float wobble = (revealFbm(float2(angle * 2.4 + u.seed, u.time * 0.9)) - 0.5) * (22.0 + u.radius * 0.07);
    float edge = dist - (u.radius + wobble);
    for (int k = 0; k < 12; ++k) {
        float h1 = revealHash(float2(float(k), u.seed));
        float h2 = revealHash(float2(u.seed, float(k) * 1.7));
        float a = h1 * 6.2831;
        float ahead = 18.0 + 40.0 * h2;
        float2 c = u.origin + float2(cos(a), sin(a)) * (u.radius + ahead);
        float r = (4.0 + 11.0 * h2) * smoothstep(0.0, 60.0, u.radius);
        edge = revealSmin(edge, length(p - c) - r, 12.0);
    }
    float pixel = 1.0 / u.scale;
    float alpha = smoothstep(-pixel, pixel, edge);
    if (alpha <= 0.0) {
        return float4(0.0);
    }
    float2 outward = dist > 0.001 ? v / dist : float2(0.0);
    float rim = exp(-max(edge, 0.0) / 6.0);
    float2 uv = (p - outward * rim * 7.0) / size;
    float4 color = oldScreen.sample(revealSampler, uv);
    color.rgb = color.rgb * (1.0 - 0.18 * exp(-(edge - 10.0) * (edge - 10.0) / 40.0)) + rim * 0.22;
    return float4(saturate(color.rgb) * alpha, alpha);
}
