
import Foundation
import UIKit
import SwiftUI

// MARK: - Unity Park Scene Controller
class UnityParkSceneController: ObservableObject {
    @Published var sceneLoaded = false
    @Published var avatarLoaded = false
    @Published var environmentSettings = EnvironmentSettings()
    @Published var cameraMode: CameraMode = .cinematic
    
    private let unityBridge = UnityBridge.getInstance()
    
    enum CameraMode {
        case cinematic      // Slow gliding camera movement
        case interactive    // User can rotate and zoom
        case fixed         // Static camera position
    }
    
    struct EnvironmentSettings {
        var timeOfDay: TimeOfDay = .afternoon
        var weatherCondition: Weather = .clear
        var windIntensity: Float = 0.3
        var ambientVolume: Float = 0.7
        var particleEffects = true
    }
    
    enum TimeOfDay: String, CaseIterable {
        case morning = "morning"
        case afternoon = "afternoon"
        case evening = "evening"
        case night = "night"
    }
    
    enum Weather: String, CaseIterable {
        case clear = "clear"
        case cloudy = "cloudy"
        case windy = "windy"
        case light_rain = "light_rain"
    }
    
    // MARK: - Scene Setup
    func initializeParkScene() {
        unityBridge.showUnity()
        setupEnvironment()
        configureLighting()
        setupAmbientSounds()
        setupParticleEffects()
    }
    
    func loadUserAvatar(assets: BackendAIPipeline.GeneratedAssets) {
        let modelURL = assets.modelURL.absoluteString
        let textureURL = assets.textureURL.absoluteString
        
        unityBridge.loadAvatarModel(modelURL: modelURL, textureURL: textureURL)
        
        // Configure avatar animations based on metadata
        configureAvatarAnimations(metadata: assets.metadata)
        avatarLoaded = true
    }
    
    // MARK: - Environment Configuration
    private func setupEnvironment() {
        let envConfig = """
        {
            "scene": "photorealistic_park",
            "lighting": "hdrp_dynamic",
            "shadows": "high_quality",
            "reflections": true,
            "postProcessing": {
                "bloom": true,
                "colorGrading": true,
                "depthOfField": true,
                "motionBlur": false
            }
        }
        """
        unityBridge.setSceneEnvironment(envConfig)
    }
    
    private func configureLighting() {
        let lightingConfig = """
        {
            "timeOfDay": "\(environmentSettings.timeOfDay.rawValue)",
            "sunIntensity": 1.2,
            "skyboxTint": [1.0, 0.95, 0.8],
            "ambientIntensity": 0.4,
            "shadowDistance": 50.0,
            "volumetricFog": true
        }
        """
        unityBridge.setSceneEnvironment(lightingConfig)
    }
    
    private func setupAmbientSounds() {
        let audioConfig = """
        {
            "ambientSounds": {
                "birds": {
                    "volume": 0.6,
                    "frequency": "random",
                    "types": ["sparrow", "robin", "dove"]
                },
                "wind": {
                    "volume": 0.4,
                    "intensity": \(environmentSettings.windIntensity),
                    "rustling": true
                },
                "water": {
                    "volume": 0.3,
                    "type": "gentle_stream"
                }
            },
            "masterVolume": \(environmentSettings.ambientVolume)
        }
        """
        unityBridge.setSceneEnvironment(audioConfig)
    }
    
    private func setupParticleEffects() {
        if environmentSettings.particleEffects {
            let particleConfig = """
            {
                "particles": {
                    "leaves": {
                        "enabled": true,
                        "density": 10,
                        "windAffected": true
                    },
                    "pollen": {
                        "enabled": true,
                        "density": 5,
                        "floatSpeed": 0.2
                    },
                    "sunbeams": {
                        "enabled": true,
                        "intensity": 0.3,
                        "volumetric": true
                    }
                }
            }
            """
            unityBridge.setSceneEnvironment(particleConfig)
        }
    }
    
    // MARK: - Avatar Animation Configuration
    private func configureAvatarAnimations(metadata: BackendAIPipeline.AvatarMetadata) {
        let animationConfig = """
        {
            "breathing": {
                "rate": \(metadata.animationConfig.breathingRate),
                "intensity": 0.8,
                "chestMovement": true,
                "shoulderMovement": true
            },
            "blinking": {
                "frequency": \(metadata.animationConfig.blinkFrequency),
                "duration": 0.15,
                "natural": true
            },
            "microMotions": {
                "headSway": 0.3,
                "weightShift": 0.2,
                "eyeMovement": 0.4,
                "facialTwitches": 0.1
            },
            "idle": {
                "poses": \(metadata.animationConfig.idlePoses),
                "transitionTime": 3.0,
                "randomness": 0.2
            }
        }
        """
        unityBridge.setSceneEnvironment(animationConfig)
    }
    
    // MARK: - Camera Controls
    func setCameraMode(_ mode: CameraMode) {
        cameraMode = mode
        
        let cameraConfig: String
        switch mode {
        case .cinematic:
            cameraConfig = """
            {
                "mode": "cinematic",
                "path": "gentle_orbit",
                "speed": 0.1,
                "focus": "avatar",
                "smoothing": true,
                "autoFraming": true
            }
            """
        case .interactive:
            cameraConfig = """
            {
                "mode": "interactive",
                "orbitEnabled": true,
                "zoomEnabled": true,
                "panEnabled": false,
                "sensitivity": 1.0,
                "bounds": {
                    "minDistance": 2.0,
                    "maxDistance": 8.0,
                    "verticalLimits": [-30, 60]
                }
            }
            """
        case .fixed:
            cameraConfig = """
            {
                "mode": "fixed",
                "position": [0, 1.6, 3],
                "lookAt": "avatar",
                "fieldOfView": 60
            }
            """
        }
        
        unityBridge.setSceneEnvironment(cameraConfig)
    }
    
    // MARK: - Environment Controls
    func updateEnvironment(_ newSettings: EnvironmentSettings) {
        environmentSettings = newSettings
        configureLighting()
        setupAmbientSounds()
        setupParticleEffects()
        
        let weatherConfig = """
        {
            "weather": "\(newSettings.weatherCondition.rawValue)",
            "windIntensity": \(newSettings.windIntensity),
            "skybox": "\(newSettings.timeOfDay.rawValue)_sky"
        }
        """
        unityBridge.setSceneEnvironment(weatherConfig)
    }
    
    func cleanup() {
        unityBridge.hideUnity()
        sceneLoaded = false
        avatarLoaded = false
    }
}

// MARK: - Unity Scene SwiftUI Integration
struct UnityParkSceneWrapper: UIViewControllerRepresentable {
    @ObservedObject var sceneController: UnityParkSceneController
    let generatedAssets: BackendAIPipeline.GeneratedAssets
    
    func makeUIViewController(context: Context) -> UnityViewController {
        let controller = UnityViewController()
        controller.sceneController = sceneController
        controller.loadScene(with: generatedAssets)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UnityViewController, context: Context) {
        // Update Unity scene if needed
    }
}

class UnityViewController: UIViewController {
    var sceneController: UnityParkSceneController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUnityView()
    }
    
    private func setupUnityView() {
        // Unity view will be embedded here
        view.backgroundColor = .black
    }
    
    func loadScene(with assets: BackendAIPipeline.GeneratedAssets) {
        sceneController?.initializeParkScene()
        sceneController?.loadUserAvatar(assets: assets)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneController?.cleanup()
    }
}
