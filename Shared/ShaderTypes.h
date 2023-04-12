//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
#import <Foundation/Foundation.h>
typedef NSInteger EnumBackingType;
#endif

#include <simd/simd.h>

typedef NS_ENUM(EnumBackingType, BufferIndex)
{
    BufferIndexVertexPositions    = 0,
    BufferIndexFaceVertices       = 1,
    BufferIndexFaceMaterials      = 3,
    BufferIndexMaterials          = 4,
    BufferIndexIntersectorObjects = 5,
    BufferIndexIntersector        = 6,
    BufferIndexUniforms           = 7
};

typedef NS_ENUM(EnumBackingType, TextureIndex)
{
    TextureIndexRandom = 0,
    TextureIndexDst    = 1
};

typedef struct Camera {
    vector_float3 position;
    vector_float3 right;
    vector_float3 up;
    vector_float3 forward;
} Camera;

typedef struct
{
    Camera camera;

    unsigned int width;
    unsigned int height;
    unsigned int frameIndex;
} Uniforms;

struct Triangle {
    vector_float3 normals[3];
    vector_float3 colors[3];
};

struct Material {
    vector_float3 diffuse;
    vector_float3 specular;
    vector_float3 transmittance;
    vector_float3 emission;
    float shininess;
    float ior;
    int illum;
};

#endif /* ShaderTypes_h */
