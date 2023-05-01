import Foundation
import Metal

class Scene {
    let vertexPositionsBuffer: MTLBuffer // Float
    let normalAnglesBuffer: MTLBuffer // Float
    let materialIndexBuffer: MTLBuffer // uint16
    let faceVertexIndexBuffer: MTLBuffer // uint16
    let vertexNormalIndexBuffer: MTLBuffer // uint16
    let materialBuffer: MTLBuffer // Material
    let normalBuffer: MTLBuffer // Float
    let emissivesBuffer: MTLBuffer // uint16
    let accelerationStructure: MTLAccelerationStructure

    let emissivesCount: Int32

    init?(contentsOf url: URL, for device: MTLDevice, commandQueue: MTLCommandQueue) async {
        guard let loader = await runBlocking({ TinyObjLoader(contentsOf: url) }) else { return nil }

        let materials = loader.materials.map(RawMaterial.init)
        guard
            let vertexBuffer = device.makeBuffer(array: loader.vertices, count: loader.vertexCount),
            let normalAnglesBuffer = device.makeBuffer(array: loader.normals, count: loader.normalCount),
            let materialIdBuffer = device.makeBuffer(array: loader.materialIds, count: loader.materialIdCount),
            let faceVertexBuffer = device.makeBuffer(array: loader.faceVertices, count: loader.faceCount * 3),
            let vertexNormalIndexBuffer = device.makeBuffer(array: loader.vertexNormals, count: loader.faceCount * 3),
            let materialBuffer = materials.withUnsafeBytes({ ptr in
                device.makeBuffer(bytes: ptr.baseAddress!, length: ptr.count, options: [])
            }),
            let emissivesBuffer = device.makeBuffer(array: loader.emissiveFaces, count: loader.emissiveFaceCount)
        else { return nil }

        self.emissivesCount = Int32(loader.emissiveFaceCount)

        vertexBuffer.label = "Vertex Positions"
        self.vertexPositionsBuffer = vertexBuffer
        normalAnglesBuffer.label = "Vertex Normals"
        self.normalAnglesBuffer = normalAnglesBuffer
        materialIdBuffer.label = "Face Material IDs"
        self.materialIndexBuffer = materialIdBuffer
        faceVertexBuffer.label = "Face Vertices"
        self.faceVertexIndexBuffer = faceVertexBuffer
        vertexNormalIndexBuffer.label = "Vertex Normal IDs"
        self.vertexNormalIndexBuffer = vertexNormalIndexBuffer
        materialBuffer.label = "Materials"
        self.materialBuffer = materialBuffer
        emissivesBuffer.label = "Emissive Faces"
        self.emissivesBuffer = emissivesBuffer

        let geometryDescriptor = MTLAccelerationStructureTriangleGeometryDescriptor()
        geometryDescriptor.indexBuffer = faceVertexBuffer
        geometryDescriptor.vertexBuffer = vertexBuffer
        geometryDescriptor.indexType = .uint16
        geometryDescriptor.opaque = true
        geometryDescriptor.triangleCount = loader.faceCount

        let faces = loader.faceCount
        guard
            let normalBuffer = device.makeBuffer(length: MemoryLayout<Float>.stride * faces * 3, options: [])
        else { return nil }
        normalBuffer.label = "Face Normals"
        self.normalBuffer = normalBuffer
        var result = UnsafeMutableRawBufferPointer(start: normalBuffer.contents(), count: normalBuffer.length)
            .initializeMemory(as: Float.self, from: (0..<faces).flatMap { i in
                let normal = loader.normal(forFace: UInt16(i))
                return [normal.x, normal.y, normal.z]
            })
        assert(result.unwritten.next() == nil)

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
            // Use MTLResourceStorageModePrivate for the best performance because the CPU
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

        await runBlocking {
            commandBuffer.waitUntilCompleted()
        }

        let compactedSize = compactedSizeBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee

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

extension MTLDevice {
    func makeBuffer<T>(array bytes: UnsafePointer<T>, count: Int) -> MTLBuffer? {
        let length = MemoryLayout<T>.size * max(count, 1)
        if count == 0 {
            return makeBuffer(length: length, options: [])
        }
        return makeBuffer(bytes: bytes, length: length)
    }
}

func runBlocking<T>(qos: DispatchQoS.QoSClass = .userInitiated, _ cb: @escaping () -> T) async -> T {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: qos).async {
            continuation.resume(returning: cb())
        }
    }
}

private extension RawMaterial {
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
