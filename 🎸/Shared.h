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
    BufferIndexVertexPositions    = 0,
    BufferIndexFaceVertices       = 1,
    BufferIndexFaceNormals        = 2,
    BufferIndexFaceMaterials      = 3,
    BufferIndexMaterials          = 4,
    BufferIndexIntersector        = 6,
    BufferIndexUniforms           = 7,
    BufferIndexEmissiveFaces      = 8,
};

typedef NS_ENUM(EnumBackingType, TextureIndex)
{
    TextureIndexRandom = 0,
    TextureIndexDst    = 1
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
    bool refractionOn;
    bool glossyOn;
    bool subsurfaceScatteringOn;
    float ssSigma_s;
    simd_float3 ssSigma_a;
    float ssEta;
    float ssG;
    bool directLightingOn;
    int directLightingSamples;
    bool importanceSamplingOn;
    bool glassTransmittanceOn;
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


//RenderSettings DEFAULT_SETTINGS = RenderSettings(.diffuseOn: true, mirrorOn: true, refractionOn: true, glossyOn: true,subsurfaceScatteringOn: true, ssSigma_s: 1.0,ssSigma_a: simd_float3(0.01, 0.1, 1.0), ssEta: 1, ssG: 0, directLightingOn: true, importanceSamplingOn: true, glassTransmittanceOn: true, russianRoulette: 0.9,samplesPerPixel: 16, toneMap: simd_float3(0.299, 0.587, 0.114), gammaCorrection: 0.4,imageWidth: 512, imageHeight: 512);

#define DEFAULT_SETTINGS {true, true, true,  true,true,  1.0,simd_float3(0.01, 0.1, 1.0), 1, 0, true, true, true, 0.9,16, simd_float3(0.299, 0.587, 0.114), 0.4, 512, 512}

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
