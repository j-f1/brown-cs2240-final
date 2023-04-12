#import <vector>

#import "TinyObjLoader.h"

//#define TINYOBJLOADER_USE_DOUBLE
#define TINYOBJLOADER_IMPLEMENTATION
#include "tiny_obj_loader.h"

simd::float3 to_simd(const tinyobj::real_t val[3]) {
    return {float(val[0]), float(val[1]), float(val[2])};
}

@implementation TinyObjLoader {
    tinyobj::attrib_t attrib;
    std::vector<tinyobj::shape_t> shapes;
    std::vector<tinyobj::material_t> materials;

    std::vector<uint16> _materialIds;
    std::vector<uint16> _faceVertices;
    std::vector<uint16> _faceNormals;
}

@dynamic vertexCount, normalCount, materialIdCount;
@dynamic vertices, normals, faceVertices, faceNormals, materialIds;
@synthesize materials = _materials;

- (instancetype)initWithContentsOfURL:(NSURL *)url {
    if (!url.isFileURL) return nil;

    std::string dirname = std::string(url.URLByDeletingLastPathComponent.fileSystemRepresentation) + "/";

    std::string err;
    bool ok = tinyobj::LoadObj(&attrib, &shapes, &materials, &err, url.fileSystemRepresentation, dirname.c_str(), true);
    if (!ok) {
        NSLog(@"Failed to load %@: %s", url, err.c_str());
        return nil;
    }

    if (!(self = [super init])) {
        return nil;
    }

    _materialIds = {};
    _faceVertices = {};
    _faceNormals = {};

    _materials = [NSMutableArray arrayWithCapacity:materials.size()];

    _faceCount = 0;
    for (const tinyobj::shape_t &shape : shapes) {
        _faceCount += shape.mesh.num_face_vertices.size();
        #ifndef NDEBUG
        for (const auto &n : shape.mesh.num_face_vertices) {
            assert(n == 3);
        }
        #endif
    }
    _faceVertices.reserve(_faceCount * 3);
    _faceNormals.reserve(_faceCount * 3);

    for (const tinyobj::shape_t &shape : shapes) {
        size_t index_offset = 0;
        for(size_t f = 0; f < shape.mesh.num_face_vertices.size(); f++) {
            unsigned fv = shape.mesh.num_face_vertices[f];
            if (fv != 3) abort();

            for(size_t v = 0; v < fv; v++) {
                tinyobj::index_t idx = shape.mesh.indices[index_offset + v];
                if (idx.vertex_index == ((int)(uint16_t)-1)) abort();
                _faceVertices.push_back(idx.vertex_index);
                if (idx.normal_index == ((int)(uint16_t)-1)) abort();
                _faceNormals.push_back(idx.normal_index);
            }
            index_offset += fv;

            _materialIds.push_back(shape.mesh.material_ids[f]);
        }
    }

    for (const tinyobj::material_t &mat : materials) {
        TinyObjMaterial *material = [TinyObjMaterial new];
        material.name = [NSString stringWithCString:mat.name.c_str() encoding:NSUTF8StringEncoding];
        material.diffuse = to_simd(mat.diffuse);
        material.specular = to_simd(mat.specular);
        material.transmittance = to_simd(mat.transmittance);
        material.emission = to_simd(mat.emission);
        material.shininess = mat.shininess;
        material.ior = mat.ior;
        material.illum = mat.illum;
        [(NSMutableArray *)_materials addObject:material];
    }

    NSLog(@"Loaded %lu faces and %lu vertices from %@", _faceVertices.size() / 3, self.vertexCount, url);
    return self;
}

- (NSInteger)vertexCount {
    return attrib.vertices.size();
}

- (NSInteger)normalCount {
    return attrib.normals.size();
}

- (NSInteger)materialIdCount {
    return _materialIds.size();
}

- (const float *)vertices {
    return attrib.vertices.data();
}

- (const float *)normals {
    return attrib.normals.data();
}

- (const uint16 *)materialIds {
    return _materialIds.data();
}

- (const uint16 *)faceVertices {
    return _faceVertices.data();
}

- (const uint16 *)faceNormals {
    return _faceNormals.data();
}

@end

@implementation TinyObjMaterial
@end
