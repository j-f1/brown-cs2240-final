// “Our” platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

let maxBuffersInFlight = 3

enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let randomTexture: MTLTexture
    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLComputePipelineState
    var depthState: MTLDepthStencilState
    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    
    var uniformBufferIndex = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>
    
    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    var rotation: Float = 0
    
    var mesh: Mesh
    
    init?(metalKitView: MTKView, modelURL: URL?) {
        self.device = metalKitView.device!
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let buffer = self.device.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        dynamicUniformBuffer = buffer
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1

        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor:depthStateDescriptor) else { return nil }
        depthState = state

        guard let mesh = Mesh(contentsOf: modelURL, for: device, commandQueue: commandQueue) else { return nil }
        self.mesh = mesh

        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .rgba32Float
        textureDescriptor.textureType = .type2D
        textureDescriptor.width = Int(metalKitView.drawableSize.width)
        textureDescriptor.height = Int(metalKitView.drawableSize.height)

        // Create a texture that contains a random integer value for each pixel. The sample
        // uses these values to decorrelate pixels while drawing pseudorandom numbers from the
        // Halton sequence.
        textureDescriptor.pixelFormat = .r32Uint
        textureDescriptor.usage = .shaderRead

        // The sample initializes the data in the texture, so it can't be private.
        #if !TARGET_OS_IPHONE
        textureDescriptor.storageMode = .managed
        #else
        textureDescriptor.storageMode = .shared
        #endif

        guard let randomTexture = device.makeTexture(descriptor: textureDescriptor) else { return nil }
        self.randomTexture = randomTexture
        let randomValues = [UInt32](repeating: 0, count: randomTexture.width * randomTexture.height).map { _ in UInt32.random(in: .min ... .max) }
        randomTexture.replace(
            region: .init(origin: .zero, size: .init(width: randomTexture.width, height: randomTexture.height, depth: 1)),
            mipmapLevel: 0,
            withBytes: randomValues,
            bytesPerRow: MemoryLayout<UInt32>.size * randomTexture.width
        )

        super.init()
        
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice) throws -> MTLComputePipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()


        let constants = MTLFunctionConstantValues()
        // The first constant is the stride between entries in the resource buffer. The sample
        // uses this stride to allow intersection functions to look up any resources they use.
        var resourcesStride = 0
        constants.setConstantValue(&resourcesStride, type: .uint, index: 0)

        let rayFunc = try library?.makeFunction(name: "raytracingKernel", constantValues: constants)

        let pipelineDescriptor = MTLComputePipelineDescriptor()
        pipelineDescriptor.label = "ComputePipeline"
        pipelineDescriptor.computeFunction = rayFunc
        pipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        return try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: []).0
    }
    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)

        uniforms[0].camera = Camera(
            position: .init(x: 0, y: 1, z: 3.6),
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: -1)
        )
    }

    func draw(in view: MTKView) {
        /// Per frame updates hare
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            self.updateDynamicBufferState()

            let width = Int(view.drawableSize.width)
            let height = Int(view.drawableSize.height)
            uniforms[0].width = UInt32(width)
            uniforms[0].height = UInt32(height)

            if let computeEncoder = commandBuffer.makeComputeCommandEncoder(), let drawable = view.currentDrawable {
                /// Final pass rendering code here
                computeEncoder.label = "Primary Compute Encoder"
                computeEncoder.pushDebugGroup("Setup")
                computeEncoder.setComputePipelineState(pipelineState)
                computeEncoder.setBuffer(dynamicUniformBuffer, offset: uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                // XXX: real textures!
                computeEncoder.setTexture(randomTexture, index: TextureIndex.random.rawValue)
                computeEncoder.setTexture(drawable.texture, index: TextureIndex.dst.rawValue)
                computeEncoder.setBuffer(mesh.vertexBuffer, offset: 0, index: BufferIndex.vertexPositions.rawValue)
                computeEncoder.setBuffer(mesh.faceVertexBuffer, offset: 0, index: BufferIndex.faceVertices.rawValue)
                computeEncoder.setBuffer(mesh.materialIdBuffer, offset: 0, index: BufferIndex.faceMaterials.rawValue)
                computeEncoder.setBuffer(mesh.materialBuffer, offset: 0, index: BufferIndex.materials.rawValue)
                computeEncoder.setBuffer(mesh.instanceDescriptors, offset: 0, index: BufferIndex.intersectorObjects.rawValue)
                computeEncoder.setAccelerationStructure(mesh.accelerationStructure, bufferIndex: BufferIndex.intersector.rawValue)
                computeEncoder.popDebugGroup()

                // Launch a rectangular grid of threads on the GPU to perform ray tracing, with one thread per
                // pixel. The sample needs to align the number of threads to a multiple of the threadgroup
                // size, because earlier, when it created the pipeline objects, it declared that the pipeline
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
        
        let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
    }
}

extension MTLOrigin {
    static let zero = MTLOrigin(x: 0, y: 0, z: 0)
}

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}
