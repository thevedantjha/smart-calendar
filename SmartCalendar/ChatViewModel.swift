import Foundation
import SwiftUI
import Combine
import Vision

struct ParsedEventData {
    var title: String
    var date: Date
    var location: String
    var notes: String
}

struct Message: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    var text: String
    var isThinking: Bool = false
    var uiImage: UIImage? = nil
}

enum MessageRole { case user, model, system }

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputParam: String = ""
    @Published var selectedUIImage: UIImage? = nil
    
    @Published var isModelLoaded: Bool = false

    @Published var isGenerating: Bool = false

    @Published var isChatProcessing: Bool = false
    
    @Published var errorMessage: String?

    @Published var extractedEventData: ParsedEventData?
    @Published var showEventEditor: Bool = false
    @Published var eventToDelete: String?

    @Published var analysisStatus: String = "Initializing..."

    private var storedUserPrompt: String = ""
    private var storedIntent: Int = 0
    
    private var modelUtils: ModelUtils?
    private var generationTask: Task<Void, Never>?
    weak var calendarManager: CalendarManager?
    
    init() {
        Task { await loadModel() }
    }
    
    func loadModel() async {
        do {
            self.modelUtils = ModelUtils()
            try await self.modelUtils?.loadModel(filename: "gemma-3n", fileExtension: "task")
            self.isModelLoaded = true
            print("[DEBUG_LOG] Model loaded successfully.")
        } catch {
            self.errorMessage = "Failed to load: \(error.localizedDescription)"
            print("[DEBUG_LOG] Model load failed: \(error)")
        }
    }
    
    func resetChat() {
        self.messages.removeAll()
        self.inputParam = ""
        self.stopGeneration()
    }
    
    func stopGeneration() {
        print("[DEBUG_LOG] Generation Stopped by User")
        generationTask?.cancel()
        
        Task { @MainActor in
            self.isGenerating = false
            self.isChatProcessing = false

            if let lastIdx = self.messages.indices.last, self.messages[lastIdx].isThinking {
                self.messages[lastIdx].text = "Generation stopped."
                self.messages[lastIdx].isThinking = false
            }
        }
    }

    func sendMessage(userQuery: String) {
        let trimmed = userQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageToSend = selectedUIImage
        
        guard !trimmed.isEmpty || imageToSend != nil else { return }
        guard isModelLoaded, !isGenerating, !isChatProcessing else { return }

        print("\n\n==================================================")
        print("[DEBUG_LOG] STEP 0: User Input Received")
        print("[DEBUG_LOG] Raw Input: \"\(trimmed)\"")
        if imageToSend != nil { print("[DEBUG_LOG] Image attached: Yes") }
        print("==================================================\n")
        
        messages.append(Message(role: .user, text: trimmed, uiImage: imageToSend))
        inputParam = ""
        selectedUIImage = nil

        storedUserPrompt = trimmed
        storedIntent = 0

        messages.append(Message(role: .model, text: "Thinking...", isThinking: true))

        isChatProcessing = true
        
        generationTask = Task {
            defer { Task { @MainActor in self.isChatProcessing = false } }
            
            do {
                try await step1_DetermineIntent()
            } catch {
                await self.handleGenerationError(error)
            }
        }
    }

    private func step1_DetermineIntent() async throws {
        guard let utils = modelUtils else { return }

        utils.reset()
        
        let prompt = """
        INSTRUCTIONS:
        Analyze the user input and reply with ONE number only.
        
        1 if the user is asking a question, checking the schedule, or looking up information.
        2 if the user is explicitly asking to CREATE, ADD, or SCHEDULE a new event.
        3 if the user is explicitly asking to DELETE, REMOVE, or CANCEL an existing event.
        
        USER INPUT: "\(storedUserPrompt)"
        
        REPLY WITH ONE OF THE NUMBERS (1, 2, or 3):
        """
        
        print("[DEBUG_LOG] --- STEP 1: Determine Intent ---")
        print("[DEBUG_LOG] Prompt Sent to Model:\n\(prompt)")
        print("[DEBUG_LOG] Streaming Response: ", terminator: "")
        
        await updateStatusMessage("Determining intent...")

        let stream = try await utils.generateResponse(prompt: prompt)
        var responseText = ""
        for try await chunk in stream {
            responseText += chunk
            print(chunk, terminator: "")
        }
        print("\n")

        print("[DEBUG_LOG] Step 1 Final Output: \(responseText)")
        
        if responseText.contains("1") {
            storedIntent = 1
            print("[DEBUG_LOG] Intent Detected: 1 (Question/Check)")
            await updateStatusMessage("Checking schedule...")
            try await step2_HandleQuestion()
        } else if responseText.contains("2") {
            storedIntent = 2
            print("[DEBUG_LOG] Intent Detected: 2 (Create Event)")
            await updateStatusMessage("Preparing to create event...")
            try await step2_HandleCreation()
        } else if responseText.contains("3") {
            storedIntent = 3
            print("[DEBUG_LOG] Intent Detected: 3 (Delete Event)")
            await updateStatusMessage("Finding event to delete...")
            try await step2_HandleDeletion()
        } else {
            storedIntent = 1
            print("[DEBUG_LOG] Intent Fallback: Defaulting to 1 (Question)")
            await updateStatusMessage("Processing question...")
            try await step2_HandleQuestion()
        }
    }
        private func step2_HandleQuestion() async throws {
            guard let utils = modelUtils else { return }

            utils.reset()
            
            let today = Date().formatted(date: .complete, time: .omitted)
            let rangePrompt = """
            YOUR RESPONSIBILITY IS TO DETERMINE WHETHER THE USER IS TALKING ABOUT A SINGLE DATE OR A TIME RANGE.
            
            Today's date: \(today)
            User prompt: "\(storedUserPrompt)"
            
            INSTRUCTIONS:
            - If the user mentions a single day (e.g., "next Monday"), calculate that day.
            - If the user talks about a time range (e.g., "this week", "next week", "this weekend"), calculate the start and end dates for that range.
            - If no date or range is specified, default to today's date.
            
            RESPOND WITH:
            - For a single date: The date in format YYYY-MM-DD.
            - For a time range: Two dates (start and end) in format YYYY-MM-DD, separated by a comma (e.g., "2025-12-01, 2025-12-07").
            """
            
            print("[DEBUG_LOG] --- STEP 2A: Calculate Date or Time Range ---")
            print("[DEBUG_LOG] Prompt Sent to Model:\n\(rangePrompt)")
            print("[DEBUG_LOG] Streaming Response: ", terminator: "")
            
            let stream = try await utils.generateResponse(prompt: rangePrompt)
            var dateString = ""
            for try await chunk in stream {
                dateString += chunk
                print(chunk, terminator: "")
            }
            print("\n")

            print("[DEBUG_LOG] Parsed Date/Range Response: \(dateString)")

            let dateRange = parseDateOrRangeResponse(dateString)
            print("[DEBUG_LOG] Calculated Range: \(dateRange)")

            if dateRange.count == 1 {
                let calculatedDate = dateRange.first!
                Task {
                    await updateStatusMessage("Checking events on \(calculatedDate.formatted(date: .abbreviated, time: .omitted))...")
                }

                let dayStart = Calendar.current.startOfDay(for: calculatedDate)
                let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
                let contextSummary = calendarManager?.getEventsSummary(from: dayStart, to: dayEnd) ?? "No calendar access."
                try await step3_GenerateFinalResponse(context: contextSummary)

            } else if dateRange.count == 2 {
                let startDate = dateRange[0]
                let endDate = dateRange[1]
                Task {
                    await updateStatusMessage("Checking events from \(startDate.formatted(date: .abbreviated, time: .omitted)) to \(endDate.formatted(date: .abbreviated, time: .omitted))...")
                }

                let contextSummary = calendarManager?.getEventsSummary(from: startDate, to: endDate) ?? "No calendar access."
                try await step3_GenerateFinalResponse(context: contextSummary)
            } else {
                Task {
                    await updateStatusMessage("Checking today's events...")
                }

                let dayStart = Calendar.current.startOfDay(for: Date())
                let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
                let contextSummary = calendarManager?.getEventsSummary(from: dayStart, to: dayEnd) ?? "No calendar access."
                try await step3_GenerateFinalResponse(context: contextSummary)
            }
        }

        private func parseDateOrRangeResponse(_ text: String) -> [Date] {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            let rangePattern = #"\d{4}-\d{2}-\d{2},\s?\d{4}-\d{2}-\d{2}"#
            let datePattern = #"\d{4}-\d{2}-\d{2}"#

            if let rangeMatch = text.range(of: rangePattern, options: .regularExpression) {
                let rangeString = String(text[rangeMatch])
                let dates = rangeString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if dates.count == 2,
                   let startDate = dateFormatter.date(from: String(dates[0])),
                   let endDate = dateFormatter.date(from: String(dates[1])) {
                    return [startDate, endDate]
                }
            }

            if let dateMatch = text.range(of: datePattern, options: .regularExpression) {
                let dateString = String(text[dateMatch])
                if let date = dateFormatter.date(from: dateString) {
                    return [date]
                }
            }
            
            return []
        }

    private func step3_GenerateFinalResponse(context: String) async throws {
        guard let utils = modelUtils else { return }
        
        utils.reset()
        
        let finalPrompt = """
        RESPOND TO QUESTIONS:
        
        CONTEXT (Events found):
        \(context)
        
        USER PROMPT:
        "\(storedUserPrompt)"
        
        INSTRUCTIONS:
        Answer the user's prompt naturally using the provided context.
        If there are no events, say so clearly.
        Keep the response concise and friendly.
        """
        
        print("[DEBUG_LOG] --- STEP 3: Generate Final Response ---")
        print("[DEBUG_LOG] Prompt Sent to Model:\n\(finalPrompt)")
        print("[DEBUG_LOG] Streaming Response: ", terminator: "")
        
        let stream = try await utils.generateResponse(prompt: finalPrompt)
        
        var finalResponse = ""
        for try await chunk in stream {
            finalResponse += chunk
            print(chunk, terminator: "")
            await updateStreamingResponse(finalResponse)
        }
        print("\n")
    }

    private func step2_HandleCreation() async throws {
        guard let utils = modelUtils else { return }
        
        utils.reset()
        
        let today = Date().formatted(date: .complete, time: .omitted)
        
        let prompt = """
        EXTRACT EVENT DETAILS.
        Today is: \(today)
        User prompt: "\(storedUserPrompt)"
        
        Format your response EXACTLY like this:
        Title: [Event Title]
        Date: [Date/Time e.g. YYYY-MM-DD HH:MM]
        Location: [Location or "None"]
        Description: [Description or "None"]
        """
        
        print("[DEBUG_LOG] --- STEP 2 (Creation): Extract Details ---")
        print("[DEBUG_LOG] Prompt Sent to Model:\n\(prompt)")
        print("[DEBUG_LOG] Streaming Response: ", terminator: "")
        
        let stream = try await utils.generateResponse(prompt: prompt)
        var fullText = ""
        for try await chunk in stream {
            fullText += chunk
            print(chunk, terminator: "")
            await updateStatusMessage("Analyzing: " + fullText)
        }
        print("\n")

        await MainActor.run {
            self.parseAIResponseToEvent(fullText)
            if !self.messages.isEmpty {
                self.messages.removeLast()
                self.messages.append(Message(role: .model, text: "I've opened the event editor for you."))
            }
        }
    }

    private func step2_HandleDeletion() async throws {
        guard let utils = modelUtils else { return }
        
        utils.reset()
        
        let prompt = """
        IDENTIFY THE EVENT TO DELETE.
        User prompt: "\(storedUserPrompt)"
        
        Reply ONLY with the exact title of the event mentioned.
        """
        
        print("[DEBUG_LOG] --- STEP 2 (Deletion): Identify Event ---")
        print("[DEBUG_LOG] Prompt Sent to Model:\n\(prompt)")
        print("[DEBUG_LOG] Streaming Response: ", terminator: "")
        
        let stream = try await utils.generateResponse(prompt: prompt)
        var eventTitle = ""
        for try await chunk in stream {
            eventTitle += chunk
            print(chunk, terminator: "")
        }
        print("\n")
        
        eventTitle = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        await MainActor.run {
            self.eventToDelete = eventTitle
            if !self.messages.isEmpty {
                self.messages.removeLast()
                self.messages.append(Message(role: .model, text: "I'll help you delete '\(eventTitle)'. Please confirm."))
            }
        }
    }
    
    private func updateStatusMessage(_ text: String) async {
        await MainActor.run {
            if let lastIdx = self.messages.indices.last {
                if self.messages[lastIdx].isThinking {
                    self.messages[lastIdx].text = text
                }
            }
        }
    }

    private func updateStreamingResponse(_ text: String) async {
        await MainActor.run {
            if let lastIdx = self.messages.indices.last {
                if self.messages[lastIdx].role == .model {
                    self.messages[lastIdx].isThinking = false
                    self.messages[lastIdx].text = text
                }
            }
        }
    }
    
    private func parseDateResponse(_ text: String) -> Date {
        let pattern = #"\d{4}-\d{2}-\d{2}"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            let dateStr = String(text[range])
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateStr) ?? Date()
        }
        return Date()
    }

    func analyzeImageForEvent(image: UIImage) {
        guard isModelLoaded, !isGenerating, !isChatProcessing else { return }

        isGenerating = true
        analysisStatus = "Scanning document..."
        
        print("[DEBUG_LOG] --- IMAGE ANALYSIS START ---")
        
        let recognizedText = performOCR(on: image)
        print("[DEBUG_LOG] OCR Text Detected:\n\(recognizedText)")
        
        analysisStatus = "Interpreting details..."
        
        let today = Date().formatted(date: .complete, time: .omitted)
        
        generationTask = Task {
            defer { Task { @MainActor in self.isGenerating = false } }
            do {
                let prompt = """
                Today's date: \(today)
                
                Text: "\(recognizedText)"
                
                
                ONLY OUTPUT IN EXACT FORMAT:
                Title: [Title]
                Date: [Date/Time e.g. YYYY-MM-DD HH:MM]
                Location: [Location] or "None"
                Description: [Summary] or "None"
                
                NOTHING ELSE SHOULD BE IN OUTPUT. NO INTRO.
                """

                
                print("[DEBUG_LOG] Image Prompt:\n\(prompt)")
                print("[DEBUG_LOG] Streaming Response: ", terminator: "")
                
                guard let utils = modelUtils else { return }
                utils.reset()
                
                let stream = try await utils.generateResponse(prompt: prompt)
                var full = ""
                
                for try await chunk in stream {
                    full += chunk
                    print(chunk, terminator: "")
                    await MainActor.run { self.analysisStatus = full }
                }
                print("\n")
                
                await MainActor.run { self.parseAIResponseToEvent(full) }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Analysis failed: \(error.localizedDescription)"
                    print("[DEBUG_LOG] Image Analysis Error: \(error)")
                }
            }
        }
    }
    
    private func performOCR(on image: UIImage) -> String {
        guard let cg = image.cgImage else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])
        return request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") ?? ""
    }
    
    private func parseAIResponseToEvent(_ text: String) {
        var title = "Untitled Event"
        var location = ""
        var description = ""
        var dateString = ""
        
        for line in text.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            if lower.starts(with: "title:") {
                title = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if lower.starts(with: "date:") {
                dateString = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            } else if lower.starts(with: "location:") {
                location = line.dropFirst(9).trimmingCharacters(in: .whitespaces)
            } else if lower.starts(with: "description:") {
                description = line.dropFirst(12).trimmingCharacters(in: .whitespaces)
            }
        }
        
        let date = detectDateInQuery(dateString) ?? Date().addingTimeInterval(3600)
        
        extractedEventData = ParsedEventData(
            title: title,
            date: date,
            location: location,
            notes: description
        )
        
        showEventEditor = true
        selectedUIImage = nil
    }
    
    private func detectDateInQuery(_ query: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let ns = query as NSString
        if let m = detector?.firstMatch(in: query, range: NSRange(location: 0, length: ns.length)),
           let d = m.date {
            return d
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let d = formatter.date(from: query) { return d }
        formatter.dateFormat = "yyyy-MM-dd"
        if let d = formatter.date(from: query) { return d }
        
        return nil
    }
    
    private func handleGenerationError(_ error: Error) async {
        print("[DEBUG_LOG] GENERATION ERROR: \(error)")
        if !messages.isEmpty { messages.removeLast() }
        messages.append(Message(role: .system, text: "Error: \(error.localizedDescription)"))
    }
}
