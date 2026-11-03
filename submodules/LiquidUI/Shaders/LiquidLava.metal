#include <metal_stdlib>
using namespace metal;

struct LiquidLavaUniforms {
    float2 viewport;
    float scale;
    float time;
    float4 tint;
    float heat;
    float burst;
    float inner;
    float outer;
};

constant int lavaBlobCount = 11;

static float lavaHash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

static float3 lavaFire(float t) {
    float3 dark = float3(0.35, 0.03, 0.0);
    float3 red = float3(0.95, 0.22, 0.02);
    float3 orange = float3(1.0, 0.62, 0.12);
    float3 white = float3(1.0, 0.97, 0.85);
    if (t < 0.33) {
        return mix(dark, red, t / 0.33);
    }
    if (t < 0.7) {
        return mix(red, orange, (t - 0.33) / 0.37);
    }

    return mix(orange, white, (t - 0.7) / 0.3);
}

static float3 lavaSky(float3 r, float3 tint) {
    float horizon = smoothstep(-0.35, 0.55, -r.y);
    float3 low = tint * 0.18;
    float3 high = mix(tint, float3(1.0), 0.55);
    float band = exp(-pow((-r.y - 0.15) * 7.0, 2.0)) * 0.6;

    return mix(low, high, horizon) + band * mix(tint, float3(1.0), 0.7);
}

vertex float4 liquid_lava_vertex(uint vid [[vertex_id]]) {
    float2 position = float2((vid << 1) & 2, vid & 2);

    return float4(position * 2.0 - 1.0, 0.0, 1.0);
}

fragment float4 liquid_lava_fragment(
    float4 position [[position]],
    constant LiquidLavaUniforms &u [[buffer(0)]]
) {
    float2 size = u.viewport / u.scale;
    float2 p = position.xy / u.scale;
    float2 center = size * 0.5;
    float band = max(u.outer - u.inner, 1.0);
    float speed = 0.55 + u.heat * 1.6;

    float field = 0.0;
    float2 gradient = float2(0.0);
    for (int i = 0; i < lavaBlobCount; i++) {
        float n = float(i);
        float phase = lavaHash(n + 1.0) * 6.2831;
        float direction = lavaHash(n + 7.0) > 0.5 ? 1.0 : -1.0;
        float angle = phase + u.time * speed * (0.25 + lavaHash(n + 3.0) * 0.45) * direction;
        float wobble = 0.5 + 0.5 * sin(u.time * speed * (0.8 + lavaHash(n + 5.0)) + phase * 2.0);
        float distance = u.inner + band * (0.25 + 0.5 * wobble) + u.burst * band * (0.6 + lavaHash(n + 9.0));
        float2 c = center + float2(cos(angle), sin(angle)) * distance;
        float radius = band * (0.26 + 0.16 * lavaHash(n + 11.0)) * (1.0 + u.heat * 0.25);
        float2 d = p - c;
        float q = max(dot(d, d), 1.0);
        float r2 = radius * radius;
        field += r2 / q;
        gradient += -2.0 * r2 * d / (q * q);
    }

    float ringDistance = length(p - center) - (u.inner + band * 0.5);
    float ring = 0.55 * exp(-pow(ringDistance / (band * 0.32), 2.0)) * (1.0 - u.burst * 0.7);
    field += ring;
    gradient += -ring * 2.0 * ringDistance / pow(band * 0.32, 2.0) * normalize(p - center + 0.0001);

    float aa = max(fwidth(field), 0.0001) * 1.2;
    float coverage = smoothstep(1.0 - aa, 1.0 + aa, field);
    if (coverage <= 0.0) {
        return float4(0.0);
    }

    float3 normal = normalize(float3(-gradient * band * 0.55, 1.0));
    float3 view = float3(0.0, 0.0, 1.0);
    float3 reflected = reflect(-view, normal);
    float3 tint = u.tint.rgb;
    float3 metal = lavaSky(reflected, tint);
    float3 light = normalize(float3(-0.45, -0.7, 0.6));
    float specular = pow(saturate(dot(reflect(-light, normal), view)), 48.0);
    float fresnel = pow(1.0 - saturate(normal.z), 2.0);
    metal += specular * 1.2 + fresnel * tint * 0.35;

    float depth = saturate((field - 1.0) * 0.45);
    float flicker = 0.85 + 0.15 * sin(u.time * 9.0 + p.x * 0.08 + p.y * 0.05);
    float3 fire = lavaFire(saturate(u.heat * (0.45 + depth * 0.7) * flicker));
    float molten = smoothstep(0.05, 0.7, u.heat);
    float3 color = mix(metal, fire + specular * 0.6, molten * (0.55 + 0.45 * depth));
    float alpha = coverage * u.tint.a;

    return float4(color * alpha, alpha);
}
