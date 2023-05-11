//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//

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
    BufferIndexVertexPositions,
    BufferIndexVertexNormalAngles,
    BufferIndexFaceVertices,
    BufferIndexFaceNormals,
    BufferIndexFaceVertexNormals,
    BufferIndexFaceMaterials,
    BufferIndexMaterials,
    BufferIndexIntersector,
    BufferIndexUniforms,
    BufferIndexEmissiveFaces,
};

typedef NS_ENUM(EnumBackingType, TextureIndex)
{
    TextureIndexRandom = 0,
    TextureIndexSrc    = 1,
    TextureIndexDst    = 2,
};

typedef NS_ENUM(EnumBackingType, FunctionConstantIndex)
{
    FunctionConstantIndexBatchSize = 0
};

typedef struct Camera {
    vector_float3 position;
    vector_float3 right;
    vector_float3 up;
    vector_float3 forward;
} Camera;

typedef struct RenderSettings {
    bool diffuseOn;
    bool mirrorOn;
    // bool refractionOn;
    // bool glossyOn;
    bool subsurfaceScatteringOn;
    bool singleSSOn;
    bool diffusionSSOn;
    simd_float3 ssSigma_s_prime;
    simd_float3 ssSigma_a;
    float ssEta;
    float ssG;
    bool directLightingOn;
    int directLightingSamples;
    bool importanceSamplingOn;
    // bool glassTransmittanceOn;
    float russianRoulette;
    int samplesPerPixel;
    simd_float3 toneMap;
    float gammaCorrection;
    unsigned int imageWidth;
    unsigned int imageHeight;
    unsigned int frameIndex;
} RenderSettings;

struct Uniforms {
    Camera camera;
    RenderSettings settings;
    int emissivesCount;
};

// See also Material struct
struct RawMaterial {
    vector_float3 diffuse;
    vector_float3 specular;
    vector_float3 transmittance;
    vector_float3 emission;
    float shininess;
    float ior;
    int illum;
};
