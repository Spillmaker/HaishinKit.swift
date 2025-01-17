import AVFoundation
import CoreImage
import CoreMedia
import UIKit

/// The interface a NetStream uses to inform its delegate.
public protocol NetStreamDelegate: AnyObject {
    /// Tells the receiver to session was interrupted.
    func stream(
        _ stream: NetStream,
        sessionWasInterrupted session: AVCaptureSession,
        reason: AVCaptureSession.InterruptionReason?
    )
    /// Tells the receiver to session interrupted ended.
    func stream(_ stream: NetStream, sessionInterruptionEnded session: AVCaptureSession)
    /// Tells the receiver to video codec error occured.
    func stream(_ stream: NetStream, videoCodecErrorOccurred error: VideoCodec.Error)
    /// Tells the receiver to audio codec error occured.
    func stream(_ stream: NetStream, audioCodecErrorOccurred error: AudioCodec.Error)
    /// Tells the receiver to will drop video frame.
    func streamWillDropFrame(_ stream: NetStream) -> Bool
    /// Tells the receiver to the stream opened.
    func streamDidOpen(_ stream: NetStream)
    func stream(_ stream: NetStream, audioLevel: Float, numberOfAudioChannels: Int)
    func stream(_ stream: NetStream, recorderErrorOccured error: IORecorder.Error)
    func stream(_ stream: NetStream, recorderFinishWriting writer: AVAssetWriter)
}

