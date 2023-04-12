import SwiftUI

struct ContentView: View {
    var body: some View {
        HStack {
            GUIView()
            MetalView(model: Bundle.main.url(forResource: "cow", withExtension: "obj", subdirectory: "meshes")!)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
