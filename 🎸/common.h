#import <metal_stdlib>
using namespace metal;
using namespace raytracing;

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
static_assert(sizeof(Material) == sizeof(RawMaterial), "Material and RawMaterial must be memory compatible");
static_assert(alignof(Material) == alignof(RawMaterial), "Material and RawMaterial must be memory compatible");

struct Intersector {
private:
    intersector<triangle_data> i;
    const thread primitive_acceleration_structure &accelerationStructure;
public:
    typedef intersector<triangle_data>::result_type Intersection;

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
        return i.intersect(ray, accelerationStructure);
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

    const thread Intersector &intersector;

    const constant int *emissives;
    const int           emissivesCount;
};
