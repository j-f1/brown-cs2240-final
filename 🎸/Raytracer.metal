#import "common.h"

#import "RandomGenerator.h"
#import "Sampler.h"

__attribute__((always_inline))
float3 transformDirection(float3 p, float4x4 transform) {
    return (transform * float4(p.x, p.y, p.z, 0.0f)).xyz;
}

__attribute__((always_inline))
constexpr float3 unpack(constant float *floats, unsigned int idx) {
    return float3(floats[idx * 3 + 0], floats[idx * 3 + 1], floats[idx * 3 + 2]);
}

struct RayTraceResult {
    ray outRay;
    Color tint;
};

inline RayTraceResult traceRay(const thread ray &inRay, const thread int &pathLength, const thread SceneState &scene) {
    // Check for intersection between the ray and the acceleration structure.
    auto intersection = scene.intersector(inRay);
    float3 intersectionPoint = inRay.origin + inRay.direction * intersection.distance();

    RayTraceResult result {
        .outRay = ray{intersectionPoint, 0.0f, inRay.min_distance, inRay.max_distance}
    };

    // Stop if the ray didn't hit anything and has bounced out of the scene.
    if (!intersection) {
        result.tint = Color::black();
        return result;
    }

    float3 normal = unpack(scene.normals, intersection.index());
    Material material = scene.materials[scene.materialIds[intersection.index()]];

    if (pathLength == 0 && material.emission) {
        result.tint = material.emission;
        return result;
    }

    switch (material.illum) {
        case Illum::refract_fresnel:
        case Illum::glass:
            // result.outRay.direction = [glass BRDF]
            result.tint = Color::white();
            break;
        case Illum::diffuse_specular_fresnel:
        case Illum::diffuse_specular:
            if (material.specular) {
                if (material.shininess > 100) {
                    // result.outRay.direction = [mirror BRDF]
                    result.tint = material.specular;
                } else {
                    // result.outRay.direction = [specular BRDF]
                    result.tint = material.specular;
                }
            } else {
                // result.outRay.direction = [diffuse BRDF]
                result.tint = material.diffuse;
            }
            break;
        default:
            result.tint = Color::pink();
            break;
    }

    return result;

    //        // Transform the normal from object to world space.
    //        worldSpaceSurfaceNormal = normalize(transformDirection(objectSpaceSurfaceNormal, objectToWorldSpaceTransform));
    //
    //        // Choose a random direction to continue the path of the ray. This causes light to
    //        // bounce between surfaces. An app might evaluate a more complicated equation to
    //        // calculate the amount of light that reflects between intersection points.  However,
    //        // all the math in this kernel cancels out because this app assumes a simple diffuse
    //        // BRDF and samples the rays with a cosine distribution over the hemisphere (importance
    //        // sampling). This requires that the kernel only multiply the colors together. This
    //        // sampling strategy also reduces the amount of noise in the output image.
    //        r = float2(halton(offset + uniforms.frameIndex, 2 + bounce * 5 + 3),
    //                   halton(offset + uniforms.frameIndex, 2 + bounce * 5 + 4));
    //
    //        float3 worldSpaceSampleDirection = sampleCosineWeightedHemisphere(r);
    //        worldSpaceSampleDirection = alignHemisphereWithNormal(worldSpaceSampleDirection, worldSpaceSurfaceNormal);
    //
    //        ray.origin = worldSpaceIntersectionPoint + worldSpaceSurfaceNormal * 1e-3f;
    //        ray.direction = worldSpaceSampleDirection;
}

kernel void raytracingKernel(
     uint2                               tid                       [[thread_position_in_grid]],
     
     constant Uniforms &                 uniforms                  [[buffer(BufferIndexUniforms)]],
     texture2d<unsigned int>             randomTex                 [[texture(TextureIndexRandom)]],
     texture2d<float, access::write>     dstTex                    [[texture(TextureIndexDst)]],
     constant float                     *positions                 [[buffer(BufferIndexVertexPositions)]],
     constant ushort                    *vertices                  [[buffer(BufferIndexFaceVertices)]],
     constant float                     *normals                   [[buffer(BufferIndexFaceNormals)]],
     constant ushort                    *materialIds               [[buffer(BufferIndexFaceMaterials)]],
     constant Material                  *materials                 [[buffer(BufferIndexMaterials)]],
     primitive_acceleration_structure    accelerationStructure     [[buffer(BufferIndexIntersector)]]
) {
    RandomGenerator rng{randomTex, tid, uniforms.frameIndex};
    SceneState state{positions, vertices, normals, materials, materialIds, Intersector{accelerationStructure}, rng};
    constant RenderSettings &settings = uniforms.settings;

    // We align the thread count to the threadgroup size, which means the thread count
    // may be different than the bounds of the texture. Test to make sure this thread
    // is referencing a pixel within the bounds of the texture.
    if (tid.x >= settings.imageWidth || tid.y >= settings.imageHeight) return;

    // The ray to cast.
    ray ray;

    // Pixel coordinates for this thread.
    float2 pixel = (float2)tid;

    // Add a random offset to the pixel coordinates for antialiasing.
    pixel += float2(rng(), rng());

    // Map pixel coordinates to -1..1.
    float2 uv = (float2)pixel / float2(settings.imageWidth, settings.imageHeight);
    uv = uv * 2.0f - 1.0f;
    uv.y = -uv.y;

    constant Camera & camera = uniforms.camera;

    // Rays start at the camera position.
    ray.origin = camera.position;

    // Map normalized pixel coordinates into camera's coordinate system.
    ray.direction = normalize(uv.x * camera.right +
                              uv.y * camera.up +
                              camera.forward);

    // Don't limit intersection distance.
    ray.max_distance = INFINITY;

    RayTraceResult result;
    int depth = 0;
    Color tint = Color::white();
    do {
        result = traceRay(ray, 0, state);
        tint *= result.tint;
        ray = result.outRay;
        depth++;
    } while (any(ray.direction != 0.f) && rng() < settings.russianRoulette);

    Color color = tint / pow(settings.russianRoulette, depth);

    dstTex.write(float4(color._unwrap(), 1), tid);
}
