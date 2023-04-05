//
//  Mesh.swift
//  Phone-ton
//
//  Created by Jed Fox on 2023-04-05.
//

import Foundation

class Mesh {
    let vertices: [SIMD3<Double>]
    let rawFaces: [SIMD3<Int>]

    init?(contentsOf url: URL?) {
        guard let url, let loader = TinyObjLoader(contentsOf: url) else {
            return nil
        }
        self.vertices = Array(UnsafeBufferPointer(start: loader.vertices, count: loader.vertexCount))
        self.rawFaces = Array(UnsafeBufferPointer(start: loader.faces, count: loader.faceCount))
    }
}
