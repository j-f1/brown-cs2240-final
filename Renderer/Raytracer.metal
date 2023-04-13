#include <metal_stdlib>
using namespace metal;
using namespace raytracing;

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

// Return the type for a bounding box intersection function.
struct BoundingBoxIntersection {
    bool accept    [[accept_intersection]]; // Whether to accept or reject the intersection.
    float distance [[distance]];            // Distance from the ray origin to the intersection point.
};

// Resources for a piece of triangle geometry.
struct TriangleResources {
    device uint16_t *indices;
    device float3 *vertexNormals;
    device float3 *vertexColors;
};

constant unsigned int primes[] = {
    2,   3,  5,  7,
    11, 13, 17, 19,
    23, 29, 31, 37,
    41, 43, 47, 53,
    59, 61, 67, 71,
    73, 79, 83, 89
};

// Returns the i'th element of the Halton sequence using the d'th prime number as a
// base. The Halton sequence is a low discrepency sequence: the values appear
// random, but are more evenly distributed than a purely random sequence. Each random
// value used to render the image uses a different independent dimension, `d`,
// and each sample (frame) uses a different index `i`. To decorrelate each pixel,
// you can apply a random offset to `i`.
float halton(unsigned int i, unsigned int d) {
    unsigned int b = primes[d];

    float f = 1.0f;
    float invB = 1.0f / b;

    float r = 0;

    while (i > 0) {
        f = f * invB;
        r = r + f * (i % b);
        i = i / b;
    }

    return r;
}

__attribute__((always_inline))
float3 transformPoint(float3 p, float4x4 transform) {
    return (transform * float4(p.x, p.y, p.z, 1.0f)).xyz;
}

__attribute__((always_inline))
float3 transformDirection(float3 p, float4x4 transform) {
    return (transform * float4(p.x, p.y, p.z, 0.0f)).xyz;
}

// Interpolates the vertex attribute of an arbitrary type across the surface of a triangle
// given the barycentric coordinates and triangle index in an intersection structure.
template<typename T, typename IndexType>
inline T interpolateVertexAttribute(device T *attributes,
                                    IndexType i0,
                                    IndexType i1,
                                    IndexType i2,
                                    float2 uv) {
    // Look up value for each vertex.
    const T T0 = attributes[i0];
    const T T1 = attributes[i1];
    const T T2 = attributes[i2];

    // Compute the sum of the vertex attributes weighted by the barycentric coordinates.
    // The barycentric coordinates sum to one.
    return (1.0f - uv.x - uv.y) * T0 + uv.x * T1 + uv.y * T2;
}

template<typename T>
inline T interpolateVertexAttribute(thread T *attributes, float2 uv) {
    // Look up the value for each vertex.
    const T T0 = attributes[0];
    const T T1 = attributes[1];
    const T T2 = attributes[2];

    // Compute the sum of the vertex attributes weighted by the barycentric coordinates.
    // The barycentric coordinates sum to one.
    return (1.0f - uv.x - uv.y) * T0 + uv.x * T1 + uv.y * T2;
}

// Uses the inversion method to map two uniformly random numbers to a 3D
// unit hemisphere, where the probability of a given sample is proportional to the cosine
// of the angle between the sample direction and the "up" direction (0, 1, 0).
inline float3 sampleCosineWeightedHemisphere(float2 u) {
    float phi = 2.0f * M_PI_F * u.x;

    float cos_phi;
    float sin_phi = sincos(phi, cos_phi);

    float cos_theta = sqrt(u.y);
    float sin_theta = sqrt(1.0f - cos_theta * cos_theta);

    return float3(sin_theta * cos_phi, cos_theta, sin_theta * sin_phi);
}

// Aligns a direction on the unit hemisphere such that the hemisphere's "up" direction
// (0, 1, 0) maps to the given surface normal direction.
inline float3 alignHemisphereWithNormal(float3 sample, float3 normal) {
    // Set the "up" vector to the normal
    float3 up = normal;

    // Find an arbitrary direction perpendicular to the normal, which becomes the
    // "right" vector.
    float3 right = normalize(cross(normal, float3(0.0072f, 1.0f, 0.0034f)));

    // Find a third vector perpendicular to the previous two, which becomes the
    // "forward" vector.
    float3 forward = cross(right, up);

    // Map the direction on the unit hemisphere to the coordinate system aligned
    // with the normal.
    return sample.x * right + sample.y * up + sample.z * forward;
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

    // The sample aligns the thread count to the threadgroup size, which means the thread count
    // may be different than the bounds of the texture. Test to make sure this thread
    // is referencing a pixel within the bounds of the texture.
    if (tid.x >= uniforms.width || tid.y >= uniforms.height) return;

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
    float2 uv = (float2)pixel / float2(uniforms.width, uniforms.height);
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
        // the sample adjusts this property below when it casts shadow rays.
        i.accept_any_intersection(false);

        // Check for intersection between the ray and the acceleration structure. If the sample
        // isn't using intersection functions, it doesn't need to include one.
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
