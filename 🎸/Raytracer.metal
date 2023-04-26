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
//    switch (mat.illum) {
//        case Illum::refract_fresnel:
//        case Illum::glass:
//            // [glass BRDF]
//            break;
//        case Illum::diffuse_specular_fresnel:
//        case Illum::diffuse_specular:
//            if (mat.specular) {
//                if (mat.shininess > 100) {
//                    // [mirror BRDF];
//                } else {
//                    // [specular BRDF];
//                }
//            } else {
//                // [diffuse BRDF];
//                return mat.diffuse/M_PI_F;
//            }
//            break;
//        default:
//
//            break;
//    }
    return mat.diffuse/M_PI_F; //TODO REMOVE
//    return Color::white();
//    return 0.f;
}

inline Sample getNextDirection(const thread Location &intersectionPoint, const thread Direction normal, const thread Material &mat, const thread ray &inRay, thread SceneState &scene) {
    
    float e1 = scene.rng(); //random number
    float e2 = scene.rng(); //random number
    float phi = 2.0 * M_PI_F * e1; //random angle on the hemisphere
    float theta = acos(1.f-e2); //random angle on the hemisphere
    
    //TODO COCO
    Sample result = {.direction = Direction(0,0,0), .pdf = 1.f,};
//    if (scene.settings.importanceSamplingOn) {
//        switch (mat.illum) {
//            case Illum::refract_fresnel:
//            case Illum::glass:
//                // [glass BRDF]
//                break;
//            case Illum::diffuse_specular_fresnel:
//            case Illum::diffuse_specular:
//                if (mat.specular) {
//                    if (mat.shininess > 100) {
//                        // [mirror BRDF];
//                    } else {
//                        // [specular BRDF];
//                    }
//                } else {
//                    // [diffuse BRDF];
//                }
//                break;
//            default:
//                result.direction = Direction(0, 0, 0);
//                result.pdf = 1;
//                break;
//        }
//    } else {
//        float3 objSpaceRand = float3(1.*sin(theta)*cos(phi), 1.*cos(theta), 1.*sin(theta)*sin(phi));
//        float3 worldSpaceRand = alignHemisphereWithNormal(objSpaceRand, float3(0,1,0));
//        float3 n = normalize(worldSpaceRand);
//        result.direction = Direction(n.x, n.y, n.z);
//        result.pdf = 1.0/(2.0*M_PI_F);
//    }
    float3 randomHemi = sampleCosineWeightedHemisphere(float2(e1, e2)); //pick a random direction on the hemisphere
    float3 worldSpaceRand = alignHemisphereWithNormal(randomHemi, normal._unwrap()); //align the random direction with the normal
    result.direction = Direction(worldSpaceRand.x, worldSpaceRand.y, worldSpaceRand.z);
    result.pdf = 1.f/(2.f*M_PI_F);
    
    return result;
    
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
        if (pathLength == 0 || !scene.settings.directLightingOn) {
            result.illumination = material.emission;
        }
        return result;
    }
    
    Sample sample = getNextDirection(intersection.location(), normal, material, inRay, scene);
    
    if (scene.settings.directLightingOn) {
        result.illumination = directLighting(inRay, intersection.location(), normal, material, scene);
    } else {
        result.illumination = Color::black();
    }
    
    Color brdf = getBRDF(inRay, sample.direction, material);
    result.brdf = brdf;
    
    
    float lightProjection = abs(dot(sample.direction, normal._unwrap()));
    
    result.ray.direction = sample.direction;
    result.brdf *= lightProjection / sample.pdf;
    
    return result;
}

kernel void raytracingKernel(
                             uint3                               tid                       [[thread_position_in_grid]],

                             constant Uniforms &                 uniforms                  [[buffer(BufferIndexUniforms)]],
                             texture2d<unsigned int>             randomTex                 [[texture(TextureIndexRandom)]],
                             texture3d<uint, access::write>      dstTex                    [[texture(TextureIndexDst)]],
                             constant float                     *positions                 [[buffer(BufferIndexVertexPositions)]],
                             constant ushort                    *vertices                  [[buffer(BufferIndexFaceVertices)]],
                             constant float                     *normals                   [[buffer(BufferIndexFaceNormals)]],
                             constant ushort                    *materialIds               [[buffer(BufferIndexFaceMaterials)]],
                             constant ushort                    *emissives                 [[buffer(BufferIndexEmissiveFaces)]],
                             constant Material                  *materials                 [[buffer(BufferIndexMaterials)]],
                             primitive_acceleration_structure    accelerationStructure     [[buffer(BufferIndexIntersector)]]
                             )
{
    constant RenderSettings &settings = uniforms.settings;
    RandomGenerator rng{randomTex, tid, settings.frameIndex};
    SceneState state{positions, vertices, normals, materials, materialIds, uniforms.settings, Intersector{accelerationStructure}, rng, emissives, uniforms.emissivesCount};
    
    // We align the thread count to the threadgroup size, which means the thread count
    // may be different than the bounds of the texture. Test to make sure this thread
    // is referencing a pixel within the bounds of the texture.
    if (tid.x >= settings.imageWidth || tid.y >= settings.imageHeight) return;
    
    // The ray to cast.
    ray ray;
    
    // Pixel coordinates for this thread.
    float2 pixel = (float2)tid.xy;
    
    // Add a random offset to the pixel coordinates for antialiasing.
    pixel += float2(rng(), rng());

    // Map pixel coordinates to -1..1.
    float2 uv = pixel / float2(settings.imageWidth, settings.imageHeight);
    uv = uv * 2.0f - 1.0f;
    uv.y = -uv.y;
    
    constant Camera & camera = uniforms.camera;
    
    // Rays start at the camera position.
    ray.origin = camera.position;
    
    // Map normalized pixel coordinates into camera's coordinate system.
    ray.direction = normalize(uv.x * camera.right +
                              uv.y * camera.up +
                              camera.forward);

    // avoid self-intersection
    ray.min_distance = 0.01;

    // Don't limit intersection distance.
    ray.max_distance = INFINITY;
    
    //raytracing loop
    RayTraceResult result;
    int depth = 0;
    Color totalBRDF = Color::white();
    Color totalIllumination = Color::black();
    do {
        result = traceRay(ray, depth, state); //depth -> 0
        
        totalIllumination += totalBRDF * result.illumination;
        totalBRDF *= result.brdf;
        
        if (all(result.ray.direction == 0.f)) break;
        ray = result.ray;
        depth++;
    } while (rng() < settings.russianRoulette);
    
    Color color = totalIllumination / pow(settings.russianRoulette, depth);
    
    dstTex.write(uint4(uint3(color.aces_approx()._unwrap() * 255), 1), tid);
}

kernel void flattenKernel(
    uint2                               tid                       [[thread_position_in_grid]],
    constant Uniforms &                 uniforms                  [[buffer(BufferIndexUniforms)]],
    texture3d<uint, access::read>       srcTex                    [[texture(TextureIndexSrc)]],
    texture3d<uint, access::write>      dstTex                    [[texture(TextureIndexDst)]]
) {
    if (!uniforms.settings.diffuseOn) return;
    float4 result = 0.f;
    for (uint z = 0; z < srcTex.get_depth(); z++) {
        result += float4(srcTex.read(uint3(tid, z)));
    }
    result /= srcTex.get_depth();
    dstTex.write(uint4(result), uint3(tid, 0));
}
