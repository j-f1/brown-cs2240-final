import SwiftUI

@MainActor
struct ContentView: View {
    @State var settings = RenderSettings.default
    @State var nextSettings = RenderSettings.default
    @AppStorage("Model URL") var model: URL?

    // needs to be kept here since iOS destroys tabs when navigating away from them
    @State private var renderer: Renderer?

    @State private var selectedTab = 0

    private func rerender() {
        nextSettings.frameIndex += 1
        settings = nextSettings
        renderer?.settings = nextSettings
        renderer?.render()
    }

    var content: some View {
        #if os(iOS)
        TabView(selection: $selectedTab) {
            NavigationStack {
                GUIView(nextSettings: $nextSettings, model: $model)
                    .navigationTitle("Render Settings")
            }
            .tag(0)
            .tabItem { Label("Setup", systemImage: "gearshape.fill") }

            RenderView(settings: $settings, nextSettings: nextSettings, model: model, renderer: $renderer, rerender: rerender)
                .tag(1)
                .tabItem { Label("Render", systemImage: "photo.fill") }
        }
        #else
        HStack(alignment: .top) {
            GUIView(nextSettings: $nextSettings, model: $model)
                .padding()
                .fixedSize(horizontal: true, vertical: false)
            Divider()
            Spacer(minLength: 0)
            RenderView(settings: $settings, nextSettings: nextSettings, model: model, renderer: $renderer, rerender: rerender)
                .padding()
                .layoutPriority(1)
            Spacer(minLength: 0)
        }
        #endif
    }

    var body: some View {
        content
            .onAppear {
                if model == nil {
                    model = Bundle.main.url(forResource: "CornellBox-Original", withExtension: "obj", subdirectory: "models/CornellBox")
                }
            }
            .task(id: model) {
                guard let model else {
                    renderer = nil
                    return
                }
                renderer = await Renderer(
                    device: MTLCreateSystemDefaultDevice()!,
                    modelURL: model,
                    settings: settings
                )
                renderer?.render()
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
