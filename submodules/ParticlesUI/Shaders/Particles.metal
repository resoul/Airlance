#include <metal_stdlib>
using namespace metal;

struct Particle {
    float4 motion;
    float4 color;
    float4 state;
};

struct ParticleTarget {
    float4 place;
    float4 color;
    float4 release;
};

struct ParticleUniforms {
    float4 viewport;
    float4 touch;
    float4 effect;
    float4 frame;
};

constant uint releaseDust = 0;
constant uint releaseBlackHole = 1;
constant uint releaseHome = 2;
constant uint releaseBurst = 3;

constant float2 particleCorners[4] = { float2(0, 0), float2(1, 0), float2(0, 1), float2(1, 1) };

static float2 particleWobble(float time, float seed) {
    return float2(sin(time * 1.7 + seed * 41.0), cos(time * 1.3 + seed * 23.0));
}

static float2 particleSettle(float2 position, float2 velocity, ParticleTarget target, constant ParticleUniforms &u) {
    float stiffness = 70.0 * target.place.w;
    float damping = 2.0 * sqrt(stiffness) * 0.62;
    float2 force = (target.place.xy - position) * stiffness - velocity * damping;
    force += particleWobble(u.frame.z, target.release.y * 97.0 + position.x * 0.01) * 5.0;
    if (u.touch.z > 0.0) {
        float2 away = position - u.touch.xy;
        float distance = max(length(away), 0.001);
        float push = saturate(1.0 - distance / u.touch.w);
        force += away / distance * push * push * 5200.0;
    }
    return force;
}

static float4 particleRelease(thread float2 &position,
                              thread float2 &velocity,
                              float age,
                              float seed,
                              ParticleTarget target,
                              constant ParticleUniforms &u) {
    float dt = u.frame.x;
    uint style = uint(u.effect.z);
    float fade = 1.0;
    if (style == releaseBlackHole) {
        float2 toCenter = u.effect.xy - position;
        float distance = max(length(toCenter), 0.001);
        float2 inward = toCenter / distance;
        float2 around = float2(-inward.y, inward.x);
        velocity += (inward * (260.0 + 2600.0 * age) + around * 900.0 / (1.0 + distance * 0.02)) * dt;
        velocity *= max(1.0 - 2.2 * dt, 0.0);
        fade = saturate((distance - 3.0) / 22.0);
    } else if (style == releaseBurst) {
        float2 fromCenter = position - u.effect.xy;
        float distance = max(length(fromCenter), 0.001);
        float2 outward = fromCenter / distance;
        float2 spin = float2(-outward.y, outward.x) * (seed - 0.5);
        float kick = exp(-age * 7.0) * (2400.0 + 2600.0 * seed);
        velocity += ((outward + spin) * kick + particleWobble(age * 3.0, seed) * 90.0) * dt;
        velocity *= max(1.0 - 1.6 * dt, 0.0);
        fade = saturate(1.0 - age / (0.55 + seed * 0.45));
    } else if (style == releaseHome) {
        float2 toHome = target.release.zw - position;
        float distance = length(toHome);
        velocity += (toHome * 55.0 - velocity * 9.0) * dt;
        fade = age < 0.15 ? 1.0 : saturate(distance / 26.0);
    } else {
        float2 eddy = particleWobble(age * 4.0, seed) * 160.0;
        velocity += (float2(170.0, -70.0) * (0.6 + seed) + eddy) * dt;
        velocity *= max(1.0 - 0.9 * dt, 0.0);
        fade = saturate(1.0 - age / (0.7 + seed * 0.7));
    }
    position += velocity * dt;
    return float4(fade);
}

kernel void particles_update(device Particle *particles [[buffer(0)]],
                             const device ParticleTarget *targets [[buffer(1)]],
                             constant ParticleUniforms &u [[buffer(2)]],
                             uint id [[thread_position_in_grid]]) {
    if (id >= uint(u.frame.y)) {
        return;
    }
    Particle p = particles[id];
    ParticleTarget target = targets[id];
    float dt = u.frame.x;
    float2 position = p.motion.xy;
    float2 velocity = p.motion.zw;
    float blend = min(1.0, dt * 6.0);
    if (target.release.x < 0.0 || u.frame.z < target.release.x) {
        float2 force = particleSettle(position, velocity, target, u);
        velocity += force * dt;
        position += velocity * dt;
        p.color = mix(p.color, target.color, blend);
        p.state.x = mix(p.state.x, target.place.z, blend);
    } else {
        float age = u.frame.z - target.release.x;
        float4 fade = particleRelease(position, velocity, age, p.state.z, target, u);
        p.color.a = min(p.color.a, fade.x * target.color.a);
    }
    p.motion = float4(position, velocity);
    particles[id] = p;
}

struct ParticleOut {
    float4 position [[position]];
    float2 local;
    float4 color;
};

vertex ParticleOut particles_vertex(uint vid [[vertex_id]],
                                    uint iid [[instance_id]],
                                    const device Particle *particles [[buffer(0)]],
                                    constant ParticleUniforms &u [[buffer(1)]]) {
    Particle p = particles[iid];
    ParticleOut out;
    out.local = particleCorners[vid] * 2.0 - 1.0;
    out.color = p.color;
    if (p.color.a < 0.004) {
        out.position = float4(-2.0, -2.0, 0.0, 1.0);
        return out;
    }
    float size = p.state.x * 1.8;
    float2 point = p.motion.xy + out.local * size * 0.5;
    float2 ndc = point * u.viewport.z / u.viewport.xy * 2.0 - 1.0;
    out.position = float4(ndc.x, -ndc.y, 0.0, 1.0);
    return out;
}

fragment float4 particles_fragment(ParticleOut in [[stage_in]],
                                   constant ParticleUniforms &u [[buffer(0)]]) {
    float distance = length(in.local);
    float core = 1.0 - smoothstep(0.35, 0.6, distance);
    float glow = pow(saturate(1.0 - distance), 2.0) * 0.45;
    float alpha = saturate(core + glow) * in.color.a * u.frame.w;
    return float4(in.color.rgb * alpha, alpha);
}
