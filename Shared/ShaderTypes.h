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

//SORRY JED JUST LEAVING THIS HERE SO I HAVE A REFERENCE FOR WHEN I FIX THIS
//typedef struct
//{
//    bool diffuseOn = true;
//    bool mirrorOn = true;
//    bool refractionOn = true;
//    bool glossyOn = true;
//    bool subsurfaceScatteringOn = true;
//    float ssSigma_s = 1.0;
//    simd_float3 ssSigma_a = {0.01, 0.1, 1.0};
//    float ssEta = 1;
//    float ssG = 0;
//    bool directLightingOn = true;
//    bool importanceSamplingOn = true;
//    bool glassTransmittanceOn = true;
//    float russianRoulette = 0.9;
//    int samplesPerPixel = 16;
//    simd_float3 toneMap = {0.299, 0.587, 0.114};
//    float gammaCorrection = 0.4;
//    int imageWidth = 512;
//    int imageHeight = 512;
//} RenderSettings;

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

#endif /* ShaderTypes_h */

