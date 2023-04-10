#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface TinyObjLoader : NSObject

- (nullable instancetype)initWithContentsOfURL:(NSURL *)url;

@property (readonly) NSInteger vertexCount;
@property (readonly) NSInteger faceCount;

@property (readonly) const simd_double3 *vertices;
@property (readonly) const simd_long3 *faces;

@end

NS_ASSUME_NONNULL_END
