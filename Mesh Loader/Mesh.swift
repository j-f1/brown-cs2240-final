//
//  Mesh.swift
//  Phone-ton
//
//  Created by Jed Fox on 2023-04-05.
//

import Foundation

class Mesh {
    private let vertices: [SIMD3<Double>]
    private let normals: [SIMD3<Double>]
    private let materialIds: [Int]
    private let faces: [SIMD3<Int>]
    private let materials: [Material]

    init?(contentsOf url: URL?) {
        guard let url, let loader = TinyObjLoader(contentsOf: url) else {
            return nil
        }
        self.vertices = Array(UnsafeBufferPointer(start: loader.vertices, count: loader.vertexCount))
        self.normals = Array(UnsafeBufferPointer(start: loader.normals, count: loader.normalCount))
        self.materialIds = Array(UnsafeBufferPointer(start: loader.materialIds, count: loader.materialIdCount))
        self.faces = Array(UnsafeBufferPointer(start: loader.faces, count: loader.faceCount))
        self.materials = loader.materials.map(Material.init)
    }
}

private extension Material {
    init(_ mat: TinyObjMaterial) {
        self.init(
            diffuse: mat.diffuse,
            specular: mat.specular,
            transmittance: mat.transmittance,
            emission: mat.emission,
            shininess: mat.shininess,
            ior: mat.ior,
            illum: mat.illum
        )
    }
}
