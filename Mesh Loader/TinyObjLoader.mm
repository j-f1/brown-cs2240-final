#import <vector>

#import "TinyObjLoader.h"

#define TINYOBJLOADER_USE_DOUBLE
#define TINYOBJLOADER_IMPLEMENTATION
#include "tiny_obj_loader.h"

@implementation TinyObjLoader {
    std::vector<simd::double3> _vertices;
    std::vector<simd::long3> _faces;
}

@dynamic vertexCount, faceCount;
@dynamic vertices, faces;

- (instancetype)initWithContentsOfURL:(NSURL *)url {
    if (!url.isFileURL) return nil;

    tinyobj::attrib_t attrib;
    std::vector<tinyobj::shape_t> shapes;
    std::string err;
    bool ok = tinyobj::LoadObj(&attrib, &shapes, nullptr, &err, url.fileSystemRepresentation);
    if (!ok) {
        NSLog(@"Failed to load %@: %s", url, err.c_str());
        return nil;
    }

    if (!(self = [super init])) {
        return nil;
    }

    _vertices = {};
    _faces = {};

    int nFaces = 0;
    for(size_t s = 0; s < shapes.size(); s++) {
        nFaces += shapes[s].mesh.num_face_vertices.size();
    }
    _faces.reserve(nFaces);

    for(size_t s = 0; s < shapes.size(); s++) {
        size_t index_offset = 0;
        for(size_t f = 0; f < shapes[s].mesh.num_face_vertices.size(); f++) {
            unsigned int fv = shapes[s].mesh.num_face_vertices[f];

            simd::long3 face;
            for(size_t v = 0; v < fv; v++) {
                tinyobj::index_t idx = shapes[s].mesh.indices[index_offset + v];

                face[v] = idx.vertex_index;

            }
            _faces.push_back(face);

            index_offset += fv;
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

    NSLog(@"Loaded %lu faces and %lu vertices from %@", _faces.size(), _vertices.size(), url);
    return self;
}

- (NSInteger)vertexCount {
    return _vertices.size();
}

- (NSInteger)faceCount {
    return _faces.size();
}

- (const simd_double3 *)vertices {
    return _vertices.data();
}

- (const simd_long3 *)faces {
    return _faces.data();
}

@end
