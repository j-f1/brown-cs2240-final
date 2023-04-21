#import "common.h"

#import "DirectLighting.h"
#import "RandomGenerator.h"
#import "Sampler.h"

struct RayTraceResult {
    // next ray to follow
    ray ray;
    // brdf for that ray
    Color brdf;
    // total light (emission + direct lighting)
    Color illumination;
};

inline RayTraceResult traceRay(const thread ray &inRay, const thread int &pathLength, thread SceneState &scene) {
    // Check for intersection between the ray and the acceleration structure.
    auto intersection = scene.intersector(inRay);
    float3 intersectionPoint = inRay.origin + inRay.direction * intersection.distance();

    RayTraceResult result{
        .ray = ray{intersectionPoint, 0.f, inRay.min_distance, inRay.max_distance},
        // .brdf = [uninitialized],
        // .illumination = [uninitialized]
    };

    // Stop if the ray didn't hit anything and has bounced out of the scene.
    if (!intersection) {
        result.brdf = Color::black();
        result.illumination = Color::black();
        return result;
    }

    Direction normal = unpack<Direction>(scene.normals, intersection.index());
    Material material = scene.materials[scene.materialIds[intersection.index()]];

    if (material.emission) {
        result.brdf = Color::black();
        result.illumination = material.emission;
        return result;
    }

    if (scene.settings.directLightingOn) {
        result.illumination = directLighting(inRay, normal, material, scene);
    } else {
        result.illumination = Color::black();
    }

    Color brdf;
    Direction outDirection;
    switch (material.illum) {
        case Illum::refract_fresnel:
        case Illum::glass:
            // result.ray.direction = [glass BRDF]._unwrap();
            result.brdf = Color::white();
            break;
        case Illum::diffuse_specular_fresnel:
        case Illum::diffuse_specular:
            if (material.specular) {
                if (material.shininess > 100) {
                    // result.ray.direction = [mirror BRDF]._unwrap();
                    result.brdf = material.specular;
                } else {
                    // result.ray.direction = [specular BRDF]._unwrap();
                    result.brdf = material.specular;
                }
            } else {
                // result.ray.direction = [diffuse BRDF]._unwrap();
                result.brdf = material.diffuse;
            }
            break;
        default:
            brdf = Color::pink();
            break;
    }

    result.brdf *= abs(result.ray);

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
    SceneState state{positions, vertices, normals, materials, materialIds, uniforms.settings, Intersector{accelerationStructure}, rng};
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
    Color totalBRDF = Color::white();
    Color totalIllumination = Color::black();
    do {
        result = traceRay(ray, 0, state);

        totalIllumination += totalBRDF * result.illumination;
        totalBRDF *= result.brdf;

        if (all(result.ray.direction == 0.f)) break;
        ray = result.ray;
        depth++;
    } while (rng() < settings.russianRoulette);

    Color color = totalIllumination / pow(settings.russianRoulette, depth);

    dstTex.write(float4(color._unwrap(), 1), tid);
}
