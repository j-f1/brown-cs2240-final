import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            MetalView()
        }
        .padding()
        .onAppear {
            if let mesh = Mesh(contentsOf: Bundle.main.url(forResource: "cow", withExtension: "obj", subdirectory: "meshes")) {
//                print(mesh.vertices)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
