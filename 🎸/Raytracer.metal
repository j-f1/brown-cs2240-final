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

//TODO eventually turn the outDir type to Ray because we will be in BSSDF land
inline Color getBRDF(const thread ray &inRay, const thread Direction &outDir, const thread Material &mat) {
    //TODO COCO
    return 0.f;
}

inline Sample getNextDirection(const thread Location &intersectionPoint, const thread Material &mat, const thread ray &inRay) {
    //TODO COCO
    //    switch (material.illum) {
    //        case Illum::refract_fresnel:
    //        case Illum::glass:
    //            // sample = [glass BRDF]
    //            result.brdf = Color::white();
    //            break;
    //        case Illum::diffuse_specular_fresnel:
    //        case Illum::diffuse_specular:
    //            if (material.specular) {
    //                if (material.shininess > 100) {
    //                    // sample = [mirror BRDF];
    //                    result.brdf = material.specular;
    //                } else {
    //                    // sample = [specular BRDF];
    //                    result.brdf = material.specular;
    //                }
    //            } else {
    //                // sample = [diffuse BRDF];
    //                result.brdf = material.diffuse;
    //            }
    //            break;
    //        default:
    //            sample.direction = Direction(0, 0, 0);
    //            sample.pdf = 1;
    //            result.brdf = Color::pink();
    //            break;
    //    }
    //

    return Sample{Direction(0,0,0), 0};
}

inline RayTraceResult traceRay(const thread ray &inRay, const thread int &pathLength, thread SceneState &scene) {
    // Check for intersection between the ray and the acceleration structure.
    auto intersection = scene.intersector(inRay);

    RayTraceResult result{
        .ray = ray{intersection.location()._unwrap(), 0.f, inRay.min_distance, inRay.max_distance},
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
        if (pathLength == 0 && scene.settings.directLightingOn) {
            result.illumination = material.emission;
        }
        return result;
    }

    Sample nextDirection = getNextDirection(intersection.location(), material, inRay);

    if (scene.settings.directLightingOn) {
        result.illumination = directLighting(inRay, normal, material, scene);
    } else {
        result.illumination = Color::black();
    }

    Sample sample = getNextDirection(intersection.location(), material, inRay);
    Color brdf = getBRDF(inRay, sample.direction, material);
    result.brdf = brdf;


    float lightProjection = abs(dot(sample.direction, normal._unwrap()));

    result.ray.direction = sample.direction;
    result.brdf *= lightProjection / sample.pdf;

    return result;
}

kernel void raytracingKernel(
     uint2                               tid                       [[thread_position_in_grid]],

     constant Uniforms &                 uniforms                  [[buffer(BufferIndexUniforms)]],
     texture2d<unsigned int>             randomTex                 [[texture(TextureIndexRandom)]],
     texture2d<uint, access::write>      dstTex                    [[texture(TextureIndexDst)]],
     constant float                     *positions                 [[buffer(BufferIndexVertexPositions)]],
     constant ushort                    *vertices                  [[buffer(BufferIndexFaceVertices)]],
     constant float                     *normals                   [[buffer(BufferIndexFaceNormals)]],
     constant ushort                    *materialIds               [[buffer(BufferIndexFaceMaterials)]],
     constant Material                  *materials                 [[buffer(BufferIndexMaterials)]],
     primitive_acceleration_structure    accelerationStructure     [[buffer(BufferIndexIntersector)]]
) {
    constant RenderSettings &settings = uniforms.settings;
    RandomGenerator rng{randomTex, tid, settings.frameIndex};
    SceneState state{positions, vertices, normals, materials, materialIds, uniforms.settings, Intersector{accelerationStructure}, rng};

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

    //raytracing loop
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

    dstTex.write(uint4(uint3(color.aces_approx()._unwrap() * 255), 1), tid);
}
