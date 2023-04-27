import SwiftUI
import UniformTypeIdentifiers

struct RenderView: View {
    @Binding var settings: RenderSettings
    let nextSettings: RenderSettings
    let model: URL?
    @Binding var renderer: Renderer?
    let rerender: @MainActor () -> Void

    @State private var expand = false
    @Environment(\.displayScale) private var scale

    private struct RenderResult: View {
        @ObservedObject var renderer: Renderer

        var body: some View {
            VStack {
                if let image = renderer.image {
                    #if canImport(AppKit)
                    let image = Image(nsImage: image)
                    #else
                    let image = Image(uiImage: image)
                    #endif
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.secondary
                }
            }.overlay {
                if renderer.rendering {
                    ProgressView()
                        .controlSize(.large)
                        .colorScheme(.dark)
                        .transition(.asymmetric(insertion: .opacity.animation(.default.delay(0.1)), removal: .identity))
                }
            }
        }
    }

    private struct SaveButton: View {
        @ObservedObject var renderer: Renderer
        @State private var isSaving = false

        private struct File: FileDocument {
            static var readableContentTypes = [UTType]()
            static var writableContentTypes = [UTType.png]

            #if canImport(AppKit)
            let image: NSImage
            #else
            let image: UIImage
            #endif

            init(configuration: ReadConfiguration) throws {
                fatalError()
            }

            #if canImport(AppKit)
            init(image: NSImage) { self.image = image }
            #else
            init(image: UIImage) { self.image = image }
            #endif

            enum Error: Swift.Error {
                case couldNotCreateCGImage
                case couldNotCreateData
            }

            func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
                #if os(macOS)
                // https://stackoverflow.com/a/17510651/5244995
                guard
                    let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
                else {
                    throw Error.couldNotCreateCGImage
                }
                let newRep = NSBitmapImageRep(cgImage: cgImage)
                newRep.size = image.size
                let data = newRep.representation(using: .png, properties: [:])
                #else
                #endif
                if let data {
                    return FileWrapper(regularFileWithContents: data)
                } else {
                    throw Error.couldNotCreateData
                }
            }
        }

        var body: some View {
            if let image = renderer.image {
                Button("Save") {
                    isSaving = true
                }
                .disabled(renderer.rendering)
                .keyboardShortcut("s")
                .fileExporter(
                    isPresented: $isSaving,
                    document: File(image: image),
                    contentType: .png,
                    defaultFilename: Date().formatted(.iso8601).replacingOccurrences(of: ":", with: ".")
                ) { result in
                    print(result)
                }
            } else {
                Button("Save") {}.disabled(true)
            }
        }
    }

    var body: some View {
        VStack {
            Group {
                if let renderer {
                    RenderResult(renderer: renderer)
                } else {
                    Color.secondary.overlay(ProgressView().controlSize(.large).colorScheme(.dark))
                }
            }
            .frame(width: expand ? nil : settings.size.width / scale, height: expand ? nil : settings.size.height / scale)
            .animation(.interactiveSpring(), value: expand)
            .onTapGesture(count: 2) {
                expand.toggle()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(settings.size.width / settings.size.height, contentMode: .fit)
            .animation(.default, value: settings.size)

            Spacer()
            HStack {
                Button("Rerender") {
                    rerender()
                }
                .disabled(renderer == nil)
                .keyboardShortcut(.defaultAction)

                Button {
                    expand.toggle()
                } label: {
                    Image(systemName: expand ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .accessibilityLabel("Expand/Collapse Render")
                }

                if let renderer {
                    SaveButton(renderer: renderer)
                }
            }
            #if os(iOS)
            .fontWeight(.medium)
            .buttonStyle(.bordered)
            .padding(.bottom)
            #endif
        }
    }
}
