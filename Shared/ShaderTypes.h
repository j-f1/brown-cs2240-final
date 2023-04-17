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
    BufferIndexMeshPositions = 0,
    BufferIndexMeshGenerics  = 1,
    BufferIndexUniforms      = 2
};

typedef NS_ENUM(EnumBackingType, VertexAttribute)
{
    VertexAttributePosition  = 0,
    VertexAttributeTexcoord  = 1,
};

typedef NS_ENUM(EnumBackingType, TextureIndex)
{
    TextureIndexColor    = 0,
};

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
} Uniforms;

typedef struct
{
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
    bool importanceSamplingOn;
    bool glassTransmittanceOn;
    float russianRoulette;
    int samplesPerPixel;
    simd_float3 toneMap;
    float gammaCorrection;
    int imageWidth;
    int imageHeight;
} RenderSettings;

//RenderSettings DEFAULT_SETTINGS = RenderSettings(.diffuseOn: true, mirrorOn: true, refractionOn: true, glossyOn: true,subsurfaceScatteringOn: true, ssSigma_s: 1.0,ssSigma_a: simd_float3(0.01, 0.1, 1.0), ssEta: 1, ssG: 0, directLightingOn: true, importanceSamplingOn: true, glassTransmittanceOn: true, russianRoulette: 0.9,samplesPerPixel: 16, toneMap: simd_float3(0.299, 0.587, 0.114), gammaCorrection: 0.4,imageWidth: 512, imageHeight: 512);

#define DEFAULT_SETTINGS {true, true, true,  true,true,  1.0,simd_float3(0.01, 0.1, 1.0), 1, 0, true, true, true, 0.9,16, simd_float3(0.299, 0.587, 0.114), 0.4, 512, 512}

#endif /* ShaderTypes_h */


