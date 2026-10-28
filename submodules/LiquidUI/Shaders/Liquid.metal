#include <metal_stdlib>
using namespace metal;

struct LiquidUniforms {
    float scale;
    float gloss;
    float rimWidth;
    float unused;
    float4 color;
    float4 bounds;
    uint blobCount;
    uint bridgeCount;
};

struct LiquidBlob {
    float4 box;
    float4 params;
};

struct LiquidBridge {
    float4 segment;
    float4 params;
};

struct LiquidVertexOut {
    float4 position [[position]];
};

static float liquidRoundedBox(float2 p, float2 halfSize, float radius) {
    float2 q = abs(p) - halfSize + radius;

    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

static float liquidSmoothMin(float a, float b, float k) {
    if (k <= 0.0) {
        return min(a, b);
    }

    float h = saturate(0.5 + 0.5 * (b - a) / k);

    return mix(b, a, h) - k * h * (1.0 - h);
}

static float liquidTaperedCapsule(float2 p, float2 a, float2 b, float ra, float rb) {
    float2 axis = b - a;
    float h = length(axis);
    if (h < 1e-3) {
        return length(p - a) - ra;
    }

    float2 direction = axis / h;
    float2 q = float2(abs(dot(p - a, float2(-direction.y, direction.x))), dot(p - a, direction));
    float slope = clamp((ra - rb) / h, -0.999, 0.999);
    float c = sqrt(1.0 - slope * slope);
    float k = dot(q, float2(-slope, c));
    if (k < 0.0) {
        return length(q) - ra;
    }
    if (k > c * h) {
        return length(q - float2(0.0, h)) - rb;
    }

    return dot(q, float2(c, slope)) - ra;
}

static float liquidField(
    float2 p,
    constant LiquidUniforms &u,
    constant LiquidBlob *blobs,
    constant LiquidBridge *bridges
) {
    float d = 1e5;
    for (uint i = 0; i < u.blobCount; ++i) {
        LiquidBlob blob = blobs[i];
        float radius = min(blob.params.x, min(blob.box.z, blob.box.w));
        d = liquidSmoothMin(d, liquidRoundedBox(p - blob.box.xy, blob.box.zw, radius), blob.params.y);
    }
    for (uint i = 0; i < u.bridgeCount; ++i) {
        LiquidBridge bridge = bridges[i];
        float shape = liquidTaperedCapsule(p, bridge.segment.xy, bridge.segment.zw, bridge.params.x, bridge.params.y);
        d = liquidSmoothMin(d, shape, bridge.params.z);
    }

    return d;
}

static float3 liquidReflection(float3 r) {
    float3 key = normalize(float3(-0.45, -0.75, 0.55));
    float3 fill = normalize(float3(0.75, 0.35, 0.55));
    float keyLight = smoothstep(0.86, 0.93, dot(r, key));
    float fillLight = smoothstep(0.93, 0.97, dot(r, fill)) * 0.5;
    float ceiling = pow(saturate(-r.y * 0.5 + 0.5), 4.0) * 0.1;

    return float3(1.0) * (keyLight + fillLight + ceiling);
}

vertex LiquidVertexOut liquid_vertex(uint vid [[vertex_id]]) {
    float2 position = float2((vid << 1) & 2, vid & 2);
    LiquidVertexOut out;
    out.position = float4(position * 2.0 - 1.0, 0.0, 1.0);

    return out;
}

fragment float4 liquid_fragment(
    LiquidVertexOut in [[stage_in]],
    constant LiquidUniforms &u [[buffer(0)]],
    constant LiquidBlob *blobs [[buffer(1)]],
    constant LiquidBridge *bridges [[buffer(2)]]
) {
    float2 p = in.position.xy / u.scale;
    if (any(p < u.bounds.xy) || any(p > u.bounds.zw)) {
        return float4(0.0);
    }

    float d = liquidField(p, u, blobs, bridges);
    float pixel = 1.0 / u.scale;
    if (d > 2.0 * pixel) {
        return float4(0.0);
    }

    const float e = 0.35;
    float2 gradient = float2(
        liquidField(p + float2(e, 0.0), u, blobs, bridges) - liquidField(p - float2(e, 0.0), u, blobs, bridges),
        liquidField(p + float2(0.0, e), u, blobs, bridges) - liquidField(p - float2(0.0, e), u, blobs, bridges)
    ) / (2.0 * e);
    float slope = max(length(gradient), 0.05);
    float distance = d / slope;
    float alpha = (1.0 - smoothstep(-0.75 * pixel, 0.75 * pixel, distance)) * u.color.a;
    if (alpha <= 0.0) {
        return float4(0.0);
    }

    float s = saturate(-distance / u.rimWidth);
    float height = sqrt(max(2.0 * s - s * s, 1e-4));
    float2 outward = gradient / slope;
    float3 normal = normalize(float3(outward * (1.0 - s) / height, 1.0));
    float3 reflected = float3(2.0 * normal.z * normal.xy, 2.0 * normal.z * normal.z - 1.0);
    float fresnel = 0.04 + 0.96 * pow(1.0 - normal.z, 5.0);
    float3 color = u.color.rgb + liquidReflection(reflected) * (0.35 + 0.65 * fresnel) * u.gloss;

    return float4(saturate(color) * alpha, alpha);
}
