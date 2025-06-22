
import Foundation
import UIKit
import Combine

// MARK: - Backend AI Pipeline Service
class BackendAIPipeline: ObservableObject {
    @Published var currentStage: PipelineStage = .idle
    @Published var progress: Double = 0.0
    @Published var generatedAssets: GeneratedAssets?
    @Published var errorMessage: String?
    
    private let baseURL = "https://api.mirrorworld-backend.replit.app" // Replit backend URL
    private var cancellables = Set<AnyCancellable>()
    
    enum PipelineStage: String, CaseIterable {
        case idle = "Ready"
        case uploading = "Uploading to backend..."
        case segmentation = "MODNet person segmentation..."
        case depthAnalysis = "MiDaS depth estimation..."
        case meshGeneration = "RenderNet 3D mesh creation..."
        case textureMapping = "PIKE texture generation..."
        case rigging = "Adding facial blendshapes..."
        case animation = "Injecting breathing & micro-motions..."
        case unityPrep = "Preparing for Unity import..."
        case completed = "Ready for 3D world!"
    }
    
    struct GeneratedAssets {
        let modelURL: URL
        let textureURL: URL
        let animationData: URL
        let metadata: AvatarMetadata
    }
    
    struct AvatarMetadata: Codable {
        let facialFeatures: FacialFeatures
        let bodyMeasurements: BodyMeasurements
        let animationConfig: AnimationConfig
    }
    
    struct FacialFeatures: Codable {
        let eyeColor: String
        let skinTone: String
        let facialStructure: [String: Double]
        let expressionCapabilities: [String]
    }
    
    struct BodyMeasurements: Codable {
        let height: Double
        let proportions: [String: Double]
        let postureData: [String: Double]
    }
    
    struct AnimationConfig: Codable {
        let breathingRate: Double
        let blinkFrequency: Double
        let microMotions: [String: Double]
        let idlePoses: [String]
    }
    
    // MARK: - Main Pipeline Function
    func processPhotoTo3D(image: UIImage) -> AnyPublisher<GeneratedAssets, Error> {
        return uploadToBackend(image: image)
            .flatMap { [weak self] uploadResponse in
                self?.monitorProcessing(jobId: uploadResponse.jobId) ?? 
                Fail(error: PipelineError.processingFailed).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Pipeline Steps
    private func uploadToBackend(image: UIImage) -> AnyPublisher<UploadResponse, Error> {
        currentStage = .uploading
        progress = 0.1
        
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            return Fail(error: PipelineError.imageProcessingFailed).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v1/process-avatar")!)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"user.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n")
        
        // Add pipeline configuration
        let config = """
        {
            "pipeline": "renderNet_pike",
            "quality": "high",
            "animations": ["breathing", "blinking", "micro_motions"],
            "targetFormat": "glb",
            "unityCompatible": true
        }
        """
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"config\"\r\n\r\n".data(using: .utf8)!)
        body.append(config.data(using: .utf8)!)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: UploadResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    private func monitorProcessing(jobId: String) -> AnyPublisher<GeneratedAssets, Error> {
        return Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .flatMap { [weak self] _ in
                self?.checkProcessingStatus(jobId: jobId) ?? 
                Empty<ProcessingStatusResponse, Error>().eraseToAnyPublisher()
            }
            .handleEvents(receiveOutput: { [weak self] response in
                self?.updateProgress(response)
            })
            .compactMap { response in
                response.isCompleted ? response.assets : nil
            }
            .first()
            .eraseToAnyPublisher()
    }
    
    private func checkProcessingStatus(jobId: String) -> AnyPublisher<ProcessingStatusResponse, Error> {
        let url = URL(string: "\(baseURL)/api/v1/status/\(jobId)")!
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: ProcessingStatusResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    private func updateProgress(_ response: ProcessingStatusResponse) {
        DispatchQueue.main.async { [weak self] in
            self?.progress = response.progress
            if let stage = PipelineStage(rawValue: response.currentStage) {
                self?.currentStage = stage
            }
            if let error = response.error {
                self?.errorMessage = error
            }
        }
    }
}

// MARK: - Response Models
struct UploadResponse: Codable {
    let jobId: String
    let estimatedTime: Int
    let message: String
}

struct ProcessingStatusResponse: Codable {
    let jobId: String
    let currentStage: String
    let progress: Double
    let isCompleted: Bool
    let assets: BackendAIPipeline.GeneratedAssets?
    let error: String?
}

// MARK: - Error Types
enum PipelineError: LocalizedError {
    case imageProcessingFailed
    case uploadFailed
    case processingFailed
    case networkError
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process the uploaded image"
        case .uploadFailed:
            return "Failed to upload image to backend"
        case .processingFailed:
            return "3D model generation failed"
        case .networkError:
            return "Network connection error"
        case .invalidResponse:
            return "Invalid response from backend"
        }
    }
}
