#import <metal_stdlib>
using namespace metal;
using namespace raytracing;

#import "RandomGenerator.h"
#import "VectorWrapper.h"
#import "Intersector.h"
#import "EmissiveList.h"

#import "Shared.h"

struct Material {
    Color diffuse;
    Color specular;
    Color transmittance;
    Color emission;
    float shininess;
    float ior;
    int illum;
};

struct Sample {
    Direction direction;
    Location location;
    float pdf;
    bool reflection;
};

namespace Illum {
constexpr constant int flat = 0;
constexpr constant int diffuse = 1;
constexpr constant int diffuse_specular = 2;
constexpr constant int diffuse_specular_reflection = 3;
constexpr constant int glass = 4;
constexpr constant int diffuse_specular_fresnel = 5;
constexpr constant int refract = 6;
constexpr constant int refract_fresnel = 7;
constexpr constant int diffuse_specular_reflection_no_ray = 8;
constexpr constant int glass_no_ray = 9;
constexpr constant int shadow_only = 10;
}

static_assert(sizeof(Material) == sizeof(RawMaterial), "Material and RawMaterial must be memory compatible");
static_assert(alignof(Material) == alignof(RawMaterial), "Material and RawMaterial must be memory compatible");

struct SceneState {
    SceneState(const thread SceneState &) = delete;
    const constant float                                      *positions;
    const constant float                                      *vertexNormalDirections;
    const constant ushort                                     *vertices;
    const constant ushort                                     *faceVertexNormals;
    const constant float                                      *normals;
    const constant Material                                   *materials;
    const constant ushort                                     *materialIds;

    const constant  RenderSettings  &settings;
    const thread    Intersector     &intersector;
    const thread    EmissiveList    &emissives;
          thread    RandomGenerator &rng;
};

inline constexpr float3 unpack(constant float *floats, ushort idx) {
    if (idx == (ushort)-1) return 0.f;
    return float3(floats[idx * 3 + 0], floats[idx * 3 + 1], floats[idx * 3 + 2]);
}
inline constexpr ushort3 unpack(constant ushort *ints, ushort idx) {
    if (idx == (ushort)-1) return (ushort)-1;
    return ushort3(ints[idx * 3 + 0], ints[idx * 3 + 1], ints[idx * 3 + 2]);
}

struct ScatterMaterial {
    inline ScatterMaterial(const constant RenderSettings &settings, const constant Material &mat)
        : σs_prime(settings.ss.sigma_s_prime)
        , σa(settings.ss.sigma_a)
        , σt_prime(settings.ss.sigma_s_prime + settings.ss.sigma_a)
        , ior(settings.ss.eta)
        , mat(mat)
    {}
    float3 σs_prime;
    float3 σa;
    float3 σt_prime;
    float σtc;
    float ior;

    const constant Material &mat;
    float phase(Direction out, Direction in) const { return phase(dot(out, in)); }
    float phase(float cosine) const { return M_1_PI_F / 4; }
};

inline float fresnel(const thread float ior, const thread Direction normal, const Direction inDir) {
    //Schlick's approximation:
    float ior_air = 1.0003;
    float R_0 = (ior-ior_air)/(ior+ior_air);
    R_0 *= R_0;
    Direction n = normalize(normal);
    Direction r = normalize(inDir);
    float cosAngle = dot(n, r);
    float schlicks = R_0 + (1.f-R_0)*pow(1.f-cosAngle, 5);
//    return clamp(1-schlicks, 0.f, 1.f);
    return 1 - schlicks;
//        return 0.5;
}
