import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

@MainActor
class Renderer: ObservableObject {
    var settings: RenderSettings

    nonisolated private let device: MTLDevice
    nonisolated private let commandQueue: MTLCommandQueue
    nonisolated private let uniformBuffer: MTLBuffer
    nonisolated private let pathTracePipelineState: MTLComputePipelineState
    nonisolated private let flattenPipelineState: MTLComputePipelineState
    private var randomTexture: MTLTexture
    private var scene: Scene

    @Published var rendering = false
    @Published var renderDuration: TimeInterval?
    @Published var content: MTLTexture?
#if canImport(AppKit)
    @Published var image: NSImage?
#else
    @Published var image: UIImage?
#endif

    @MainActor
    init?(device: MTLDevice, modelURL: URL, settings: RenderSettings) async {
        let start = Date.now
        self.device = device
        guard let queue = self.device.makeCommandQueue() else {
            print("Unable to allocate command queue")
            return nil
        }
        queue.label = "Main Command Queue"
        self.commandQueue = queue

        guard let buffer = self.device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: []) else { return nil }
        uniformBuffer = buffer

        self.uniformBuffer.label = "UniformBuffer"

        do {
            pathTracePipelineState = try Renderer.buildPathTracePipeline(device: device)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }

        do {
            flattenPipelineState = try Renderer.buildFlattenPipeline(device: device)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }

        guard let mesh = await Scene(contentsOf: modelURL, for: device, commandQueue: commandQueue) else {
            print("Unable to load model at \(modelURL.absoluteString)")
            return nil
        }
        self.scene = mesh

        let start2 = Date()
        guard let randomTexture = await Renderer.buildRandomTexture(size: settings.size, on: device) else {
            print("Unable to create random texture")
            return nil
        }
        print("Created random texture in \((Date.now.timeIntervalSince(start2) * 1000).formatted(.number.precision(.significantDigits(...3))))ms")

        self.randomTexture = randomTexture

        self.settings = settings

