import SwiftUI

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
            }
            #if os(iOS)
            .fontWeight(.medium)
            .buttonStyle(.bordered)
            .padding(.bottom)
            #endif
        }
    }
}
