import Foundation
import CoreLocation
import Vision
import AVFoundation
import EventKit
import Combine

/// Main service for detecting user's environment using multiple sources
class EnvironmentDetectionService: NSObject, ObservableObject {
    static let shared = EnvironmentDetectionService()

    @Published var currentContext: EnvironmentContext?
    @Published var isMonitoring: Bool = false
    @Published var detectionSources: [EnvironmentContext.DetectionSource: Bool] = [:]
    @Published var lastUpdate: Date?

    private let locationService = LocationDetectionService()
    private let visionService = VisionDetectionService()
    private let calendarService = CalendarDetectionService()

    private var cancellables = Set<AnyCancellable>()
    private var contextHistory: [EnvironmentContext] = []

    private override init() {
        super.init()
        setupBindings()
    }

    private func setupBindings() {
        // Combine all detection sources
        locationService.$detectedContext
            .compactMap { $0 }
            .sink { [weak self] context in
                self?.updateContext(context)
            }
            .store(in: &cancellables)

        visionService.$detectedContext
            .compactMap { $0 }
            .sink { [weak self] context in
                self?.updateContext(context)
            }
            .store(in: &cancellables)

        calendarService.$detectedContext
            .compactMap { $0 }
            .sink { [weak self] context in
                self?.updateContext(context)
            }
            .store(in: &cancellables)
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        isMonitoring = true
        locationService.startMonitoring()
        calendarService.startMonitoring()

        detectionSources[.location] = true
        detectionSources[.calendar] = true
    }

    func stopMonitoring() {
        isMonitoring = false
        locationService.stopMonitoring()
        calendarService.stopMonitoring()
    }

    /// Capture and analyze current camera view
    func analyzeCurrentScene() {
        visionService.captureAndAnalyze()
        detectionSources[.vision] = true
    }

    // MARK: - Context Management

    private func updateContext(_ newContext: EnvironmentContext) {
        // Only update if significantly different or higher confidence
        if let current = currentContext {
            if newContext.type == current.type && newContext.confidence <= current.confidence {
                return
            }

            // Require higher confidence to switch context
            if newContext.type != current.type && newContext.confidence < 0.6 {
                return
            }
        }

        // Update context
        currentContext = newContext
        lastUpdate = Date()
        contextHistory.append(newContext)

        // Keep only last 10 contexts
        if contextHistory.count > 10 {
            contextHistory.removeFirst()
        }

        // Send to Apple Watch
        WatchConnectorService.shared.sendContext(newContext)
    }

    /// Manually set environment (user override)
    func setManualContext(_ type: EnvironmentContext.EnvironmentType) {
        let context = EnvironmentContext(
            type: type,
            confidence: 1.0,
            source: .manual,
            timestamp: Date(),
            details: nil
        )
        updateContext(context)
    }

    /// Get context for upcoming calendar event
    func getUpcomingEventContext() -> EnvironmentContext? {
        return calendarService.detectedContext
    }
}

// MARK: - Location Detection Service

