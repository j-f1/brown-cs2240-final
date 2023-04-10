#import <vector>

#import "TinyObjLoader.h"

#define TINYOBJLOADER_USE_DOUBLE
#define TINYOBJLOADER_IMPLEMENTATION
#include "tiny_obj_loader.h"

simd::float3 to_simd(const tinyobj::real_t val[3]) {
    return {float(val[0]), float(val[1]), float(val[2])};
}

@implementation TinyObjLoader {
    std::vector<simd::double3> _vertices;
    std::vector<simd::double3> _normals;
    std::vector<long> _materialIds;
    std::vector<simd::long3> _faces;
}

@dynamic vertexCount, normalCount, materialIdCount, faceCount;
@dynamic vertices, normals, materialIds, faces;

- (instancetype)initWithContentsOfURL:(NSURL *)url {
    if (!url.isFileURL) return nil;

    std::string dirname = std::string(url.URLByDeletingLastPathComponent.fileSystemRepresentation) + "/";

    tinyobj::attrib_t attrib;
    std::vector<tinyobj::shape_t> shapes;
    std::vector<tinyobj::material_t> materials;
    std::string err;
    bool ok = tinyobj::LoadObj(&attrib, &shapes, &materials, &err, url.fileSystemRepresentation, dirname.c_str(), true);
    if (!ok) {
        NSLog(@"Failed to load %@: %s", url, err.c_str());
        return nil;
    }

    if (!(self = [super init])) {
        return nil;
    }

    _vertices = {};
    _normals = {};
    _materialIds = {};
    _faces = {};

    _materials = [NSMutableArray arrayWithCapacity:materials.size()];

    int nFaces = 0;
    for(size_t s = 0; s < shapes.size(); s++) {
        nFaces += shapes[s].mesh.num_face_vertices.size();
    }
    _faces.reserve(nFaces);

    for (const tinyobj::shape_t &shape : shapes) {
        size_t index_offset = 0;
        for(size_t f = 0; f < shape.mesh.num_face_vertices.size(); f++) {
            unsigned int fv = shape.mesh.num_face_vertices[f];

            simd::long3 face;
            for(size_t v = 0; v < fv; v++) {
                tinyobj::index_t idx = shape.mesh.indices[index_offset + v];
                face[v] = idx.vertex_index;
            }
            index_offset += fv;

            _faces.push_back(face);
            _materialIds.push_back(shape.mesh.material_ids[f]);
        }
    }

    _vertices.reserve(attrib.vertices.size() / 3);
    for (size_t i = 0; i < attrib.vertices.size(); i += 3) {
        simd::double3 vertex;
        vertex[0] = attrib.vertices[i];
        vertex[1] = attrib.vertices[i + 1];
        vertex[2] = attrib.vertices[i + 2];
        _vertices.push_back(vertex);
    }

    _normals.reserve(attrib.normals.size() / 3);
    for (size_t i = 0; i < attrib.normals.size(); i += 3) {
        simd::double3 normal;
        normal[0] = attrib.normals[i];
        normal[1] = attrib.normals[i + 1];
        normal[2] = attrib.normals[i + 2];
        _normals.push_back(normal);
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

    NSLog(@"Loaded %lu faces and %lu vertices from %@", _faces.size(), _vertices.size(), url);
    return self;
}

- (NSInteger)vertexCount {
    return _vertices.size();
}

- (NSInteger)normalCount {
    return _normals.size();
}

- (NSInteger)materialIdCount {
    return _materialIds.size();
}

- (NSInteger)faceCount {
    return _faces.size();
}

- (const simd_double3 *)vertices {
    return _vertices.data();
}

- (const simd_double3 *)normals {
    return _normals.data();
}

- (const long *)materialIds {
    return _materialIds.data();
}

- (const simd_long3 *)faces {
    return _faces.data();
}

@end

@implementation TinyObjMaterial
@end
