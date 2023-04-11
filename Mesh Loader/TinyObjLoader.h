#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@class TinyObjMaterial;

@interface TinyObjLoader : NSObject

- (nullable instancetype)initWithContentsOfURL:(NSURL *)url;

@property (readonly) NSInteger vertexCount;
@property (readonly) NSInteger normalCount;
@property (readonly) NSInteger materialIdCount;
@property (readonly) NSInteger faceCount;

@property (readonly) const simd_float3 *vertices;
@property (readonly) const simd_float3 *normals;
@property (readonly) const ushort *materialIds;
@property (readonly) const simd_ushort3 *faces;

@property (readonly) NSArray<TinyObjMaterial *> *materials;

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
