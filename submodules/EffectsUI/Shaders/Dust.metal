#include <metal_stdlib>
using namespace metal;

struct DustGrain {
    float2 position;
    float2 velocity;
    float4 color;
    float release;
    float seed;
    float alive;
    float life;
};

struct DustUniforms {
    float2 viewport;
    float scale;
    float time;
    float4 element;
    float grain;
    uint columns;
    uint rows;
    float releaseWindow;
    float2 wind;
    float gravity;
    float dt;
};

constant float2 dustCorners[4] = { float2(0, 0), float2(1, 0), float2(0, 1), float2(1, 1) };
constexpr sampler dustSampler(coord::normalized, address::clamp_to_edge, filter::linear);

static float dustHash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float2 dustToClip(float2 pt, float2 viewport, float scale) {
    float2 ndc = pt * scale / viewport * 2.0 - 1.0;
    return float2(ndc.x, -ndc.y);
}

static float dustRelease(uint2 cell, constant DustUniforms &u) {
    float x = (float(cell.x) + 0.5) / float(u.columns);
    return (x * 0.75 + dustHash(float2(cell) * 1.37) * 0.25) * u.releaseWindow;
}

kernel void dust_spawn(device DustGrain *grains [[buffer(0)]],
                       constant DustUniforms &u [[buffer(1)]],
                       texture2d<float> snapshot [[texture(0)]],
                       uint id [[thread_position_in_grid]]) {
    if (id >= u.columns * u.rows) {
        return;
    }
    uint2 cell = uint2(id % u.columns, id / u.columns);
    float2 uv = (float2(cell) + 0.5) * u.grain / u.element.zw;
    DustGrain g;
    g.position = u.element.xy + (float2(cell) + 0.5) * u.grain;
    g.velocity = float2(0.0);
    g.color = snapshot.sample(dustSampler, uv, level(0.0));
    g.release = dustRelease(cell, u);
    g.seed = dustHash(float2(cell) + 17.0);
    g.alive = g.color.a > 0.02 ? 1.0 : 0.0;
    g.life = 0.55 + dustHash(float2(cell) + 3.1) * 0.6;
    grains[id] = g;
}

kernel void dust_update(device DustGrain *grains [[buffer(0)]],
                        constant DustUniforms &u [[buffer(1)]],
                        uint id [[thread_position_in_grid]]) {
    if (id >= u.columns * u.rows) {
        return;
    }
    DustGrain g = grains[id];
    if (g.alive == 0.0 || u.time < g.release) {
        return;
    }
    float age = u.time - g.release;
    if (all(g.velocity == 0.0)) {
        float angle = (g.seed - 0.5) * 2.4 - 1.2;
        g.velocity = u.wind * (0.4 + g.seed) + float2(cos(angle), sin(angle)) * (30.0 + 50.0 * g.seed);
    }
    float2 eddy = float2(sin(age * 7.0 + g.seed * 40.0), cos(age * 5.0 + g.seed * 31.0)) * 140.0;
    g.velocity += (eddy + float2(0.0, u.gravity)) * u.dt;
    g.velocity *= max(1.0 - 1.4 * u.dt, 0.0);
    g.position += g.velocity * u.dt;
    if (age > g.life) {
        g.alive = 0.0;
    }
    grains[id] = g;
}

struct DustGrainOut {
    float4 position [[position]];
    float2 local;
    float4 color;
};

vertex DustGrainOut dust_grain_vertex(uint vid [[vertex_id]],
                                      uint iid [[instance_id]],
                                      const device DustGrain *grains [[buffer(0)]],
                                      constant DustUniforms &u [[buffer(1)]]) {
    DustGrain g = grains[iid];
    DustGrainOut out;
    out.local = dustCorners[vid] * 2.0 - 1.0;
    if (g.alive == 0.0 || u.time < g.release) {
        out.position = float4(-2.0, -2.0, 0.0, 1.0);
        out.color = float4(0.0);
        return out;
    }
    float age = saturate((u.time - g.release) / g.life);
    float size = u.grain * mix(1.5, 0.6, age);
    float2 pt = g.position + out.local * size * 0.5;
    out.position = float4(dustToClip(pt, u.viewport, u.scale), 0.0, 1.0);
    out.color = g.color * (1.0 - age * age);
    return out;
}

fragment float4 dust_grain_fragment(DustGrainOut in [[stage_in]]) {
    float mask = 1.0 - smoothstep(0.5, 1.0, length(in.local));
    return in.color * mask;
}

struct DustElementOut {
    float4 position [[position]];
    float2 uv;
};

vertex DustElementOut dust_element_vertex(uint vid [[vertex_id]],
                                          constant DustUniforms &u [[buffer(0)]]) {
    DustElementOut out;
    out.uv = dustCorners[vid];
    float2 pt = u.element.xy + out.uv * u.element.zw;
    out.position = float4(dustToClip(pt, u.viewport, u.scale), 0.0, 1.0);
    return out;
}

fragment float4 dust_element_fragment(DustElementOut in [[stage_in]],
                                      texture2d<float> snapshot [[texture(0)]],
                                      constant DustUniforms &u [[buffer(0)]]) {
    uint2 cell = uint2(in.uv * u.element.zw / u.grain);
    if (cell.x >= u.columns || cell.y >= u.rows || u.time >= dustRelease(cell, u)) {
        return float4(0.0);
    }
    return snapshot.sample(dustSampler, in.uv, level(0.0));
}
