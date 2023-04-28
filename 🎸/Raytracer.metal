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

//generate the smooth normal??
inline Direction generateWeightedNormal(thread Intersector::Intersection intersection, thread SceneState& scene) {
    tri hit{scene.vertices[intersection.index()], scene};
    
    Location v0 = hit.v2 - hit.v1;
    Location v1 = hit.v3 - hit.v1;
    Location v2 = intersection.location() - hit.v1;
    float d00 = dot(v0,v0);
    float d01 = dot(v0,v1);
    float d11 = dot(v1,v1);
    float d20 = dot(v2,v0);
    float d21 = dot(v2,v1);
    float denom = d00 * d11 - d01 * d01;
    float v = (d11 * d20 - d01 * d21) / denom;
    float w = (d00 * d21 - d01 * d20) / denom;
    float u = 1.f - v - w;

    Direction n = cross(v0,v1);
//    Direction n1 = floatEpsEqual(length_squared(hit.n1), 0) ? n : hit.n1;
//    Direction n2 = floatEpsEqual(length_squared(hit.n2), 0) ? n : hit.n2;
//    Direction n3 = floatEpsEqual(length_squared(hit.n3), 0) ? n : hit.n3;
//    Direction interpolated_normal = normalize(u * n1 + v * n2 + w * n3);
//    return interpolated_normal;
    return n;
}

//TODO eventually turn the outDir type to Ray because we will be in BSSDF land
inline Color getBRDF(const thread ray &inRay, const thread Direction normal, const thread Direction &outDir, const thread Material &mat, thread SceneState &scene) {
    //TODO COCO
    switch (mat.illum) {
        case Illum::refract_fresnel:
        case Illum::glass:
            return float3(1.f,1.f,1.f);
            break;
        case Illum::diffuse_specular_fresnel:
        case Illum::diffuse_specular:
            if (any(mat.specular > 0)) { //todo does this work?
                if (mat.shininess > 100) {
                    // [mirror BRDF];
                    return float3(1.f,1.f,1.f);
                } else {
                    // [Phong Glossy Specular BRDF];
                    float n = mat.shininess;
                    float3 s = mat.specular;
                    float3 normalized_color = ((n+2.f)/(2.f*M_PI_F))*s;
                    Direction norm = normalize(normal);
                    Direction reflectedVector = normalize(inRay.direction) - 2.f*dot(normalize(inRay.direction), norm)*norm;
                    float dotProd = dot(reflectedVector, normalize(outDir));
                    if (dotProd < 0) {return float3(0.f, 0.f, 0.f);}
                    float reflectiveIntensity = pow(dotProd, n);
                    
                    return normalized_color*reflectiveIntensity;
                }
            } else {
                // [diffuse BRDF];
                if (scene.settings.diffuseOn) {
                    return mat.diffuse/M_PI_F;
                } else {return float3(1.f,1.f,1.f);}
            }
            break;
        default:
            return 0.f; //TODO REMOVE
            break;
    }
}

inline Sample generateRandomOnHemi(Direction normal, float2 uv) {
    Sample result = {.direction = Direction(0,0,0), .pdf = 1.f,};
    float3 randomHemi = sampleCosineWeightedHemisphere(uv); //pick a random direction on the hemisphere
    result.direction = alignHemisphereWithNormal(randomHemi, normal); //align the random direction with the normal
    result.pdf = 1.f/(2.f*M_PI_F);
    return result;
}

