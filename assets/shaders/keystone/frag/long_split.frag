#version 450

// Circular fillets adapted from Caelestia Shell's Blobs/shaders/blob.frag.
// GPL-3.0; attribution and upstream revision: licenses/README.md.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec4 fillColor;
    vec2 mainCenter;
    vec2 mainSize;
    float mainRadius;
    vec2 satelliteCenter;
    vec2 satelliteSize;
    float satelliteRadius;
    float facingRadius;
    float blendRadius;
    float filletRadius;
    vec2 inwardNormal;
    float edgeSoftness;
    vec4 cutoutRect;
    float cutoutRadius;
} ubuf;

float roundedBoxDistance(vec2 point, vec2 halfSize, float radius)
{
    vec2 q = abs(point) - halfSize + vec2(radius);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}

float circularMinimum(float a, float b, float radius)
{
    if (radius <= 0.001)
        return min(a, b);
    // A circular arc tangent to both surfaces, rather than a cubic bulge
    // over the entire equal-distance band.
    return max(radius, min(a, b))
        - length(max(vec2(radius) - vec2(a, b), vec2(0.0)));
}

void main()
{
    vec2 pixel = qt_TexCoord0 * ubuf.resolution;
    vec2 tangent = vec2(ubuf.inwardNormal.y, -ubuf.inwardNormal.x);
    float inward = dot(pixel - ubuf.mainCenter, ubuf.inwardNormal) - ubuf.mainRadius;
    float along = dot(pixel - ubuf.mainCenter, tangent);
    float halfLength = dot(ubuf.satelliteSize * 0.5, abs(tangent));
    float halfDepth = dot(ubuf.satelliteSize * 0.5, abs(ubuf.inwardNormal));
    float gap = max(0.0, dot(ubuf.satelliteCenter - ubuf.mainCenter, ubuf.inwardNormal)
        - ubuf.mainRadius - halfDepth);
    float mainDistance = roundedBoxDistance(pixel - ubuf.mainCenter, ubuf.mainSize * 0.5, ubuf.mainRadius);
    float panelRadius = dot(pixel - ubuf.satelliteCenter, ubuf.inwardNormal) < 0.0
        ? ubuf.facingRadius : ubuf.satelliteRadius;
    float panelDistance = roundedBoxDistance(pixel - ubuf.satelliteCenter, ubuf.satelliteSize * 0.5, panelRadius);

    // Peel across a broad contact patch as the panel leaves the edge. There
    // is no separate seed or connector: the fillet itself narrows and breaks.
    // Keep this profile in sync with junctionRadius() in LongIslandFrame.
    float t = clamp(abs(along) / (halfLength + ubuf.filletRadius), 0.0, 1.0);
    float radius = ubuf.blendRadius * (1.0 - smoothstep(0.0, ubuf.filletRadius, gap) * t * t);
    float surface = circularMinimum(mainDistance, panelDistance, radius);
    // The bar is stationary; the hidden portion of the sliding panel must
    // never show above it or swell its outer edge.
    surface = min(mainDistance, max(surface, -inward));

    if (ubuf.cutoutRect.z > 0.0) {
        float cutout = roundedBoxDistance(pixel - ubuf.cutoutRect.xy - ubuf.cutoutRect.zw * 0.5,
            ubuf.cutoutRect.zw * 0.5, ubuf.cutoutRadius);
        surface = min(mainDistance, max(surface, -cutout));
    }
    float alpha = 1.0 - smoothstep(-ubuf.edgeSoftness, ubuf.edgeSoftness, surface);
    fragColor = ubuf.fillColor * alpha * ubuf.qt_Opacity;
}
