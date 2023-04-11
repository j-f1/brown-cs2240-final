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
    let normalBuffer: MTLBuffer // SIMD3<Float>
    let materialIdBuffer: MTLBuffer // uint16
    let faceBuffer: MTLBuffer // int
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
            let vertexBuffer = device.makeBuffer(bytes: loader.vertices, length: loader.vertexCount * MemoryLayout<SIMD3<Float>>.stride, options: options),
            let normalBuffer = device.makeBuffer(bytes: loader.normals, length: loader.normalCount * MemoryLayout<SIMD3<Float>>.stride, options: options),
            let materialIdBuffer = device.makeBuffer(bytes: loader.materialIds, length: loader.materialIdCount * MemoryLayout<ushort>.stride, options: options),
            let faceBuffer = device.makeBuffer(bytes: loader.faces, length: loader.faceCount * MemoryLayout<SIMD3<ushort>>.stride, options: options),
            let materialBuffer = materials.withUnsafeBytes({ ptr in
                device.makeBuffer(bytes: ptr.baseAddress!, length: ptr.count, options: options)
            })
        else { return nil }

        self.vertexBuffer = vertexBuffer
        self.normalBuffer = normalBuffer
        self.materialIdBuffer = materialIdBuffer
        self.faceBuffer = faceBuffer
        self.materialBuffer = materialBuffer
    }

    var geometryDescriptor: MTLAccelerationStructureTriangleGeometryDescriptor {
        let descriptor = MTLAccelerationStructureTriangleGeometryDescriptor()
        descriptor.indexBuffer = faceBuffer
        descriptor.indexType = .uint16

        descriptor.vertexBuffer = vertexBuffer
        descriptor.vertexStride = MemoryLayout<SIMD3<Float>>.stride
        return descriptor
    }

    var resources: [MTLResource] {
        [faceBuffer, normalBuffer, materialIdBuffer]
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
