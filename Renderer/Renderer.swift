// “Our” platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

class Renderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let randomTexture: MTLTexture
    var uniformBuffer: MTLBuffer
    var pipelineState: MTLComputePipelineState
    var scene: Scene

    init?(metalKitView: MTKView, modelURL: URL?) {
        self.device = metalKitView.device!
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        guard let buffer = self.device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: []) else { return nil }
        uniformBuffer = buffer
        
        self.uniformBuffer.label = "UniformBuffer"

        metalKitView.colorPixelFormat = .bgr10_xr_srgb
        #if os(macOS)
        metalKitView.colorspace = CGColorSpace(name: CGColorSpace.displayP3)
        #endif
        metalKitView.sampleCount = 1

        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        guard let mesh = Scene(contentsOf: modelURL, for: device, commandQueue: commandQueue) else { return nil }
        self.scene = mesh

        guard let randomTexture = Renderer.buildRandomTexture(size: metalKitView.drawableSize, on: device) else { return nil }
        self.randomTexture = randomTexture

        super.init()
    }

    class func buildRandomTexture(size: CGSize, on device: MTLDevice) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .rgba32Float
        textureDescriptor.textureType = .type2D
        textureDescriptor.width = Int(size.width)
        textureDescriptor.height = Int(size.height)

        // Create a texture that contains a random integer value for each pixel. The raytracer
        // uses these values to decorrelate pixels while drawing pseudorandom numbers from the
        // Halton sequence.
        textureDescriptor.pixelFormat = .r32Uint
        textureDescriptor.usage = .shaderRead

        guard let randomTexture = device.makeTexture(descriptor: textureDescriptor) else { return nil }
        let randomValues = [UInt32](repeating: 0, count: randomTexture.width * randomTexture.height).map { _ in UInt32.random(in: .min ... .max) }
        randomTexture.replace(
            region: .init(origin: .zero, size: .init(width: randomTexture.width, height: randomTexture.height, depth: 1)),
            mipmapLevel: 0,
            withBytes: randomValues,
            bytesPerRow: MemoryLayout<UInt32>.size * randomTexture.width
        )
        return randomTexture
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice) throws -> MTLComputePipelineState {
        /// Build a render state pipeline object
        let library = device.makeDefaultLibrary()
        let pipelineDescriptor = MTLComputePipelineDescriptor()
        pipelineDescriptor.label = "ComputePipeline"
        pipelineDescriptor.computeFunction = library?.makeFunction(name: "raytracingKernel")
        pipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        return try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: []).0
    }

    func draw(in view: MTKView) {
        /// Per frame updates hare

        if let commandBuffer = commandQueue.makeCommandBuffer() {
            let uniforms = UnsafeMutableRawPointer(uniformBuffer.contents()).bindMemory(to: Uniforms.self, capacity: 1)
            uniforms[0].camera = Camera(
                position: .init(x: 0, y: 1, z: 3.6),
                right: .init(x: 1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: -1)
            )

            let width = Int(view.drawableSize.width)
            let height = Int(view.drawableSize.height)
            uniforms[0].width = UInt32(width)
            uniforms[0].height = UInt32(height)

            if let computeEncoder = commandBuffer.makeComputeCommandEncoder(), let drawable = view.currentDrawable {
                /// Final pass rendering code here
                computeEncoder.label = "Primary Compute Encoder"
                computeEncoder.pushDebugGroup("Setup")
                computeEncoder.setComputePipelineState(pipelineState)
                computeEncoder[.uniforms] = uniformBuffer
                computeEncoder[.random] = randomTexture
                computeEncoder[.dst] = drawable.texture
                computeEncoder[.vertexPositions] = scene.vertexBuffer
                computeEncoder[.faceVertices] = scene.faceVertexBuffer
                computeEncoder[.faceMaterials] = scene.materialIdBuffer
                computeEncoder[.materials] = scene.materialBuffer
                computeEncoder[.intersectorObjects] = scene.instanceDescriptors
                computeEncoder[.intersector] = scene.accelerationStructure
                computeEncoder.popDebugGroup()

                // Launch a rectangular grid of threads on the GPU to perform ray tracing, with one thread per
                // pixel. The number of threads needs to be aligned to a multiple of the threadgroup size,
                // because earlier, when it created the pipeline objects, it declared that the pipeline
                // would always use a threadgroup size that's a multiple of the thread execution width
                // (SIMD group size). An 8x8 threadgroup is a safe threadgroup size and small enough to be
                // supported on most devices. A more advanced app would choose the threadgroup size dynamically.
                let threadsPerThreadgroup = MTLSize(width: 8, height: 8, depth: 1)
                let threadgroups = MTLSize(
                    width: (width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
                    height: (height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
                    depth: 1
                )
                computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)

                computeEncoder.endEncoding()
                commandBuffer.present(drawable)
            }
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
    }
}

private extension MTLComputeCommandEncoder {
    subscript(name: TextureIndex) -> MTLTexture? {
        get { nil }
        set { setTexture(newValue, index: name.rawValue) }
    }

    subscript(name: BufferIndex) -> MTLAccelerationStructure? {
        get { nil }
        set { setAccelerationStructure(newValue, bufferIndex: name.rawValue) }
    }

    subscript(name: BufferIndex) -> MTLBuffer? {
        get { nil }
        set { setBuffer(newValue, offset: 0, index: name.rawValue) }
    }
}

extension MTLOrigin {
    static let zero = MTLOrigin(x: 0, y: 0, z: 0)
}
