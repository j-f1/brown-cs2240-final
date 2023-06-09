#import "common.h"

#import "DirectLighting.h"
#import "RandomGenerator.h"
#import "BRDF.h"

struct RayTraceResult {
    // next ray to follow
    ray ray;
    // brdf for that ray
    Color brdf;
    // total light (emission + direct lighting)
    Color illumination;
    
    //if a reflection event happened
    bool sampleDirectLighting;
};

inline RayTraceResult traceRay(const thread ray &inRay, const thread int &pathLength, thread SceneState &scene) {
    // Check for intersection between the ray and the acceleration structure.
    Intersector::Intersection intersection = scene.intersector(inRay);
    
    RayTraceResult result{
        .ray = ray{intersection.location(), 0.f, inRay.min_distance, inRay.max_distance},
        .sampleDirectLighting = false,
        // .brdf = [uninitialized],
        // .illumination = [uninitialized]
    };
    
    // Stop if the ray didn't hit anything and has bounced out of the scene.
    if (!intersection) {
        result.brdf = Colors::black();
        result.illumination = Colors::black();
        return result;
    }

    Hit hit{intersection, scene};
    
    if (!floatEpsEqual(hit.tri.material.emission, 0)) {
        result.brdf = Colors::black();
        if (pathLength == 0 || !scene.settings.directLightingOn) {
            result.illumination = hit.tri.material.emission;
        }
        return result;
    }
    
    Sample sample = getNextDirection(hit, scene);
    
    if (scene.settings.directLightingOn) {
        result.illumination = directLighting(hit, scene);
    } else {
        result.illumination = Colors::black();
    }
    
    Color brdf = getBRDF(hit, sample.hit, scene);
    result.brdf = brdf;
    
    result.ray.direction = sample.hit.inRay.direction;
//    result.ray.origin = sample.hit.location + 0.001*sample.hit.normal;
    result.brdf /= sample.pdf;
    if (floatEpsEqual(sample.hit.inRay.direction, 0)) {
        result.illumination = result.brdf;
        result.brdf = Colors::white();
    } else if (floatEpsEqual(sample.hit.location, hit.location)) {
        float lightProjection = abs(dot(sample.hit.inRay.direction, hit.normal));
        result.brdf *= lightProjection;
    }
    
    result.sampleDirectLighting = sample.sampleDirectLighting;
    return result;
}

kernel void pathTraceKernel(
    uint3                               tid                       [[thread_position_in_grid]],
    constant Uniforms &                 uniforms                  [[buffer(BufferIndexUniforms)]],
    texture2d<unsigned int>             randomTex                 [[texture(TextureIndexRandom)]],
    texture3d<float, access::write>     dstTex                    [[texture(TextureIndexDst)]],
    constant float                     *positions                 [[buffer(BufferIndexVertexPositions)]],
    constant float                     *vertexNormals             [[buffer(BufferIndexVertexNormalAngles)]],
    constant ushort                    *vertices                  [[buffer(BufferIndexFaceVertices)]],
    constant ushort                    *faceVertexNormals         [[buffer(BufferIndexFaceVertexNormals)]],
    constant float                     *normals                   [[buffer(BufferIndexFaceNormals)]],
    constant ushort                    *materialIds               [[buffer(BufferIndexFaceMaterials)]],
    constant ushort                    *emissives                 [[buffer(BufferIndexEmissiveFaces)]],
    constant Material                  *materials                 [[buffer(BufferIndexMaterials)]],
    primitive_acceleration_structure    accelerationStructure     [[buffer(BufferIndexIntersector)]]
) {
    constant RenderSettings &settings = uniforms.settings;
    RandomGenerator rng{randomTex, tid, settings.frameIndex};
    EmissiveList emissiveList{emissives, uniforms.emissivesCount};
    SceneState state{positions, vertexNormals, vertices, faceVertexNormals, normals, materials, materialIds, uniforms.settings, Intersector{accelerationStructure}, emissiveList, rng};
    emissiveList.scene = &state;
    
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
    int totalDepth = 0;
    Color totalBRDF = Colors::white();
    Color totalIllumination = Colors::black();
    do {
        result = traceRay(ray, depth, state); //depth -> 0
        
        totalIllumination += totalBRDF * result.illumination;
        totalBRDF *= result.brdf;
        
        if (all(result.ray.direction == 0.f)) break;
        ray = result.ray;
        depth++;
        totalDepth++;
        if (result.sampleDirectLighting) depth = 0; //if it's a reflection event, count the illumination
    } while (rng() < settings.russianRoulette);
    
    Color color = totalIllumination / pow(settings.russianRoulette, totalDepth - 1);

    dstTex.write(float4(color, 1), tid);
}
