import Foundation
import Metal

class Scene {
    let vertexBuffer: MTLBuffer // Float
    let materialIdBuffer: MTLBuffer // uint16
    let faceVertexBuffer: MTLBuffer // uint16
    let materialBuffer: MTLBuffer // Material
    let accelerationStructure: MTLAccelerationStructure
    let instanceDescriptors: MTLBuffer // MTLAccelerationStructureInstanceDescriptor

    init?(contentsOf url: URL?, for device: MTLDevice, commandQueue: MTLCommandQueue) {
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

        vertexBuffer.label = "Vertex Positions"
        self.vertexBuffer = vertexBuffer
        materialIdBuffer.label = "Face Material IDs"
        self.materialIdBuffer = materialIdBuffer
        faceVertexBuffer.label = "Face Vertices"
        self.faceVertexBuffer = faceVertexBuffer
        materialBuffer.label = "Materials"
        self.materialBuffer = materialBuffer

        let geometryDescriptor = MTLAccelerationStructureTriangleGeometryDescriptor()
        geometryDescriptor.indexBuffer = faceVertexBuffer
        geometryDescriptor.vertexBuffer = vertexBuffer
        geometryDescriptor.indexType = .uint16
        geometryDescriptor.triangleCount = loader.faceCount

        let faces = loader.faceCount
        guard
            let instanceDescriptors = device.makeBuffer(length: MemoryLayout<MTLAccelerationStructureInstanceDescriptor>.size * faces, options: options)
        else { return nil }
        instanceDescriptors.label = "Instance Descriptors"
        self.instanceDescriptors = instanceDescriptors
        let buf = UnsafeMutableBufferPointer(start: instanceDescriptors.contents().assumingMemoryBound(to: MTLAccelerationStructureInstanceDescriptor.self), count: faces)
        for i in 0..<faces {
            buf[i] = .init(
                transformationMatrix: .init(),
                options: .opaque,
                mask: 0,
                intersectionFunctionTableOffset: 0,
                accelerationStructureIndex: UInt32(i)
            )
        }

        let descriptor = MTLPrimitiveAccelerationStructureDescriptor()
        descriptor.geometryDescriptors = [geometryDescriptor]

        // Query for the sizes needed to store and build the acceleration structure.
        let accelSizes = device.accelerationStructureSizes(descriptor: descriptor)

        guard
            // Allocate an acceleration structure large enough for this descriptor. This method
            // doesn't actually build the acceleration structure, but rather allocates memory.
            let accelerationStructure = device.makeAccelerationStructure(size: accelSizes.accelerationStructureSize)
        else { return nil }

        guard
            // Allocate scratch space Metal uses to build the acceleration structure.
            // Use MTLResourceStorageModePrivate for the best performance because the sample
            // doesn't need access to buffer's contents.
            let scratchBuffer = device.makeBuffer(length: accelSizes.buildScratchBufferSize, options: .storageModePrivate),
            // Create a command buffer that performs the acceleration structure build.
            let commandBuffer = commandQueue.makeCommandBuffer(),
            // Create an acceleration structure command encoder.
            let commandEncoder = commandBuffer.makeAccelerationStructureCommandEncoder(),
            // Allocate a buffer for Metal to write the compacted accelerated structure's size into.
            let compactedSizeBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size, options: .storageModeShared)
        else { return nil }

        commandEncoder.label = "Make Acceleration Structure"

        scratchBuffer.label = "Scratch Buffer"
        compactedSizeBuffer.label = "Compacted Size Buffer"

        // Schedule the actual acceleration structure build.
        commandEncoder.build(
            accelerationStructure: accelerationStructure,
            descriptor: descriptor,
            scratchBuffer: scratchBuffer,
            scratchBufferOffset: 0
        )

        // Compute and write the compacted acceleration structure size into the buffer. You
        // must already have a built acceleration structure because Metal determines the compacted
        // size based on the final size of the acceleration structure. Compacting an acceleration
        // structure can potentially reclaim significant amounts of memory because Metal must
        // create the initial structure using a conservative approach.
        commandEncoder.writeCompactedSize(
            accelerationStructure: accelerationStructure,
            buffer: compactedSizeBuffer,
            offset: 0
        )

        // End encoding, and commit the command buffer so the GPU can start building the
        // acceleration structure.
        commandEncoder.endEncoding()
        commandBuffer.commit()

        // The sample waits for Metal to finish executing the command buffer so that it can
        // read back the compacted size.

        // Note: Don't wait for Metal to finish executing the command buffer if you aren't compacting
        // the acceleration structure, as doing so requires CPU/GPU synchronization. You don't have
        // to compact acceleration structures, but do so when creating large static acceleration
        // structures, such as static scene geometry. Avoid compacting acceleration structures that
        // you rebuild every frame, as the synchronization cost may be significant.

        commandBuffer.waitUntilCompleted()

        let compactedSize = compactedSizeBuffer.contents().assumingMemoryBound(to: Int.self).pointee

        guard
            // Allocate a smaller acceleration structure based on the returned size.
            let compactedAccelerationStructure = device.makeAccelerationStructure(size: Int(compactedSize)),

            // Create another command buffer and encoder.
            let commandBuffer2 = commandQueue.makeCommandBuffer(),
            let commandEncoder2 = commandBuffer2.makeAccelerationStructureCommandEncoder()
        else { return nil }

        self.accelerationStructure = compactedAccelerationStructure

        // Encode the command to copy and compact the acceleration structure into the
        // smaller acceleration structure.
        commandEncoder2.copyAndCompact(
            sourceAccelerationStructure: accelerationStructure,
            destinationAccelerationStructure: compactedAccelerationStructure
        )

        // End encoding and commit the command buffer. You don't need to wait for Metal to finish
        // executing this command buffer as long as you synchronize any ray-intersection work
        // to run after this command buffer completes. The sample relies on Metal's default
        // dependency tracking on resources to automatically synchronize access to the new
        // compacted acceleration structure.
        commandEncoder2.endEncoding()
        commandBuffer2.commit()
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
