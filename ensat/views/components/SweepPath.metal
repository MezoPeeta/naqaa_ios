//
//  SweepPath.metal
//  ensat
//
//  Created by Mazen on 06/10/2026.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Erases or reveals text along the path its ink is written in.
///
/// `pathMap` stores, per pixel, how far along the strokes that pixel is: 0 at the first pixel
/// and 1 at the latest tip. Pixels with an order above `edge` are hidden, and the `band` just
/// below the edge fades out and takes the tint, so only the tip of the stroke carries the
/// gradient. Erasing moves `edge` down from the latest tip to the first pixel, and revealing
/// moves it back up. The tip also glows: its own pixels are pushed brighter in the tint
/// color by `glow`, without spilling any light onto the empty space around the letters.
[[ stitchable ]] half4 sweepPath(
    float2 position,
    half4 color,
    texture2d<half> pathMap,
    float2 origin,
    float2 size,
    float edge,
    float band,
    float tintStrength,
    float glow,
    half4 tint
) {
    if (color.a <= 0.0h) {
        return color;
    }

    constexpr sampler pathSampler(filter::linear, address::clamp_to_edge);
    float2 uv = (position - origin) / max(size, float2(1.0));
    float order = float(pathMap.sample(pathSampler, uv).r);

    // 0 behind the tip, 1 at and beyond the edge.
    float tip = clamp((order - (edge - band)) / max(band, 0.001), 0.0, 1.0);
    float smoothTip = tip * tip * (3.0 - 2.0 * tip);
    float visibility = 1.0 - smoothTip;
    float tipWeight = sin(tip * M_PI_F);

    half3 tinted = tint.rgb * color.a;
    half3 rgb = mix(color.rgb, tinted, half(tipWeight * tintStrength));
    // Premultiplied colors above the alpha add light, which reads as a glow in the ink.
    rgb += tinted * half(tipWeight * glow);
    return half4(rgb, color.a) * half(visibility);
}
