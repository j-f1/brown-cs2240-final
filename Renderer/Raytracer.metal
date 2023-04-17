#import "Halton.h"
#import "Sampler.h"

#include <metal_stdlib>
using namespace metal;
using namespace raytracing;

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

__attribute__((always_inline))
float3 transformDirection(float3 p, float4x4 transform) {
    return (transform * float4(p.x, p.y, p.z, 0.0f)).xyz;
}

kernel void raytracingKernel(
     uint2                                                  tid                       [[thread_position_in_grid]],
     constant Uniforms &                                    uniforms                  [[buffer(BufferIndexUniforms)]],
     texture2d<unsigned int>                                randomTex                 [[texture(TextureIndexRandom)]],
     texture2d<float, access::write>                        dstTex                    [[texture(TextureIndexDst)]],
     constant float                                        *positions                 [[buffer(BufferIndexVertexPositions)]],
     constant ushort                                       *vertices                  [[buffer(BufferIndexFaceVertices)]],
     constant ushort                                       *materialIds               [[buffer(BufferIndexFaceMaterials)]],
     constant Material                                     *materials                 [[buffer(BufferIndexMaterials)]],
     constant MTLAccelerationStructureInstanceDescriptor   *instances                 [[buffer(BufferIndexIntersectorObjects)]],
     primitive_acceleration_structure                       accelerationStructure     [[buffer(BufferIndexIntersector)]]
) {

    constant RenderSettings &settings = uniforms.settings;

    // We align the thread count to the threadgroup size, which means the thread count
    // may be different than the bounds of the texture. Test to make sure this thread
    // is referencing a pixel within the bounds of the texture.
    if (tid.x >= settings.imageWidth || tid.y >= settings.imageHeight) return;

    // The ray to cast.
    ray ray;

    // Pixel coordinates for this thread.
    float2 pixel = (float2)tid;

    // Apply a random offset to the random number index to decorrelate pixels.
    unsigned int offset = randomTex.read(tid).x;

    // Add a random offset to the pixel coordinates for antialiasing.
    float2 r = float2(halton(offset + uniforms.frameIndex, 0),
                      halton(offset + uniforms.frameIndex, 1));

    pixel += r;

    // Map pixel coordinates to -1..1.
    float2 uv = (float2)pixel / float2(settings.imageWidth, settings.imageHeight);
    uv = uv * 2.0f - 1.0f;

    constant Camera & camera = uniforms.camera;

    // Rays start at the camera position.
    ray.origin = camera.position;

    // Map normalized pixel coordinates into camera's coordinate system.
    ray.direction = normalize(uv.x * camera.right +
                              uv.y * camera.up +
                              camera.forward);

    // Don't limit intersection distance.
    ray.max_distance = INFINITY;

    // Start with a fully white color. The kernel scales the light each time the
    // ray bounces off of a surface, based on how much of each light component
    // the surface absorbs.
    float3 color = float3(1.0f, 1.0f, 1.0f);

    float4 accumulatedColor = float4(0.0f, 0.0f, 0.0f, 0.0f);

    // Create an intersector to test for intersection between the ray and the geometry in the scene.
    intersector<triangle_data> i;

    // not using intersection functions, so some hints to Metal for better performance.
    i.assume_geometry_type(geometry_type::triangle);
    i.force_opacity(forced_opacity::opaque);

    typename intersector<triangle_data>::result_type intersection;

    // Simulate up to three ray bounces. Each bounce propagates light backward along the
    // ray's path toward the camera.
    for (int bounce = 0; bounce < 3; bounce++) {
        // Get the closest intersection, not the first intersection. This is the default, but
        // we will adjust this property below when casting shadow rays.
        i.accept_any_intersection(false);

        // Check for intersection between the ray and the acceleration structure.
        intersection = i.intersect(ray, accelerationStructure);

        // Stop if the ray didn't hit anything and has bounced out of the scene.
        if (intersection.type == intersection_type::none)
            break;
        unsigned int instanceIndex = intersection.primitive_id;

        // The ray hit something. Look up the transformation matrix for this instance.
        float4x4 objectToWorldSpaceTransform(1.0f);

        for (int column = 0; column < 4; column++)
            for (int row = 0; row < 3; row++)
                objectToWorldSpaceTransform[column][row] = instances[instanceIndex].transformationMatrix[column][row];

        // Compute the intersection point in world space.
//        float3 worldSpaceIntersectionPoint = ray.origin + ray.direction * intersection.distance;
//
//        float3 worldSpaceSurfaceNormal = 0.0f;
//        float3 surfaceColor = 0.0f;
//
//        // XXX: compute normals
//        float3 objectSpaceSurfaceNormal = float3(0, 0, 0);
        auto material = materials[materialIds[intersection.primitive_id]];

        // XXX: path trace
        accumulatedColor = float4(material.diffuse, 1);
        break;

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

    dstTex.write(accumulatedColor, tid);
}