class LocationDetectionService: NSObject, ObservableObject {
    @Published var detectedContext: EnvironmentContext?
    @Published var currentLocation: CLLocation?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func startMonitoring() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
    }

    private func analyzeLocation(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let placemark = placemarks?.first else { return }

            let environmentType = self?.determineEnvironmentType(from: placemark) ?? .unknown

            let context = EnvironmentContext(
                type: environmentType,
                confidence: 0.7,
                source: .location,
                timestamp: Date(),
                details: EnvironmentContext.ContextDetails(
                    placeName: placemark.name,
                    address: [placemark.thoroughfare, placemark.locality].compactMap { $0 }.joined(separator: ", "),
                    calendarEvent: nil,
                    sceneDescription: nil
                )
            )

            DispatchQueue.main.async {
                self?.detectedContext = context
            }
        }
    }

    private func determineEnvironmentType(from placemark: CLPlacemark) -> EnvironmentContext.EnvironmentType {
        // Check point of interest categories
        if #available(iOS 16.0, *) {
            // Use newer APIs if available
        }

        // Analyze place name and area of interest
        let name = (placemark.name ?? "").lowercased()
        let areaOfInterest = (placemark.areasOfInterest?.first ?? "").lowercased()
        let combined = name + " " + areaOfInterest

        // Medical
        if combined.contains("hospital") || combined.contains("medical center") || combined.contains("emergency") {
            return .hospital
        }
        if combined.contains("clinic") || combined.contains("doctor") || combined.contains("physician") {
            return .clinic
        }
        if combined.contains("pharmacy") || combined.contains("drugstore") || combined.contains("cvs") || combined.contains("walgreens") {
            return .pharmacy
        }

        // Food
        if combined.contains("restaurant") || combined.contains("diner") || combined.contains("grill") || combined.contains("kitchen") {
            return .restaurant
        }
        if combined.contains("cafe") || combined.contains("coffee") || combined.contains("starbucks") {
            return .cafe
        }

        // Shopping
        if combined.contains("grocery") || combined.contains("supermarket") || combined.contains("market") || combined.contains("whole foods") {
            return .grocery
        }
        if combined.contains("mall") || combined.contains("store") || combined.contains("shop") || combined.contains("target") || combined.contains("walmart") {
            return .retail
        }

        // Transportation
        if combined.contains("airport") || combined.contains("terminal") {
            return .airport
        }
        if combined.contains("station") || combined.contains("transit") || combined.contains("bus") || combined.contains("train") {
            return .publicTransport
        }

        // Other
        if combined.contains("bank") || combined.contains("credit union") {
            return .bank
        }
        if combined.contains("school") || combined.contains("university") || combined.contains("college") {
            return .school
        }
        if combined.contains("gym") || combined.contains("fitness") || combined.contains("workout") {
            return .gym
        }
        if combined.contains("church") || combined.contains("temple") || combined.contains("mosque") || combined.contains("synagogue") {
            return .church
        }
        if combined.contains("library") {
            return .library
        }
        if combined.contains("museum") {
            return .museum
        }
        if combined.contains("theater") || combined.contains("cinema") || combined.contains("movie") {
            return .theater
        }

        return .unknown
    }
}

extension LocationDetectionService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Only analyze if moved significantly (100 meters)
        if let lastLocation = currentLocation {
            if location.distance(from: lastLocation) < 100 {
                return
            }
        }

        currentLocation = location
        analyzeLocation(location)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// MARK: - Vision Detection Service

class VisionDetectionService: ObservableObject {
    @Published var detectedContext: EnvironmentContext?
    @Published var isAnalyzing: Bool = false

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?

    func captureAndAnalyze() {
        // Request camera permission and capture image
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else { return }
            self?.setupCaptureSession()
        }
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        captureSession = session
        photoOutput = output

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()

            // Capture photo after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let settings = AVCapturePhotoSettings()
                output.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func analyzeImage(_ image: CGImage) {
        isAnalyzing = true

        // Use Vision framework for scene classification
        let request = VNClassifyImageRequest { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation] else {
                self?.isAnalyzing = false
                return
            }

            // Get top classifications
            let topResults = results.prefix(5)
            let environmentType = self?.mapClassificationToEnvironment(topResults) ?? .unknown
            let confidence = topResults.first?.confidence ?? 0

            let context = EnvironmentContext(
                type: environmentType,
                confidence: Double(confidence),
                source: .vision,
                timestamp: Date(),
                details: EnvironmentContext.ContextDetails(
                    placeName: nil,
                    address: nil,
                    calendarEvent: nil,
                    sceneDescription: topResults.map { "\($0.identifier): \(Int($0.confidence * 100))%" }.joined(separator: ", ")
                )
            )

            DispatchQueue.main.async {
                self?.detectedContext = context
                self?.isAnalyzing = false
            }
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
    }

