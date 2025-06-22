
import Foundation
import UIKit
import UnityFramework

// MARK: - Unity Bridge for iOS Integration
class UnityBridge: NSObject, ObservableObject {
    private var unityFramework: UnityFramework?
    private var hostMainWindow: UIWindow?
    private var launchOpts: [UIApplication.LaunchOptionsKey: Any]?
    
    @Published var isUnityLoaded = false
    @Published var currentScene = ""
    @Published var modelLoadProgress: Float = 0.0
    
    private static var instance: UnityBridge?
    
    static func getInstance() -> UnityBridge {
        if instance == nil {
            instance = UnityBridge()
        }
        return instance!
    }
    
    override init() {
        super.init()
        loadUnity()
    }
    
    // MARK: - Unity Lifecycle
    private func loadUnity() {
        let bundlePath = Bundle.main.bundlePath + "/Frameworks/UnityFramework.framework"
        let bundle = Bundle(path: bundlePath)
        
        if bundle?.isLoaded == false {
            bundle?.load()
        }
        
        let ufw = bundle?.principalClass?.getInstance()
        if ufw?.appController() == nil {
            let machineHeader = UnsafeMutablePointer<MachineHeader>.allocate(capacity: 1)
            machineHeader.pointee = _mh_execute_header
            ufw?.setExecuteHeader(machineHeader)
        }
        unityFramework = ufw
        unityFramework?.setDataBundleId("com.unity3d.framework")
        unityFramework?.register(self)
        
        NSClassFromString("FrameworkLibAPI")?.registerAPIforNativeCalls(self)
    }
    
    func showUnity() {
        if let unityFramework = unityFramework {
            unityFramework.showUnityWindow()
            isUnityLoaded = true
        }
    }
    
    func hideUnity() {
        unityFramework?.pause(true)
    }
    
    func pauseUnity() {
        unityFramework?.pause(true)
    }
    
    func resumeUnity() {
        unityFramework?.pause(false)
    }
    
    func unloadUnity() {
        unityFramework?.unload()
        isUnityLoaded = false
    }
    
    // MARK: - Unity Communication
    func loadAvatarModel(modelURL: String, textureURL: String) {
        let message = """
        {
            "modelURL": "\(modelURL)",
            "textureURL": "\(textureURL)",
            "animationData": "breathing,blinking,idle"
        }
        """
        unityFramework?.sendMessageToGO(withName: "AvatarManager", functionName: "LoadUserAvatar", message: message)
    }
    
    func updateCameraPosition(x: Float, y: Float, z: Float) {
        let message = "\(x),\(y),\(z)"
        unityFramework?.sendMessageToGO(withName: "CameraController", functionName: "UpdatePosition", message: message)
    }
    
    func setSceneEnvironment(_ environment: String) {
        unityFramework?.sendMessageToGO(withName: "SceneManager", functionName: "SetEnvironment", message: environment)
    }
}

// MARK: - Unity Framework Delegate
extension UnityBridge: UnityFrameworkListener {
    func unityDidUnload(_ notification: Notification!) {
        unityFramework?.unregisterFrameworkListener(self)
        unityFramework = nil
        hostMainWindow = nil
        launchOpts = nil
    }
}

// MARK: - Native Calls from Unity
extension UnityBridge {
    @objc func onUnityMessage(_ message: String) {
        let data = message.data(using: .utf8)!
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            DispatchQueue.main.async {
                switch json["type"] as? String {
                case "modelLoaded":
                    self.modelLoadProgress = 1.0
                case "sceneReady":
                    self.currentScene = json["scene"] as? String ?? ""
                case "loadingProgress":
                    self.modelLoadProgress = json["progress"] as? Float ?? 0.0
                default:
                    break
                }
            }
        }
    }
}
