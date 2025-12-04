import Foundation
import MediaPipeTasksGenAI
import UIKit

class ModelUtils {
    private var llmInference: LlmInference?
    private var session: LlmInference.Session?

    private var modelPath: String?
    
    func loadModel(filename: String, fileExtension: String) async throws {
        let fileManager = FileManager.default

        guard let bundlePath = Bundle.main.path(forResource: filename, ofType: fileExtension) else {
            throw NSError(domain: "ModelUtils", code: 404, userInfo: [NSLocalizedDescriptionKey: "Model file not found in Bundle."])
        }

        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        try fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        
        let modelTargetURL = appSupportDir.appendingPathComponent("\(filename).\(fileExtension)")

        if !fileManager.fileExists(atPath: modelTargetURL.path) {
            print("[ModelUtils] Copying model to App Support...")
            try? fileManager.removeItem(at: modelTargetURL)
            try fileManager.copyItem(atPath: bundlePath, toPath: modelTargetURL.path)
        }

        let options = LlmInference.Options(modelPath: modelTargetURL.path)
        options.maxTokens = 4096
        
        
        
        self.modelPath = modelTargetURL.path

        self.llmInference = try LlmInference(options: options)

        try startNewSession()
    }
    
    func startNewSession() throws {
        guard let engine = self.llmInference else { return }
        let sessionOptions = LlmInference.Session.Options()
        sessionOptions.topk = 40
        sessionOptions.temperature = 0.8
        sessionOptions.randomSeed = 101
        
        self.session = try LlmInference.Session(llmInference: engine, options: sessionOptions)
        print("[ModelUtils] New Text-Only Session Started")
    }
    
    func reset() {
        guard llmInference != nil else { return }
        try? startNewSession()
    }
    
    func generateResponse(prompt: String) async throws -> AsyncThrowingStream<String, Error> {
        guard let session = session else {
            throw NSError(domain: "ModelUtils", code: 500, userInfo: [NSLocalizedDescriptionKey: "Session not initialized"])
        }
        try session.addQueryChunk(inputText: prompt)
        return session.generateResponseAsync()
    }
}