    private func mapClassificationToEnvironment(_ classifications: ArraySlice<VNClassificationObservation>) -> EnvironmentContext.EnvironmentType {
        for classification in classifications {
            let label = classification.identifier.lowercased()

            // Medical
            if label.contains("hospital") || label.contains("medical") || label.contains("clinic") {
                return .hospital
            }

            // Food service
            if label.contains("restaurant") || label.contains("dining") || label.contains("food court") {
                return .restaurant
            }
            if label.contains("coffee") || label.contains("cafe") {
                return .cafe
            }

            // Retail
            if label.contains("store") || label.contains("shop") || label.contains("mall") || label.contains("supermarket") {
                return .retail
            }

            // Transportation
            if label.contains("airport") || label.contains("terminal") {
                return .airport
            }
            if label.contains("train") || label.contains("bus") || label.contains("subway") || label.contains("station") {
                return .publicTransport
            }

            // Office
            if label.contains("office") || label.contains("conference") || label.contains("meeting") {
                return .office
            }

            // Education
            if label.contains("classroom") || label.contains("school") || label.contains("library") {
                return .school
            }

            // Outdoors
            if label.contains("park") || label.contains("outdoor") || label.contains("street") || label.contains("sidewalk") {
                return .outdoors
            }

            // Home
            if label.contains("living room") || label.contains("bedroom") || label.contains("kitchen") || label.contains("home") {
                return .home
            }
        }

        return .unknown
    }
}

extension VisionDetectionService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        captureSession?.stopRunning()

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            return
        }

        analyzeImage(cgImage)
    }
}

// MARK: - Calendar Detection Service

class CalendarDetectionService: ObservableObject {
    @Published var detectedContext: EnvironmentContext?

    private let eventStore = EKEventStore()
    private var timer: Timer?

    func startMonitoring() {
        requestAccess()

        // Check calendar every 5 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkUpcomingEvents()
        }

        // Initial check
        checkUpcomingEvents()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func requestAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                if granted {
                    self.checkUpcomingEvents()
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                if granted {
                    self.checkUpcomingEvents()
                }
            }
        }
    }

    private func checkUpcomingEvents() {
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: now)!

        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        // Find the most relevant upcoming event
        guard let nextEvent = events.first else { return }

        let environmentType = determineEnvironmentType(from: nextEvent)

        let context = EnvironmentContext(
            type: environmentType,
            confidence: 0.8,
            source: .calendar,
            timestamp: Date(),
            details: EnvironmentContext.ContextDetails(
                placeName: nextEvent.location,
                address: nil,
                calendarEvent: nextEvent.title,
                sceneDescription: nil
            )
        )

        DispatchQueue.main.async {
            self.detectedContext = context
        }
    }

    private func determineEnvironmentType(from event: EKEvent) -> EnvironmentContext.EnvironmentType {
        let title = (event.title ?? "").lowercased()
        let location = (event.location ?? "").lowercased()
        let combined = title + " " + location

        // Medical appointments
        if combined.contains("doctor") || combined.contains("medical") || combined.contains("hospital") ||
           combined.contains("appointment") || combined.contains("checkup") || combined.contains("therapy") {
            return .hospital
        }

        // Work
        if combined.contains("meeting") || combined.contains("conference") || combined.contains("office") ||
           combined.contains("work") || combined.contains("call") {
            return .office
        }

        // School
        if combined.contains("class") || combined.contains("school") || combined.contains("lecture") ||
           combined.contains("study") {
            return .school
        }

        // Fitness
        if combined.contains("gym") || combined.contains("workout") || combined.contains("fitness") ||
           combined.contains("exercise") || combined.contains("yoga") {
            return .gym
        }

        // Religious
        if combined.contains("church") || combined.contains("service") || combined.contains("temple") ||
           combined.contains("mass") {
            return .church
        }

        // Food
        if combined.contains("lunch") || combined.contains("dinner") || combined.contains("breakfast") ||
           combined.contains("restaurant") || combined.contains("cafe") {
            return .restaurant
        }

        // Travel
        if combined.contains("flight") || combined.contains("airport") {
            return .airport
        }

        return .unknown
    }
}
