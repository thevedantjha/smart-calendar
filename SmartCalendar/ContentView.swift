import SwiftUI
import PhotosUI
import EventKit

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var calendarManager = CalendarManager()
    
    @State private var showCamera = false
    @State private var showChatMode = false
    @State private var inputImage: UIImage?

    @State private var isPulsing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(Date(), style: .date)
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .textCase(.uppercase)
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.largeTitle)
                                Text("My Schedule")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                            }
                        }
                        Spacer()
                        
                        if viewModel.isModelLoaded {
                            Circle().fill(Color.green).frame(width: 10, height: 10)
                        } else {
                            ProgressView()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            if calendarManager.upcomingEvents.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(calendarManager.upcomingEvents, id: \.eventIdentifier) { event in
                                    EventCard(event: event)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()

                    HStack(spacing: 20) {
                        Button(action: { showCamera = true }) {
                            VStack {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 24))
                                Text("Scan Flyer")
                                    .font(.caption)
                            }
                            .frame(width: 100, height: 80)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(15)
                        }
                        .disabled(viewModel.isGenerating)
                        
                        Button(action: { showChatMode = true }) {
                            HStack {
                                Image(systemName: "bubble.left.fill")
                                Text("Talk to Calendar")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(radius: 5)
                        }
                    }
                    .padding()
                }

                if viewModel.isGenerating && !showChatMode {
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()

                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 30) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 100, height: 100)
                                    .scaleEffect(isPulsing ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
                                
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 40))
                                    .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                            .onAppear { isPulsing = true }
                            
                            VStack(spacing: 8) {
                                Text("Scanning Flyer")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("Extracting dates, times, and locations...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("LIVE OUTPUT")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                        .padding(.bottom, 5)
                                    Spacer()
                                    if !viewModel.analysisStatus.isEmpty {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    }
                                }
                                
                                ScrollView {
                                    Text(viewModel.analysisStatus.isEmpty ? "Waiting for AI..." : viewModel.analysisStatus)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                        .animation(.default, value: viewModel.analysisStatus)
                                }
                                .frame(height: 120)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground).opacity(0.9))
                            .cornerRadius(16)
                            .padding(.horizontal, 40)
                            .shadow(radius: 20)
                            
                            Button(action: {
                                withAnimation {
                                    viewModel.stopGeneration()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Cancel Scanning")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.8))
                                .clipShape(Capsule())
                            }
                            .padding(.top, 10)
                        }
                    }
                    .transition(.opacity.animation(.easeInOut))
                    .zIndex(100)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(selectedImage: $inputImage)
            }
            .onChange(of: inputImage) { _, newImage in
                if let img = newImage {
                    viewModel.analyzeImageForEvent(image: img)
                }
            }
            .sheet(isPresented: $viewModel.showEventEditor) {
                if let data = viewModel.extractedEventData {
                    EventEditorView(data: data, manager: calendarManager) { createdTitle in
                        let msg = Message(role: .system, text: "Created event: \(createdTitle)")
                        viewModel.messages.append(msg)
                    }
                }
            }
            .sheet(isPresented: $showChatMode) {
                ChatSheetView(viewModel: viewModel, calendarManager: calendarManager)
            }
            .onAppear {
                viewModel.calendarManager = calendarManager
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No upcoming events")
                .font(.headline)
                .foregroundColor(.gray)
            Text("Scan a flyer or talk to the AI to add one!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(15)
    }
}

struct EventCard: View {
    let event: EKEvent
    
    var body: some View {
        HStack(spacing: 15) {
            VStack {
                Text(event.startDate, format: .dateTime.month())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                Text(event.startDate, format: .dateTime.day())
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .frame(width: 50, height: 50)
            .background(Color.red.opacity(0.1))
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let loc = event.location, !loc.isEmpty {
                    Text(loc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(event.startDate, style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct PulsingGradientIcon: View {
    @Binding var isPulsing: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 100, height: 100)
                .scaleEffect(isPulsing ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
            
            Image(systemName: "wand.and.stars")
                .font(.system(size: 40))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}

struct ChatSheetView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isInputFocused: Bool

    @State private var showDeleteAlert = false
    @State private var pendingDeleteTitle = ""
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(UIColor.systemGray4))
                    }
                }
                .padding()
                
                Spacer()

                Group {
                    if viewModel.messages.isEmpty {
                        inputView
                    } else if viewModel.isChatProcessing || isSystemProcessing {
                        processingView
                    } else {
                        resultView
                    }
                }
                .transition(.opacity.animation(.easeInOut))
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
             viewModel.resetChat()
        }
        .onChange(of: viewModel.eventToDelete) { _, title in
            if let title = title {
                pendingDeleteTitle = title
                showDeleteAlert = true
                viewModel.eventToDelete = nil
            }
        }
        .alert("Delete Event?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                calendarManager.deleteEvent(title: pendingDeleteTitle)
                viewModel.messages.append(Message(role: .system, text: "Deleted event: \(pendingDeleteTitle)"))
            }
        } message: {
            Text("Are you sure you want to delete '\(pendingDeleteTitle)'? This cannot be undone.")
        }
    }

    var isSystemProcessing: Bool {
        guard let last = viewModel.messages.last else { return false }
        return last.isThinking
    }

    var inputView: some View {
        VStack(spacing: 25) {
            Text("Ask your Calendar")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Check your schedule, add events, or delete plans.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack {
                TextField("What would you like to do?", text: $viewModel.inputParam)
                    .font(.title3)
                    .padding()
                    .frame(height: 60)
                    .focused($isInputFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        if !viewModel.inputParam.isEmpty {
                            viewModel.sendMessage(userQuery: viewModel.inputParam)
                        }
                    }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            Button(action: {
                viewModel.sendMessage(userQuery: viewModel.inputParam)
            }) {
                Text("Send Request")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.inputParam.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .disabled(viewModel.inputParam.isEmpty)
            .padding(.horizontal, 20)
        }
    }

    var processingView: some View {
        VStack(spacing: 30) {
            PulsingGradientIcon(isPulsing: $viewModel.isGenerating)

            if let lastMsg = viewModel.messages.last {
                Text(lastMsg.text)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity)
                    .animation(.easeIn(duration: 0.1), value: lastMsg.text)
            }

            Button(action: {
                viewModel.stopGeneration()
            }) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("Stop Generating")
                }
                .fontWeight(.medium)
                .foregroundColor(.red)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(30)
            }
            .padding(.top, 20)
        }
    }

    var resultView: some View {
        VStack(spacing: 30) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let lastMsg = viewModel.messages.last {
                        Text(lastMsg.text)
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                            .animation(.default, value: lastMsg.text)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 400)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(20)
            .padding(.horizontal)

            Button(action: {
                withAnimation {
                    viewModel.resetChat()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Ask Something Else")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(16)
            }
            .padding(.horizontal, 20)
        }
    }
}
