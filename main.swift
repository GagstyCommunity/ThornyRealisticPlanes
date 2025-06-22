
import SwiftUI
import PhotosUI
import AVFoundation

@main
struct MirrorWorldApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = MirrorWorldViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                switch viewModel.currentState {
                case .welcome:
                    WelcomeView(viewModel: viewModel)
                case .permissions:
                    PermissionsView(viewModel: viewModel)
                case .photoSelection:
                    PhotoSelectionView(viewModel: viewModel)
                case .processing:
                    ProcessingView(viewModel: viewModel)
                case .unityScene:
                    UnitySceneView(viewModel: viewModel)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - View Model
class MirrorWorldViewModel: ObservableObject {
    @Published var currentState: AppState = .welcome
    @Published var selectedImage: UIImage?
    @Published var processingProgress: Double = 0.0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    enum AppState {
        case welcome
        case permissions
        case photoSelection
        case processing
        case unityScene
    }
    
    func nextState() {
        switch currentState {
        case .welcome:
            currentState = .permissions
        case .permissions:
            currentState = .photoSelection
        case .photoSelection:
            if selectedImage != nil {
                currentState = .processing
                startProcessing()
            }
        case .processing:
            currentState = .unityScene
        case .unityScene:
            currentState = .welcome
        }
    }
    
    func uploadPhoto(_ image: UIImage) {
        selectedImage = image
        isLoading = true
        
        // Simulate API call to backend
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
            self.nextState()
        }
    }
    
    private func startProcessing() {
        processingProgress = 0.0
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            self.processingProgress += 0.02
            
            if self.processingProgress >= 1.0 {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.nextState()
                }
            }
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @ObservedObject var viewModel: MirrorWorldViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "person.3d")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("MirrorWorld")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Transform your photo into a photorealistic 3D version of yourself")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 15) {
                FeatureRow(icon: "camera.fill", text: "Capture or upload your photo")
                FeatureRow(icon: "cube.fill", text: "AI creates your 3D model")
                FeatureRow(icon: "sparkles", text: "Experience yourself in a virtual park")
            }
            .padding()
            
            Spacer()
            
            Button("Get Started") {
                viewModel.nextState()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.bottom, 50)
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

// MARK: - Permissions View
struct PermissionsView: View {
    @ObservedObject var viewModel: MirrorWorldViewModel
    @State private var cameraPermissionGranted = false
    @State private var photosPermissionGranted = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Privacy First")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("We need access to your camera and photos to create your 3D avatar")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 20) {
                PermissionRow(
                    icon: "camera.fill",
                    title: "Camera Access",
                    description: "Take photos for 3D conversion",
                    isGranted: cameraPermissionGranted
                ) {
                    requestCameraPermission()
                }
                
                PermissionRow(
                    icon: "photo.fill",
                    title: "Photo Library",
                    description: "Select existing photos",
                    isGranted: photosPermissionGranted
                ) {
                    requestPhotosPermission()
                }
            }
            .padding()
            
            Spacer()
            
            Button("Continue") {
                viewModel.nextState()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!cameraPermissionGranted || !photosPermissionGranted)
            .padding(.bottom, 50)
        }
        .padding()
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.cameraPermissionGranted = granted
            }
        }
    }
    
    private func requestPhotosPermission() {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                self.photosPermissionGranted = status == .authorized
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Allow") {
                    action()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Photo Selection View
struct PhotoSelectionView: View {
    @ObservedObject var viewModel: MirrorWorldViewModel
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var inputImage: UIImage?
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Choose Your Photo")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .cornerRadius(20)
                    .shadow(radius: 10)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5))
                    .frame(height: 300)
                    .overlay(
                        VStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("Select a photo of yourself")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    )
            }
            
            HStack(spacing: 20) {
                Button("Camera") {
                    showingCamera = true
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Photo Library") {
                    showingImagePicker = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            Spacer()
            
            if viewModel.selectedImage != nil {
                Button("Create My 3D Avatar") {
                    viewModel.nextState()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $inputImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: $inputImage, sourceType: .camera)
        }
        .onChange(of: inputImage) { image in
            if let image = image {
                viewModel.selectedImage = image
            }
        }
    }
}

// MARK: - Processing View
struct ProcessingView: View {
    @ObservedObject var viewModel: MirrorWorldViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("Creating Your 3D Avatar")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.blue, lineWidth: 3)
                    )
            }
            
            VStack(spacing: 15) {
                ProgressView(value: viewModel.processingProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                Text(processingStageText)
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("\(Int(viewModel.processingProgress * 100))% Complete")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var processingStageText: String {
        let progress = viewModel.processingProgress
        
        if progress < 0.2 {
            return "Analyzing your photo..."
        } else if progress < 0.4 {
            return "Extracting facial features..."
        } else if progress < 0.6 {
            return "Building 3D mesh..."
        } else if progress < 0.8 {
            return "Adding textures..."
        } else {
            return "Finalizing your avatar..."
        }
    }
}

// MARK: - Unity Scene View
struct UnitySceneView: View {
    @ObservedObject var viewModel: MirrorWorldViewModel
    
    var body: some View {
        VStack {
            Text("Your 3D World")
                .font(.title)
                .fontWeight(.bold)
                .padding()
            
            // Placeholder for Unity integration
            ZStack {
                Color.black
                    .cornerRadius(20)
                
                VStack {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Unity Scene Loading...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Your 3D avatar will appear here")
                        .font(.body)
                        .foregroundColor(.gray)
                }
            }
            .frame(height: 400)
            .padding()
            
            Button("Start Over") {
                viewModel.selectedImage = nil
                viewModel.processingProgress = 0.0
                viewModel.currentState = .welcome
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding()
        }
    }
}

// MARK: - Supporting Views and Styles
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