        print("Loaded \(modelURL.lastPathComponent) in \((Date.now.timeIntervalSince(start) * 1000).formatted(.number.precision(.significantDigits(...3))))ms")
    }

    private class func buildRandomTexture(size: CGSize, on device: MTLDevice) async -> MTLTexture? {
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

        return await runBlocking {
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
    }

    private class func buildIntermediateTexture(size: CGSize, samples: Int32, on device: MTLDevice) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .rgba32Float
        textureDescriptor.textureType = .type3D
        textureDescriptor.width = Int(size.width)
        textureDescriptor.height = Int(size.height)
        textureDescriptor.depth = Int(samples)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .private

        return device.makeTexture(descriptor: textureDescriptor)
    }

    private class func buildOutputTexture(size: CGSize, on device: MTLDevice) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .rgba8Uint
        textureDescriptor.textureType = .type2D
        textureDescriptor.width = Int(size.width)
        textureDescriptor.height = Int(size.height)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        #if os(iOS)
        textureDescriptor.storageMode = .shared
        #else
        textureDescriptor.storageMode = .managed
        #endif

        return device.makeTexture(descriptor: textureDescriptor)
    }

    private class func buildPathTracePipeline(device: MTLDevice) throws -> MTLComputePipelineState {
        let library = device.makeDefaultLibrary()
        let pipelineDescriptor = MTLComputePipelineDescriptor()
        pipelineDescriptor.label = "Render Pipeline"
        pipelineDescriptor.computeFunction = library?.makeFunction(name: "pathTraceKernel")
        pipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        return try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: []).0
    }

    private class func buildFlattenPipeline(device: MTLDevice) throws -> MTLComputePipelineState {
        let library = device.makeDefaultLibrary()
        let pipelineDescriptor = MTLComputePipelineDescriptor()
        pipelineDescriptor.label = "Flatten Pipeline"
        pipelineDescriptor.computeFunction = library?.makeFunction(name: "flattenKernel")
        pipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        return try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: []).0
    }

    private func growRandomTexture() async -> MTLTexture {
        guard randomTexture.width < settings.imageWidth || randomTexture.height < settings.imageHeight else { return randomTexture }

        var newSize = CGSize(width: randomTexture.width, height: randomTexture.height)
        while Int(newSize.width) < settings.imageWidth { newSize.width *= 2 }
        while Int(newSize.height) < settings.imageHeight { newSize.height *= 2 }
        print("Growing random texture to \(newSize)")
        guard let randomTexture = await Renderer.buildRandomTexture(size: newSize, on: device) else {
            print("Unable to create random texture")
            return self.randomTexture
        }
        self.randomTexture = randomTexture
        return randomTexture
    }

    func render() {
        let start = Date()
        guard
            let intermediateTexture = Renderer.buildIntermediateTexture(size: settings.size, samples: settings.samplesPerPixel, on: device),
            let finalTexture = Renderer.buildOutputTexture(size: settings.size, on: device)
        else {
            print("Unable to create render textures")
            return
        }

        guard !rendering else { return }
        rendering = true
        content = nil

        Task.detached(priority: .userInitiated) { [self, settings, scene] in
            let randomTexture = await growRandomTexture()

            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            let uniforms = UnsafeMutableRawPointer(uniformBuffer.contents()).bindMemory(to: Uniforms.self, capacity: 1)
            uniforms[0].camera = Camera(
                position: .init(x: 0, y: 1, z: 3.6),
                right: .init(x: 0.4, y: 0, z: 0),
                up: .init(x: 0, y: 0.4, z: 0),
                forward: .init(x: 0, y: 0, z: -1)
            )

            let width = Int(settings.size.width)
            let height = Int(settings.size.height)
            assert(width == settings.imageWidth)
            assert(height == settings.imageHeight)
            uniforms[0].settings = settings
            uniforms[0].emissivesCount = scene.emissivesCount

            /// Launch a rectangular grid of threads on the GPU to perform ray tracing, with one thread per
            /// pixel. The number of threads needs to be aligned to a multiple of the threadgroup size,
            /// because earlier, when it created the pipeline objects, it declared that the pipeline
            /// would always use a threadgroup size that's a multiple of the thread execution width
            /// (SIMD group size). An 8x8 threadgroup is a safe threadgroup size and small enough to be
            /// supported on most devices. A more advanced app would choose the threadgroup size dynamically.
            let threadsPerThreadgroup = MTLSize(width: 8, height: 8, depth: 1)
            let threadgroups = MTLSize(
                width: (width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
                height: (height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
                depth: Int(settings.samplesPerPixel)
            )

            if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                computeEncoder.label = "Path Tracer"
                computeEncoder.pushDebugGroup("Setup")
                computeEncoder.setComputePipelineState(pathTracePipelineState)
                computeEncoder[.uniforms] = uniformBuffer
                computeEncoder[.random] = randomTexture
                computeEncoder[.dst] = intermediateTexture
                computeEncoder[.vertexPositions] = scene.vertexPositionsBuffer
                computeEncoder[.vertexNormalAngles] = scene.normalAnglesBuffer
                computeEncoder[.faceVertexNormals] = scene.vertexNormalIndexBuffer
                computeEncoder[.faceVertices] = scene.faceVertexIndexBuffer
                computeEncoder[.faceNormals] = scene.normalBuffer
                computeEncoder[.faceMaterials] = scene.materialIndexBuffer
                computeEncoder[.materials] = scene.materialBuffer
                computeEncoder[.emissiveFaces] = scene.emissivesBuffer
                computeEncoder[.intersector] = scene.accelerationStructure
                computeEncoder.popDebugGroup()

                computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
                computeEncoder.endEncoding()
            }

            if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                computeEncoder.label = "Sample Flattener"
                computeEncoder.setComputePipelineState(flattenPipelineState)
                computeEncoder[.uniforms] = uniformBuffer
                computeEncoder[.src] = intermediateTexture
                computeEncoder[.dst] = finalTexture

                let threadgroups = MTLSize(width: threadgroups.width, height: threadgroups.height, depth: 1)
                computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
                computeEncoder.endEncoding()
            }

            #if !os(iOS)
            if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
                blitEncoder.synchronize(resource: finalTexture)
                blitEncoder.endEncoding()
            }
            #endif

            commandBuffer.commit()
            await runBlocking {
                commandBuffer.waitUntilCompleted()
            }

            await MainActor.run {
                self.content = finalTexture
                self.image = finalTexture.image
                self.rendering = false
                self.renderDuration = Date().timeIntervalSince(start)
                print("Rendered in \(Date().timeIntervalSince(start).formatted(.number.precision(.fractionLength(2))))s")
            }
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

private extension MTLTexture {
#if canImport(AppKit)
    typealias ImageType = NSImage
#else
    typealias ImageType = UIImage
#endif
    var image: ImageType {
        let pixelBytes = UnsafeMutableRawBufferPointer.allocate(byteCount: allocatedSize, alignment: MemoryLayout<UInt8>.alignment)
        let bytesPerRow = 4 * width; precondition(pixelFormat == .rgba8Uint)
        self.getBytes(pixelBytes.baseAddress!, bytesPerRow: bytesPerRow, from: MTLRegion(origin: .zero, size: MTLSize(width: width, height: height, depth: 1)), mipmapLevel: 0)
        let provider = CGDataProvider(dataInfo: nil, data: pixelBytes.baseAddress!, size: pixelBytes.count, releaseData: { _, data, _ in data.deallocate() })
        let cgImage = CGImage(
            width: width, height: height,
            bitsPerComponent: MemoryLayout<UInt8>.size * 8,
            bitsPerPixel: MemoryLayout<UInt8>.size * 8 * 4,
            bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: [.init(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)],
            provider: provider!,
            decode: nil,
            shouldInterpolate: false,
            intent: .absoluteColorimetric
        )!
#if canImport(AppKit)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
#else
        return UIImage(cgImage: cgImage)
#endif
    }
}
