//
//  Mesh.swift
//  Phone-ton
//
//  Created by Jed Fox on 2023-04-05.
//

import Foundation
import Metal

class Mesh {
    let vertexBuffer: MTLBuffer // SIMD3<Float>
    let materialIdBuffer: MTLBuffer // uint16
    let faceVertexBuffer: MTLBuffer // uint16
    let materialBuffer: MTLBuffer // Material

    init?(contentsOf url: URL?, for device: MTLDevice) {
        guard let url, let loader = TinyObjLoader(contentsOf: url) else {
            return nil
        }
        #if os(iOS)
        let options = MTLResourceOptions.storageModeShared
        #else
        let options = MTLResourceOptions.storageModeManaged
        #endif

        let materials = loader.materials.map(Material.init)
        guard
            let vertexBuffer = device.makeBuffer(bytes: loader.vertices, length: loader.vertexCount * MemoryLayout<Float>.stride, options: options),
            let materialIdBuffer = device.makeBuffer(bytes: loader.materialIds, length: loader.materialIdCount * MemoryLayout<UInt16>.stride, options: options),
            let faceVertexBuffer = device.makeBuffer(bytes: loader.faceVertices, length: loader.faceCount * 3 * MemoryLayout<UInt16>.stride, options: options),
            let materialBuffer = materials.withUnsafeBytes({ ptr in
                device.makeBuffer(bytes: ptr.baseAddress!, length: ptr.count, options: options)
            })
        else { return nil }

        self.vertexBuffer = vertexBuffer
        self.materialIdBuffer = materialIdBuffer
        self.faceVertexBuffer = faceVertexBuffer
        self.materialBuffer = materialBuffer
    }

    var geometryDescriptor: MTLAccelerationStructureTriangleGeometryDescriptor {
        let descriptor = MTLAccelerationStructureTriangleGeometryDescriptor()
        descriptor.indexBuffer = faceVertexBuffer
        descriptor.vertexBuffer = vertexBuffer
        descriptor.indexType = .uint16
        return descriptor
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
