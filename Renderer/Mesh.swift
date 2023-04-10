import Foundation
import ModelIO
import Metal

#if os(iOS)
private let managedBufferStorageMode = MTLStorageMode.shared
#else
private let managedBufferStorageMode = MTLStorageMode.managed
#endif

struct Mesh {
    let device: MTLDevice

    let indices: [UInt16]
    let vertices: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let colors: [SIMD3<Float>]
    let triangles: [Triangle]

    init(mesh: MDLMesh, device: MTLDevice) {
        indices = mesh.vertexDescriptor.attributeNamed(MDLVertexAttributePosition)
    }
}
