#import <metal_stdlib>
using namespace metal;
using namespace raytracing;

#import "RandomGenerator.h"
#import "VectorWrapper.h"
#import "Intersector.h"

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
    const constant float                                      *positions;
    const constant float                                      *vertexNormalDirections;
    const constant ushort                                     *vertices;
    const constant ushort                                     *faceVertexNormals;
    const constant float                                      *normals;
    const constant Material                                   *materials;
    const constant ushort                                     *materialIds;

    const constant  RenderSettings  &settings;
    const thread    Intersector     &intersector;
          thread    RandomGenerator &rng;

    const constant ushort  *emissives;
    const int               emissivesCount;
};

inline constexpr float3 unpack(constant float *floats, ushort idx) {
    if (idx == (ushort)-1) return 0.f;
    return float3(floats[idx * 3 + 0], floats[idx * 3 + 1], floats[idx * 3 + 2]);
}
inline constexpr ushort3 unpack(constant ushort *ints, ushort idx) {
    if (idx == (ushort)-1) return (ushort)-1;
    return ushort3(ints[idx * 3 + 0], ints[idx * 3 + 1], ints[idx * 3 + 2]);
}

struct tri {
    inline tri(int idx, const thread SceneState &scene)
    : idx(idx), material(scene.materials[scene.materialIds[idx]]) {
        ushort3 vertIndices = unpack(scene.vertices, idx);
        v1 = unpack(scene.positions, vertIndices.x);
        v2 = unpack(scene.positions, vertIndices.y);
        v3 = unpack(scene.positions, vertIndices.z);
        ushort3 normalIndices = unpack(scene.faceVertexNormals, idx);
        n1 = unpack(scene.vertexNormalDirections, normalIndices.x);
        n2 = unpack(scene.vertexNormalDirections, normalIndices.y);
        n3 = unpack(scene.vertexNormalDirections, normalIndices.z);
        faceNormal = unpack(scene.normals, idx);
    }

    int idx;
    const constant Material &material;
    Direction faceNormal;
    Location v1, v2, v3;
    Direction n1, n2, n3;

    inline Location sample(thread RandomGenerator &rng) const {
        // https://math.stackexchange.com/a/538472/415698
        return v1 + rng() * (v2 - v1) + rng() * (v3 - v1);
    }
};
