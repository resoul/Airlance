#include <metal_stdlib>
using namespace metal;

struct SpoilerOut {
    float4 position [[position]];
};

struct SpoilerUniforms {
    float2 viewport;
    float scale;
    float time;
    uint rectCount;
    float seed;
    uint stampCount;
    float unused;
    float4 reveal;
    float4 ink;
};

static float spoilerHash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float spoilerNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 w = f * f * (3.0 - 2.0 * f);
    return mix(mix(spoilerHash(i), spoilerHash(i + float2(1, 0)), w.x),
               mix(spoilerHash(i + float2(0, 1)), spoilerHash(i + float2(1, 1)), w.x), w.y);
}

static float spoilerFbm(float2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; ++i) {
        v += a * spoilerNoise(p);
        p = p * 2.03 + 11.7;
        a *= 0.5;
    }
    return v;
}

static float spoilerBox(float2 p, float2 halfSize, float radius) {
    float2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

vertex SpoilerOut spoiler_vertex(uint vid [[vertex_id]]) {
    float2 pos = float2((vid << 1) & 2, vid & 2);
    SpoilerOut out;
    out.position = float4(pos * 2.0 - 1.0, 0.0, 1.0);
    return out;
}

fragment float4 spoiler_fragment(SpoilerOut in [[stage_in]],
                                 constant SpoilerUniforms &u [[buffer(0)]],
                                 constant float4 *rects [[buffer(1)]],
                                 constant float4 *stamps [[buffer(2)]]) {
    float2 p = in.position.xy / u.scale;
    float d = 1e5;
    for (uint i = 0; i < u.rectCount; ++i) {
        float2 halfSize = rects[i].zw * 0.5 + float2(2.0, 1.0);
        d = min(d, spoilerBox(p - rects[i].xy - rects[i].zw * 0.5, halfSize, 5.0));
    }
    float edgeNoise = (spoilerFbm(p * 0.18 + float2(u.time * 0.4, u.seed)) - 0.5) * 3.0;
    float ink = 1.0 - smoothstep(-1.0, 1.0, d + edgeNoise);
    if (ink <= 0.0) {
        return float4(0.0);
    }

    float holeNoise = (spoilerFbm(p * 0.12 + u.seed * 3.0) - 0.5) * 10.0;
    float erased = 0.0;
    for (uint i = 0; i < u.stampCount; ++i) {
        float r = stamps[i].z;
        erased = max(erased, 1.0 - smoothstep(r - 5.0, r + 1.0, length(p - stamps[i].xy) + holeNoise));
    }
    float radius = u.reveal.z;
    if (radius > 0.0) {
        erased = max(erased, 1.0 - smoothstep(radius - 10.0, radius + 1.0, length(p - u.reveal.xy) + holeNoise * 1.6));
    }
    float alpha = ink * (1.0 - erased);
    if (alpha <= 0.001) {
        return float4(0.0);
    }

    float2 flow = p * 0.06 + float2(spoilerFbm(p * 0.05 + u.time * 0.15), spoilerFbm(p * 0.05 - u.time * 0.12)) * 2.0;
    float churn = spoilerFbm(flow + u.seed);
    float3 color = u.ink.rgb * (0.75 + 0.6 * churn);
    float3 sheen = 0.5 + 0.5 * cos(6.2831 * (churn * 1.3 + float3(0.0, 0.33, 0.67)) + u.time * 0.6);
    color += sheen * 0.10 * smoothstep(0.45, 0.75, churn);

    float2 q = p + float2(u.time * 5.0, sin(u.time * 0.7 + p.x * 0.05) * 3.0);
    float2 cell = floor(q / 3.2);
    float h = spoilerHash(cell + u.seed);
    float2 dotPos = (cell + 0.25 + 0.5 * float2(spoilerHash(cell + 1.7), spoilerHash(cell + 4.1))) * 3.2;
    float twinkle = smoothstep(0.78, 1.0, h) * (0.5 + 0.5 * sin(u.time * 4.0 + h * 50.0));
    color += exp(-dot(q - dotPos, q - dotPos) * 1.6) * twinkle * 0.9;

    float pool = smoothstep(0.0, 0.5, erased) * (1.0 - smoothstep(0.5, 1.0, erased));
    color = mix(color, u.ink.rgb * 0.45, pool * 0.8);

    return float4(saturate(color) * alpha, alpha);
}
