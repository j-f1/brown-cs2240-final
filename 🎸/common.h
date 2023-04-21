#import <metal_stdlib>
using namespace metal;
using namespace raytracing;

#import "RandomGenerator.h"
#import "VectorWrapper.h"

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

struct Intersector {
private:
    intersector<triangle_data> i;
    const thread primitive_acceleration_structure &accelerationStructure;
public:
    struct Intersection {
        friend struct Intersector;
    protected:
        Intersection(intersector<triangle_data>::result_type i) : i(i) {}
        intersector<triangle_data>::result_type i;
    public:
        inline operator bool() const {
            return i.type != intersection_type::none;
        }
        inline int index() const {
            return i.primitive_id;
        }
        inline float distance() const {
            return i.distance;
        }
    };

    Intersector(const thread primitive_acceleration_structure &accelerationStructure)
    : i(), accelerationStructure(accelerationStructure)
    {
        // not using intersection functions, so some hints to Metal for better performance.
        i.assume_geometry_type(geometry_type::triangle);
        i.force_opacity(forced_opacity::opaque);

        // Get the closest intersection, not the first intersection.
        // (this is the default)
        i.accept_any_intersection(false);
    }

    Intersection operator()(const thread ray &ray) const {
        return {i.intersect(ray, accelerationStructure)};
    }

    //    Intersection test(const thread ray &ray) {
    //        // Get the first intersection, not the closest intersection.
    //        i.accept_any_intersection(true);
    //
    //        return i.intersect(ray, accelerationStructure);
    //    }
};

struct SceneState {
    const constant float                                      *positions;
    const constant ushort                                     *vertices;
    const constant float                                      *normals;
    const constant Material                                   *materials;
    const constant ushort                                     *materialIds;

    const constant  RenderSettings  &settings;
    const thread    Intersector     &intersector;
          thread    RandomGenerator &rng;

    const constant int *emissives;
    const int           emissivesCount;
};

inline constexpr float3 unpack(constant float *floats, unsigned int idx) {
    return float3(floats[idx * 3 + 0], floats[idx * 3 + 1], floats[idx * 3 + 2]);
}
template<typename T>
inline constexpr T unpack(constant float *floats, unsigned int idx) {
    return T::_wrap(unpack(floats, idx));
}
inline constexpr ushort3 unpack(constant ushort *ints, unsigned int idx) {
    return ushort3(ints[idx * 3 + 0], ints[idx * 3 + 1], ints[idx * 3 + 2]);
}

