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
                let data = image.pngData()
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

    private struct RenderDuration: View {
        @ObservedObject var renderer: Renderer

        var body: some View {
            if let duration: Double = renderer.renderDuration {
                Text("Rendered in \(duration, format: .number.precision(.fractionLength(2)))s")
               } else {
                  Text("Rendering...")

            }

        }
    }

    private struct RenderButton: View {
        @ObservedObject var renderer: Renderer
        let rerender: @MainActor () -> Void

        var body: some View {
            Button(renderer.rendering ? "Rendering…" : "Rerender") {
                rerender()
            }
            .disabled(renderer.rendering)
            .keyboardShortcut(.defaultAction)
            .keyboardShortcut("r")
        }
    }

    var body: some View {
        VStack {
            if let renderer {
                RenderDuration(renderer: renderer)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            } else {
                Text("Waiting to render…")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            Spacer()

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
                if let renderer {
                    RenderButton(renderer: renderer, rerender: rerender)
                } else {
                    Button("Rerender") {}.disabled(true)
                }

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
