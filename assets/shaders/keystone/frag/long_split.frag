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
    vec2 inwardNormal;
    vec2 peakBulge;
    float bodyVisible;
    float contactBlend;
    vec4 neck; // separation, root half-width, waist half-width, active
    float edgeSoftness;
    vec4 cutoutRect;
    float cutoutRadius;
} ubuf;

float roundedBoxDistance(vec2 point, vec2 halfSize, float radius)
{
    vec2 edgeDistance = abs(point) - halfSize + vec2(radius);
    return min(max(edgeDistance.x, edgeDistance.y), 0.0)
        + length(max(edgeDistance, vec2(0.0))) - radius;
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
    vec2 relative = pixel - ubuf.mainCenter;
    vec2 tangent = vec2(ubuf.inwardNormal.y, -ubuf.inwardNormal.x);
    float along = dot(relative, tangent);
    float inward = dot(relative, ubuf.inwardNormal);
    float waterDepth = inward - ubuf.mainRadius;
    float mainDistance = roundedBoxDistance(relative, ubuf.mainSize * 0.5, ubuf.mainRadius);

    // The submerged object first stretches only the inward edge of the bar.
    // The arch has zero slope and curvature at both shoulders.
    float t = clamp(abs(along) / max(ubuf.peakBulge.x * 0.5, 0.001), 0.0, 1.0);
    float arch = pow(1.0 - t * t, 3.0) * ubuf.peakBulge.y;
    float surfaceDistance = mainDistance - arch * smoothstep(0.0, ubuf.mainRadius, inward);

    if (ubuf.bodyVisible > 0.5) {
        float bodyDistance = roundedBoxDistance(
            pixel - ubuf.satelliteCenter, ubuf.satelliteSize * 0.5, ubuf.satelliteRadius);
        // A buried panel cannot protrude through the opposite side of the bar.
        bodyDistance = max(bodyDistance, -waterDepth);
        // Union preserves the complete panel interior throughout emergence.
        // Never interpolate its distance field with the bar's distance field.
        surfaceDistance = smoothMinimum(surfaceDistance, bodyDistance,
            ubuf.contactBlend * smoothstep(0.0, ubuf.mainRadius, inward));
    }

    if (ubuf.neck.x > 0.001 && ubuf.neck.w > 0.5) {
        // Concave sides form a stretched meniscus. A negative waist splits the
        // neck in its centre; the two attached tips then retract into each surface.
        // Elliptical cut-ins meet the flat surfaces tangentially at each root.
        vec2 point = vec2(abs(along) - ubuf.neck.y, waterDepth - ubuf.neck.x * 0.5);
        vec2 radii = max(vec2(ubuf.neck.y - ubuf.neck.z, ubuf.neck.x * 0.5), vec2(0.001));
        float k0 = length(point / radii);
        float k1 = length(point / (radii * radii));
        float cutIn = k1 > 0.00001 ? k0 * (k0 - 1.0) / k1 : -min(radii.x, radii.y);
        float neckDistance = max(-cutIn, max(abs(along) - ubuf.neck.y,
            max(-waterDepth, waterDepth - ubuf.neck.x)));
        surfaceDistance = min(surfaceDistance, neckDistance);
    }

    if (ubuf.cutoutRect.z > 0.0) {
        float cutoutDistance = roundedBoxDistance(
            pixel - ubuf.cutoutRect.xy - ubuf.cutoutRect.zw * 0.5,
            ubuf.cutoutRect.zw * 0.5, ubuf.cutoutRadius);
        // The Dashboard hole belongs to the child, never to the persistent bar.
        surfaceDistance = min(mainDistance, max(surfaceDistance, -cutoutDistance));
    }
    float alpha = 1.0 - smoothstep(-ubuf.edgeSoftness, ubuf.edgeSoftness, surfaceDistance);
    fragColor = ubuf.fillColor * alpha * ubuf.qt_Opacity;
}
