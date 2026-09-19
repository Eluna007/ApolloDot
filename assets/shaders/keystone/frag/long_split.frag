#version 450

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
    float blendRadius;
    float edgeSoftness;
    vec4 cutoutRect;
    float cutoutRadius;
} ubuf;

float roundedBoxDistance(vec2 point, vec2 halfSize, float radius)
{
    vec2 edgeDistance = abs(point) - halfSize + vec2(radius);
    return min(max(edgeDistance.x, edgeDistance.y), 0.0)
        + length(max(edgeDistance, vec2(0.0)))
        - radius;
}

float smoothMinimum(float first, float second, float radius)
{
    if (radius <= 0.001)
        return min(first, second);

    float influence = max(radius - abs(first - second), 0.0) / radius;
    return min(first, second) - influence * influence * radius * 0.25;
}

void main()
{
    vec2 pixel = qt_TexCoord0 * ubuf.resolution;
    float mainDistance = roundedBoxDistance(
        pixel - ubuf.mainCenter,
        ubuf.mainSize * 0.5,
        ubuf.mainRadius
    );
    float satelliteDistance = roundedBoxDistance(
        pixel - ubuf.satelliteCenter,
        ubuf.satelliteSize * 0.5,
        ubuf.satelliteRadius
    );
    // Localize the smooth union around the clock. A uniform blend between
    // two long, flat edges creates a wide sheet instead of a liquid neck.
    bool horizontal = ubuf.mainSize.x >= ubuf.mainSize.y;
    float crossAxis = horizontal ? pixel.x - ubuf.satelliteCenter.x
                                : pixel.y - ubuf.satelliteCenter.y;
    float pillSpan = horizontal ? ubuf.satelliteSize.x : ubuf.satelliteSize.y;
    float neckSpan = clamp(pillSpan * 0.18, 28.0, 48.0);
    float normalizedCrossAxis = crossAxis / neckSpan;
    float neckWeight = exp(-normalizedCrossAxis * normalizedCrossAxis);
    float distanceToSurface = smoothMinimum(
        mainDistance,
        satelliteDistance,
        ubuf.blendRadius * neckWeight
    );
    if (ubuf.cutoutRect.z > 0.0) {
        float cutoutDistance = roundedBoxDistance(
            pixel - ubuf.cutoutRect.xy - ubuf.cutoutRect.zw * 0.5,
            ubuf.cutoutRect.zw * 0.5,
            ubuf.cutoutRadius
        );
        // The keyhole belongs only to the child; it must never punch through
        // the persistent clock bar while the child is being absorbed.
        distanceToSurface = min(mainDistance, max(distanceToSurface, -cutoutDistance));
    }
    float alpha = 1.0 - smoothstep(
        -ubuf.edgeSoftness,
        ubuf.edgeSoftness,
        distanceToSurface
    );

    fragColor = ubuf.fillColor * alpha * ubuf.qt_Opacity;
}
