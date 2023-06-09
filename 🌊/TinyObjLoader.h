#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@class TinyObjMaterial;

@interface TinyObjLoader : NSObject

- (nullable instancetype)initWithContentsOfURL:(NSURL *)url;

@property (readonly) NSInteger vertexCount;
@property (readonly) NSInteger normalCount;

@property (readonly) NSInteger faceCount;

@property (readonly) NSInteger materialIdCount;
@property (readonly) NSInteger emissiveFaceCount;

@property (readonly) const float *vertices; // [x, y, z, x, y, z, ...]
@property (readonly) const float *normals; // [x, y, z, x, y, z, ...]

@property (readonly) const uint16_t *faceVertices; // [v1, v2, v3, v1, v2, v3, ...]
@property (readonly) const uint16_t *vertexNormals; // [v1, v2, v3, v1, v2, v3, ...]

@property (readonly) const uint16_t *materialIds; // per-face array
@property (readonly) const uint16_t *emissiveFaces; // array of face IDs

@property (readonly) NSArray<TinyObjMaterial *> *materials;

- (simd_float3)normalForFace:(uint16_t)face;

@end

@interface TinyObjMaterial : NSObject

@property (strong, nonatomic) NSString *name;
@property simd_float3 diffuse;
@property simd_float3 specular;
@property simd_float3 transmittance;
@property simd_float3 emission;
@property float shininess;
@property float ior;
@property int illum;

@end

NS_ASSUME_NONNULL_END
