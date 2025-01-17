import Foundation

struct AVCFormatStream {
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init?(bytes: UnsafePointer<UInt8>, count: UInt32) {
        self.init(data: Data(bytes: bytes, count: Int(count)))
    }

    init?(data: Data?) {
        guard let data = data else {
            return nil
        }
        self.init(data: data)
    }

    func toByteStream() -> Data {
        let buffer = ByteArray(data: data)
        var result = Data()
        while buffer.bytesAvailable > 0 {
            do {
                let length: Int = try Int(buffer.readUInt32())
                result.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
                try result.append(buffer.readBytes(length))
            } catch {
                logger.error("\(buffer)")
            }
        }
        return result
    }

    static func toNALFileFormat(_ data: inout Data) -> Data {
        var lastIndexOf = data.count - 1
        for i in (2 ..< data.count).reversed() {
            guard data[i] == 1 && data[i - 1] == 0 && data[i - 2] == 0 else {
                continue
            }
            let startCodeLength = i - 3 >= 0 && data[i - 3] == 0 ? 4 : 3
            let start = 4 - startCodeLength
            let length = lastIndexOf - i
            if length > 0 {
                data.replaceSubrange(
                    i - startCodeLength + 1 ... i,
                    with: Int32(length).bigEndian.data[start...]
                )
                lastIndexOf = i - startCodeLength
            }
        }
        return data
    }
}