inline Sample getNextDirection(const thread Location &intersectionPoint, const thread Direction normal, const thread Material &mat, const thread ray &inRay, thread SceneState &scene) {
    
    float e1 = scene.rng(); //random number
    float e2 = scene.rng(); //random number
    
    //TODO COCO
    Sample result = {.direction = Direction(0,0,0), .pdf = 1.f};
    switch (mat.illum) {
        case Illum::refract_fresnel:
        case Illum::glass:
            // glass
            {
                float3 norm = normal;
                float cos_theta_i = dot(norm, inRay.direction);
                bool passingIntoGlass = cos_theta_i < 0;
                
                float ior = mat.ior;//Diffuse color as array of floats
                float ior_i; //ior that the ray was passing through
                float ior_t; //ior that the ray is maybe going into
                
                //when the ray hits a boundary of a refractive object, it is not obvious whether the ray is entering the object or exiting.
                //Use normals to determine this (if ray is in the same direction as normal, it is leaving object)
                //We have guarantee that rays will only pass into refractive objects and then immediately air when passing out
                if (passingIntoGlass) {
                    cos_theta_i = abs(cos_theta_i);
                    ior_i = 1;
                    ior_t = ior;
                } else {
                    norm*=-1;
                    ior_i = ior;
                    ior_t = 1;
                }
                
                float sqdCos_t = 1.f-pow((ior_i/ior_t),2)*(1.f-pow(cos_theta_i,2));
                //if ior is already that of glass, change it back to air
                
                //for dielectric splitting (both reflection and refraction) use Schlick's approximation of how much light gets reflected
                float split = scene.rng();
                float r_0 = pow((ior_i-ior_t)/(ior_i+ior_t),2.f);
                float schlicks = r_0 + (1.f-r_0)*pow((1.f-cos_theta_i),5.f);
                
                
                if (split < schlicks || sqdCos_t < 0) { //if Schlicks, or if total internal reflection
                    //reflect
                    Direction incomingDir = normalize(inRay.direction);
                    Direction reflectedVector = incomingDir - 2.f*dot(incomingDir,norm)*norm;
                    result.direction = reflectedVector;
                    result.pdf = 1.f;
                } else {
                    //refract
                    float cosTheta_t = sqrt(sqdCos_t);
                    float ratioIT = ior_i/ior_t;
                    //if the determinant is non-negative, we do not have total internal reflection
                    Direction refractedDir = ratioIT * inRay.direction + (ratioIT * cos_theta_i - cosTheta_t)*norm;
                    
                    //accumulate the radiance of the next path!
                    result.direction = refractedDir;
                    result.pdf = 1.f;
                    
                }
                return result;
            }
            break;
        case Illum::diffuse_specular_fresnel:
        case Illum::diffuse_specular:
            if (any(mat.specular>0)) {
                if (mat.shininess > 100) {
                    // mirror
                    if (scene.settings.mirrorOn) {
                        Direction reflectedVector = inRay.direction - 2.f*dot(inRay.direction, normal)*normal;
                        result.direction = reflectedVector;
                        result.pdf = 1.f;
                        return result;
                    } else {
                        return generateRandomOnHemi(normal, float2(e1, e2));
                    }
                } else {
                    // specular BRDF;
                    if (scene.settings.importanceSamplingOn) {
                        //TODO
                        float shine = mat.shininess;

                        float phi = 2.0 * M_PI_F * e1;
                        float theta = acos(pow(e2, 1/(1+shine)));

                        Direction objSpaceRand = float3(1.*sin(theta)*cos(phi), 1.*cos(theta), 1.*sin(theta)*sin(phi));

                        result.pdf = (shine+2.f)/(2.f*M_PI_F)*(pow(cos(theta),shine));

                        Direction reflectedVector = inRay.direction - 2.f*(dot(inRay.direction,normal))*normal;

                        result.direction = alignHemisphereWithNormal(objSpaceRand, reflectedVector);

                        return result;
                    } else {
                        return generateRandomOnHemi(normal, float2(e1, e2));
                    }
                }
            } else {
                // diffuse
                if (scene.settings.importanceSamplingOn) {
                    float phi = 2.0 * M_PI_F * e1;
                    float theta = asin(e2);
                    Direction objSpaceRand = normalize(float3(1.*sin(theta)*cos(phi), 1.*cos(theta), 1.*sin(theta)*sin(phi)));
                    result.direction = normalize(alignHemisphereWithNormal(objSpaceRand, normalize(normal)));
                    result.pdf = dot(normalize(normal),result.direction);
                    return result;
                } else {
                    return generateRandomOnHemi(normal, float2(e1, e2));
                }
            }
            break;
        default:
            result.direction = Direction(0, 0, 0);
            result.pdf = 1;
            return result;
            break;
    }
}

inline RayTraceResult traceRay(const thread ray &inRay, const thread int &pathLength, thread SceneState &scene) {
    // Check for intersection between the ray and the acceleration structure.
    Intersector::Intersection intersection = scene.intersector(inRay);
    
    RayTraceResult result{
        .ray = ray{intersection.location(), 0.f, inRay.min_distance, inRay.max_distance},
        // .brdf = [uninitialized],
        // .illumination = [uninitialized]
    };
    
    // Stop if the ray didn't hit anything and has bounced out of the scene.
    if (!intersection) {
        result.brdf = Colors::black();
        result.illumination = Colors::black();
        return result;
    }
    
    Direction normal = unpack<Direction>(scene.normals, intersection.index());
//    Direction normal = generateWeightedNormal(intersection, scene);
    normal = normalize(normal);
    Material material = scene.materials[scene.materialIds[intersection.index()]];
    
    if (!floatEpsEqual(material.emission, 0)) {
        result.brdf = Colors::black();
        if (pathLength == 0 || !scene.settings.directLightingOn) {
            result.illumination = material.emission;
        }
        return result;
    }
    
    Sample sample = getNextDirection(intersection.location(), normalize(normal), material, inRay, scene);
    
    if (scene.settings.directLightingOn) {
        result.illumination = directLighting(inRay, intersection.location(), normal, material, scene);
    } else {
        result.illumination = Colors::black();
    }
    
    Color brdf = getBRDF(inRay, normal, sample.direction, material, scene);
    result.brdf = brdf;
    
    
    float lightProjection = abs(dot(sample.direction, normal));
    
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
//                             constant float                     *vertexNormals             [[buffer(BufferIndexVertexNormals)]],
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
    SceneState state{positions, vertices, normals, materials, materialIds, uniforms.settings, Intersector{accelerationStructure}, rng, emissives, uniforms.emissivesCount}; //vertexNormals
    
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
    Color totalBRDF = Colors::white();
    Color totalIllumination = Colors::black();
    do {
        result = traceRay(ray, depth, state); //depth -> 0
        
        totalIllumination += totalBRDF * result.illumination;
        totalBRDF *= result.brdf;
        
        if (all(result.ray.direction == 0.f)) break;
        ray = result.ray;
        depth++;
    } while (rng() < settings.russianRoulette);
    
    Color color = totalIllumination / pow(settings.russianRoulette, depth);
    
    //    dstTex.write(uint4(uint3(aces_approx(color) * 255), 1), tid); //TODO make this an optional color mode
    dstTex.write(uint4(uint3(tone_map(color, settings.toneMap, settings.gammaCorrection) * 255), 1), tid);
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
