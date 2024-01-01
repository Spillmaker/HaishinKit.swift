import AVFoundation

/// The HTTPStream class represents an HLS playlist and .ts files.
open class HTTPStream: NetStream {
    /// For appendSampleBuffer, specifies whether media contains types .video or .audio.
    public var expectedMedias: Set<AVMediaType> {
        get {
            tsWriter.expectedMedias
        }
        set {
            tsWriter.expectedMedias = newValue
        }
    }

    /// The name of stream.
    private(set) var name: String?
    private lazy var tsWriter = TSFileWriter()

    open func publish(_ name: String?) {
        lockQueue.async {
            if name == nil {
                self.name = name
                self.mixer.stopEncoding()
                self.tsWriter.stopRunning()
                return
            }
            self.name = name
            self.mixer.startEncoding(self.tsWriter)
            self.mixer.startRunning()
            self.tsWriter.startRunning()
        }
    }

    #if os(iOS) || os(macOS)
        override open func attachCamera(
            _ device: AVCaptureDevice?,
            onError: ((Error) -> Void)? = nil,
            onSuccess: (() -> Void)? = nil,
            replaceVideoCameraId _: UUID? = nil
        ) {
            if device == nil {
                tsWriter.expectedMedias.remove(.video)
            } else {
                tsWriter.expectedMedias.insert(.video)
            }
            super.attachCamera(device, onError: onError, onSuccess: onSuccess)
        }

        override open func attachAudio(
            _ device: AVCaptureDevice?,
            automaticallyConfiguresApplicationAudioSession: Bool = true,
            onError: ((Error) -> Void)? = nil
        ) {
            if device == nil {
                tsWriter.expectedMedias.remove(.audio)
            } else {
                tsWriter.expectedMedias.insert(.audio)
            }
            super.attachAudio(
                device,
                automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession,
                onError: onError
            )
        }
    #endif

    func getResource(_ resourceName: String) -> (MIME, String)? {
        let url = URL(fileURLWithPath: resourceName)
        guard let name: String = name, url.pathComponents.count >= 2 && url.pathComponents[1] == name else {
            return nil
        }
        let fileName: String = url.pathComponents.last!
        switch true {
        case fileName == "playlist.m3u8":
            return (.applicationXMpegURL, tsWriter.playlist)
        case fileName.contains(".ts"):
            if let mediaFile: String = tsWriter.getFilePath(fileName) {
                return (.videoMP2T, mediaFile)
            }
            return nil
        default:
            return nil
        }
    }
}