/// The `NetStream` class is the foundation of a RTMPStream, HTTPStream.
open class NetStream: NSObject {
    /// The lockQueue.
    public let lockQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetStream.lock")
        queue.setSpecific(key: queueKey, value: queueValue)
        return queue
    }()

    private static let queueKey = DispatchSpecificKey<UnsafeMutableRawPointer>()
    private static let queueValue = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)

    /// The mixer object.
    public private(set) lazy var mixer: IOMixer = {
        let mixer = IOMixer()
        mixer.delegate = self
        return mixer
    }()

    /// Specifies the delegate of the NetStream.
    public weak var delegate: (any NetStreamDelegate)?
    /// Specifies the context object.
    public var context: CIContext {
        get {
            mixer.video.context
        }
        set {
            mixer.video.context = newValue
        }
    }

    /// Specifiet the device torch indicating wheter the turn on(TRUE) or not(FALSE).
    public var torch: Bool {
        get {
            var torch: Bool = false
            lockQueue.sync {
                torch = self.mixer.video.torch
            }
            return torch
        }
        set {
            lockQueue.async {
                self.mixer.video.torch = newValue
            }
        }
    }

    /// Specifies the frame rate of a device capture.
    public var frameRate: Float64 {
        get {
            var frameRate: Float64 = IOMixer.defaultFrameRate
            lockQueue.sync {
                frameRate = self.mixer.video.frameRate
            }
            return frameRate
        }
        set {
            lockQueue.async {
                self.mixer.video.frameRate = newValue
            }
        }
    }

    /// Specifies if appleLog should be used.
    public func setColorSpace(colorSpace: AVCaptureColorSpace, onComplete: @escaping () -> Void) {
        lockQueue.async {
            self.mixer.video.colorSpace = colorSpace
            onComplete()
        }
    }

    /// Specifies the sessionPreset for the AVCaptureSession.
    public var sessionPreset: AVCaptureSession.Preset {
        get {
            var sessionPreset: AVCaptureSession.Preset = .default
            lockQueue.sync {
                sessionPreset = self.mixer.sessionPreset
            }
            return sessionPreset
        }
        set {
            lockQueue.async {
                self.mixer.sessionPreset = newValue
            }
        }
    }

    /// Specifies the video orientation for stream.
    public var videoOrientation: AVCaptureVideoOrientation {
        get {
            mixer.video.videoOrientation
        }
        set {
            mixer.video.videoOrientation = newValue
        }
    }

    /// Specifies the hasAudio indicies whether no signal audio or not.
    public var hasAudio: Bool {
        get {
            !mixer.audio.muted
        }
        set {
            mixer.audio.muted = !newValue
        }
    }

    /// Specifies the hasVideo indicies whether freeze video signal or not.
    public var hasVideo: Bool {
        get {
            !mixer.video.muted
        }
        set {
            mixer.video.muted = !newValue
        }
    }

    /// Specifies the audio compression properties.
    public var audioSettings: AudioCodecSettings {
        get {
            mixer.audio.codec.settings
        }
        set {
            mixer.audio.codec.settings = newValue
        }
    }

    /// Specifies the video compression properties.
    public var videoSettings: VideoCodecSettings {
        get {
            mixer.video.codec.settings
        }
        set {
            mixer.video.codec.settings = newValue
        }
    }

    /// Creates a NetStream object.
    override public init() {
        super.init()
    }

    /// Attaches the primary camera object.
    /// - Warning: This method can't use appendSampleBuffer at the same time.
    open func attachCamera(
        _ device: AVCaptureDevice?,
        onError: ((_ error: Error) -> Void)? = nil,
        onSuccess: (() -> Void)? = nil,
        replaceVideoCameraId: UUID? = nil
    ) {
        lockQueue.async {
            do {
                try self.mixer.video.attachCamera(device, replaceVideoCameraId)
                onSuccess?()
            } catch {
                onError?(error)
            }
        }
    }

    /// Attaches the audio capture object.
    /// - Warning: This method can't use appendSampleBuffer at the same time.
    open func attachAudio(
        _ device: AVCaptureDevice?,
        automaticallyConfiguresApplicationAudioSession: Bool = false,
        onError: ((_ error: Error) -> Void)? = nil
    ) {
        lockQueue.sync {
            do {
                try self.mixer.audio.attachAudio(
                    device,
                    automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession
                )
            } catch {
                onError?(error)
            }
        }
    }

    /// Append a video sample buffer.
    /// - Warning: This method can't use attachCamera or attachAudio method at the same time.
    open func addReplaceVideoSampleBuffer(id: UUID, _ sampleBuffer: CMSampleBuffer) {
        mixer.video.lockQueue.async {
            self.mixer.video.addReplaceVideoSampleBuffer(id: id, sampleBuffer)
        }
    }

    open func addReplaceVideo(cameraId: UUID, latency: Double) {
        mixer.video.lockQueue.async {
            self.mixer.video.addReplaceVideo(cameraId: cameraId, latency: latency)
        }
    }

    open func removeReplaceVideo(cameraId: UUID) {
        mixer.video.lockQueue.async {
            self.mixer.video.removeReplaceVideo(cameraId: cameraId)
        }
    }

    /// Returns the IOVideoCaptureUnit by index.
    public func videoCapture() -> IOVideoCaptureUnit? {
        return mixer.video.lockQueue.sync {
            self.mixer.video.capture
        }
    }

    /// Register a video effect.
    public func registerVideoEffect(_ effect: VideoEffect) -> Bool {
        mixer.video.lockQueue.sync {
            self.mixer.video.registerEffect(effect)
        }
    }

    /// Unregister a video effect.
    public func unregisterVideoEffect(_ effect: VideoEffect) -> Bool {
        mixer.video.lockQueue.sync {
            self.mixer.video.unregisterEffect(effect)
        }
    }

    /// Starts recording.
    public func startRecording(
        url: URL,
        _ settings: [AVMediaType: [String: Any]] = IORecorder.defaultOutputSettings
    ) {
        mixer.recorder.url = url
        mixer.recorder.outputSettings = settings
        mixer.recorder.startRunning()
    }

    /// Stop recording.
    public func stopRecording() {
        mixer.recorder.stopRunning()
    }
}

extension NetStream: IOMixerDelegate {
    func mixer(
        _: IOMixer,
        sessionWasInterrupted session: AVCaptureSession,
        reason: AVCaptureSession.InterruptionReason?
    ) {
        delegate?.stream(self, sessionWasInterrupted: session, reason: reason)
    }

    func mixer(_: IOMixer, sessionInterruptionEnded session: AVCaptureSession) {
        delegate?.stream(self, sessionInterruptionEnded: session)
    }

    func mixer(_: IOMixer, audioLevel: Float, numberOfAudioChannels: Int) {
        delegate?.stream(self, audioLevel: audioLevel, numberOfAudioChannels: numberOfAudioChannels)
    }

    func mixer(_: IOMixer, recorderErrorOccured error: IORecorder.Error) {
        delegate?.stream(self, recorderErrorOccured: error)
    }

    func mixer(_: IOMixer, recorderFinishWriting writer: AVAssetWriter) {
        delegate?.stream(self, recorderFinishWriting: writer)
    }
}
