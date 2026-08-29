import AVFoundation
import Foundation

final class AudioBufferConverter: @unchecked Sendable {
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var outputFormat: AVAudioFormat?
    private let lock = NSLock()

    func convert(_ buffer: AVAudioPCMBuffer, to outputFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        lock.lock()
        defer { lock.unlock() }

        if buffer.format == outputFormat {
            return buffer
        }

        if converter == nil || inputFormat != buffer.format || self.outputFormat != outputFormat {
            converter = AVAudioConverter(from: buffer.format, to: outputFormat)
            inputFormat = buffer.format
            self.outputFormat = outputFormat
        }
        guard let converter else { return nil }

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up) + 32)
        guard let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        var error: NSError?
        var consumed = false
        converter.convert(to: converted, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if error != nil {
            return nil
        }
        return converted
    }
}
