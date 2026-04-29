import UIKit
import LiveViewKit
import ReplayKit
import Photos
import AVFoundation

class ViewController: UIViewController {
    
    // MARK: - Properties
    private let context = LVContext.sharedInstance()
    private let screenRecorder = RPScreenRecorder.shared()
    
    // UI
    private let imageView = UIImageView()
    private let bottomBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let logoLabel = UILabel()
    
    // Buttons (Left to Right)
    private let captureButton = createActionButton(named: "circle.fill")
    private let inspectorButton = createActionButton(named: "terminal")
    private let toneMappingButton = createActionButton(named: "slider.horizontal.3")
    private let magicSRButton = createActionButton(named: "sparkles.rectangle")
    private let settingsButton = createActionButton(named: "gearshape")
    
    // Fullscreen
    private var isFullScreen = false
    private let tapGesture = UITapGestureRecognizer()
    
    // Constraints
    private lazy var normalConstraints: [NSLayoutConstraint] = {
        return [
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 16.0 / 9.0)
        ]
    }()
    
    private lazy var fullScreenConstraints: [NSLayoutConstraint] = {
        return [
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 16.0 / 9.0)
        ]
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureAudioSession() // 👈 关键：只播放，不录音，强制外放
        
        setupUI()
        setupGestures()
        requestPhotoPermission()
        
        context.delegate = self
        if let _ = context.responds(to: #selector(setter: LVContext.audioInputEnabled)) {
            // 如果 API 支持，显式禁用麦克风
            context.setValue(false, forKey: "audioInputEnabled")
        }
        context.start()
    }
    
    // MARK: - Audio Setup
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.overrideOutputAudioPort(.speaker)
            try session.setActive(true)
        } catch {
            print("⚠️ Audio session error: $error)")
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // Main image view
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        // Tap gesture for fullscreen
        imageView.addGestureRecognizer(tapGesture)
        imageView.isUserInteractionEnabled = true
        
        // Bottom bar
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)
        
        // Logo
        logoLabel.text = "MONICON"
        logoLabel.textColor = .white
        logoLabel.font = .systemFont(ofSize: 16, weight: .bold)
        logoLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.contentView.addSubview(logoLabel)
        
        // Button stack
        let buttons = [captureButton, inspectorButton, toneMappingButton, magicSRButton, settingsButton]
        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .horizontal
        stack.spacing = 16
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.contentView.addSubview(stack)
        
        // Initial constraints (normal mode)
        NSLayoutConstraint.activate(normalConstraints)
        
        // Bottom bar layout
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 80),
            
            logoLabel.leadingAnchor.constraint(equalTo: bottomBar.contentView.layoutMarginsGuide.leadingAnchor),
            logoLabel.bottomAnchor.constraint(equalTo: bottomBar.contentView.bottomAnchor, constant: -10),
            
            stack.trailingAnchor.constraint(equalTo: bottomBar.contentView.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: bottomBar.contentView.centerYAnchor),
            stack.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Button actions
        inspectorButton.addTarget(self, action: #selector(inspectorTapped), for: .touchUpInside)
        toneMappingButton.addTarget(self, action: #selector(toneMappingTapped), for: .touchUpInside)
        magicSRButton.addTarget(self, action: #selector(magicSRTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
    }
    
    private func setupGestures() {
        tapGesture.addTarget(self, action: #selector(imageTapped))
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(captureButtonLongPressed(_:)))
        longPress.minimumPressDuration = 0.5
        captureButton.addGestureRecognizer(longPress)
    }
    
    private func requestPhotoPermission() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
    }
    
    // MARK: - Fullscreen Toggle
    @objc private func imageTapped() {
        isFullScreen.toggle()
        
        NSLayoutConstraint.deactivate(normalConstraints)
        NSLayoutConstraint.deactivate(fullScreenConstraints)
        
        if isFullScreen {
            NSLayoutConstraint.activate(fullScreenConstraints)
            bottomBar.isHidden = true
        } else {
            NSLayoutConstraint.activate(normalConstraints)
            bottomBar.isHidden = false
        }
        
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Capture Actions
    @objc private func captureButtonTapped() {
        guard let image = imageView.image else { return }
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(photoSaved(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func captureButtonLongPressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            startRecording()
        case .ended, .cancelled:
            stopRecording()
        default: break
        }
    }
    
    private func startRecording() {
        guard screenRecorder.isAvailable, !screenRecorder.isRecording else { return }
        screenRecorder.startRecording { [weak self] error in
            if let error = error {
                print("❌ Recording failed: $error)")
            } else {
                DispatchQueue.main.async {
                    self?.captureButton.layer.borderWidth = 2
                    self?.captureButton.layer.borderColor = UIColor.red.cgColor
                }
            }
        }
    }
    
    private func stopRecording() {
        if screenRecorder.isRecording {
            screenRecorder.stopRecording { _, _ in
                DispatchQueue.main.async {
                    self.captureButton.layer.borderWidth = 0
                }
            }
        }
    }
    
    @objc private func photoSaved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        let message = error == nil ? "Screenshot saved." : "Failed to save screenshot."
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Other Button Stubs
    @objc private func inspectorTapped() { print("InInspector") }
    @objc private func toneMappingTapped() { print("Tone Mapping") }
    @objc private func magicSRTapped() { print("Magic SR") }
    @objc private func settingsTapped() { print("Settings") }
    
    // MARK: - Helpers
    private static func createActionButton(named systemName: String) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor(displayP3Red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0) // Orange
        button.layer.cornerRadius = 12
        button.tintColor = .white
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        return button
    }
}

// MARK: - LVContextDelegate
extension ViewController: LVContextDelegate {
    func lvContext(_ context: LVContext!, didOutputPixelBuffer pixelBuffer: CVPixelBuffer!) {
        DispatchQueue.main.async { [weak self] in
            self?.imageView.image = self?.imageFromPixelBuffer(pixelBuffer)
        }
    }
}

// MARK: - PixelBuffer → UIImage
extension ViewController {
    private func imageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer?) -> UIImage? {
        guard let pixelBuffer = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ), let cgImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}
