#ifndef common_h
#define common_h

#include <metal_stdlib>
using namespace metal;
using namespace raytracing;

#import "VectorWrapper.h"

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "Shared.h"

typedef intersector<triangle_data>::result_type Intersection;

struct SceneState {
    const constant MTLAccelerationStructureInstanceDescriptor *instances;
    const constant Material                                   *materials;
    const constant ushort                                     *materialIds;

    const constant int *emissives;
    const int           emissivesCount;
};

#endif /* common_h */
