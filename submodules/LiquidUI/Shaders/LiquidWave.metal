#include <metal_stdlib>
using namespace metal;

struct LiquidWaveUniforms {
    float2 viewport;
    float scale;
    float progress;
    float4 played;
    float4 rest;
    float time;
    float playing;
    float count;
    float unused;
};

static float waveSmoothMin(float a, float b, float k) {
    float h = saturate(0.5 + 0.5 * (b - a) / k);

    return mix(b, a, h) - k * h * (1.0 - h);
}

static float waveAmplitude(constant float *amplitudes, float count, float x) {
    float f = clamp(x, 0.0, 1.0) * (count - 1.0);
    int i = int(floor(f));
    float t = f - float(i);
    int last = int(count) - 1;
    float a = amplitudes[max(i - 1, 0)];
    float b = amplitudes[i];
    float c = amplitudes[min(i + 1, last)];
    float d = amplitudes[min(i + 2, last)];

    return 0.5 * (2.0 * b + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t
        + (-a + 3.0 * b - 3.0 * c + d) * t * t * t);
}

vertex float4 liquid_wave_vertex(uint vid [[vertex_id]]) {
    float2 position = float2((vid << 1) & 2, vid & 2);

    return float4(position * 2.0 - 1.0, 0.0, 1.0);
}

fragment float4 liquid_wave_fragment(
    float4 position [[position]],
    constant LiquidWaveUniforms &u [[buffer(0)]],
    constant float *amplitudes [[buffer(1)]]
) {
    float2 size = u.viewport / u.scale;
    float2 p = position.xy / u.scale;
    const float margin = 4.0;
    float x = (p.x - margin) / (size.x - margin * 2.0);
    float mid = size.y * 0.5;
    float head = margin + u.progress * (size.x - margin * 2.0);

    float amplitude = max(waveAmplitude(amplitudes, u.count, x), 0.12);
    float near = exp(-pow((p.x - head) / 16.0, 2.0)) * u.playing;
    float ripple = sin((p.x - head) * 0.55 - u.time * 14.0) * exp(-abs(p.x - head) / 26.0) * u.playing;
    float halfHeight = max(amplitude * (size.y * 0.42) * (1.0 + near * 0.35) + ripple * 1.6, 1.4);
    float band = abs(p.y - mid) - halfHeight;
    band = max(band, max(margin - p.x, p.x - (size.x - margin)));
    float dropRadius = (3.5 + 1.2 * sin(u.time * 9.0)) * u.playing;
    float drop = length(p - float2(head, mid - halfHeight * 0.2)) - dropRadius;
    float d = u.playing > 0.01 ? waveSmoothMin(band, drop, 6.0) : band;

    float coverage = saturate(0.5 - d * u.scale / 1.5);
    if (coverage <= 0.0) {
        return float4(0.0);
    }

    float playedMix = smoothstep(head + 1.5, head - 1.5, p.x);
    float3 color = mix(u.rest.rgb, u.played.rgb, playedMix);
    float alpha = mix(u.rest.a, u.played.a, playedMix);
    float rim = exp(-pow((d + 1.4) / 1.2, 2.0)) * step(p.y, mid);
    color = mix(color, float3(1.0), rim * 0.35);
    float a = coverage * alpha;

    return float4(color * a, a);
}
