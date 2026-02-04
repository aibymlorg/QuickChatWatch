import SwiftUI
import AVFoundation

/// Camera view for real-time scene analysis
struct CameraAnalysisView: View {
    @EnvironmentObject var environmentDetector: EnvironmentDetectionService
    @Environment(\.dismiss) var dismiss

    @State private var isAnalyzing = false
    @State private var analysisResult: EnvironmentContext?

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                CameraPreviewView()
                    .ignoresSafeArea()

                // Overlay
                VStack {
                    Spacer()

                    // Result card
                    if let result = analysisResult {
                        resultCard(result)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Capture button
                    HStack {
                        Spacer()

                        Button {
                            analyzeScene()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)

                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 80, height: 80)

                                if isAnalyzing {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.title)
                                        .foregroundColor(.black)
                                }
                            }
                        }
                        .disabled(isAnalyzing)

                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Scan Environment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                if analysisResult != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use") {
                            if let result = analysisResult {
                                environmentDetector.setManualContext(result.type)
                            }
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func resultCard(_ result: EnvironmentContext) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: result.type.icon)
                    .font(.title2)
                    .foregroundColor(.cyan)

                Text(result.type.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(Int(result.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let description = result.details?.sceneDescription {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Preview phrases
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(result.type.suggestedPhrases.prefix(4), id: \.self) { phrase in
                        Text(phrase)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
    }

    private func analyzeScene() {
        isAnalyzing = true

        // Trigger camera analysis
        environmentDetector.analyzeCurrentScene()

        // Simulate analysis delay and get result
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isAnalyzing = false
            analysisResult = environmentDetector.currentContext
        }
    }
}

/// Camera preview using AVCaptureSession
struct CameraPreviewView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = CameraUIView()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

class CameraUIView: UIView {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)

        self.captureSession = session
        self.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    deinit {
        captureSession?.stopRunning()
    }
}

#Preview {
    CameraAnalysisView()
        .environmentObject(EnvironmentDetectionService.shared)
}
