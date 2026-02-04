import Foundation
import AVFoundation

/// Utility for converting raw PCM audio data to WAV format
struct AudioConverter {
    /// Gemini TTS returns raw PCM 16-bit signed integer at 24kHz
    static let defaultSampleRate: Int = 24000
    static let defaultBitsPerSample: Int = 16
    static let defaultNumChannels: Int = 1

    /// Convert raw PCM audio data to WAV format
    /// - Parameters:
    ///   - pcmData: Raw PCM audio bytes (16-bit signed integer)
    ///   - sampleRate: Sample rate in Hz (default: 24000)
    ///   - bitsPerSample: Bits per sample (default: 16)
    ///   - numChannels: Number of audio channels (default: 1 for mono)
    /// - Returns: WAV format audio data with proper header
    static func pcmToWAV(
        pcmData: Data,
        sampleRate: Int = defaultSampleRate,
        bitsPerSample: Int = defaultBitsPerSample,
        numChannels: Int = defaultNumChannels
    ) -> Data {
        var wavData = Data()

        let byteRate = sampleRate * numChannels * (bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = pcmData.count
        let fileSize = 36 + dataSize

        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        wavData.append(contentsOf: "WAVE".utf8)

        // fmt subchunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // Subchunk1Size (16 for PCM)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // AudioFormat (1 for PCM)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Array($0) })

        // data subchunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        wavData.append(pcmData)

        return wavData
    }

    /// Decode base64 encoded audio data
    /// - Parameter base64String: Base64 encoded audio data
    /// - Returns: Decoded Data or nil if decoding fails
    static func decodeBase64(_ base64String: String) -> Data? {
        Data(base64Encoded: base64String)
    }

    /// Convert base64 PCM to WAV format ready for playback
    /// - Parameter base64PCM: Base64 encoded raw PCM audio
    /// - Returns: WAV format Data ready for AVAudioPlayer
    static func base64PCMToWAV(_ base64PCM: String) -> Data? {
        guard let pcmData = decodeBase64(base64PCM) else {
            return nil
        }
        return pcmToWAV(pcmData: pcmData)
    }

    /// Calculate audio duration from PCM data
    /// - Parameters:
    ///   - pcmData: Raw PCM audio data
    ///   - sampleRate: Sample rate in Hz
    ///   - bitsPerSample: Bits per sample
    ///   - numChannels: Number of channels
    /// - Returns: Duration in seconds
    static func calculateDuration(
        pcmData: Data,
        sampleRate: Int = defaultSampleRate,
        bitsPerSample: Int = defaultBitsPerSample,
        numChannels: Int = defaultNumChannels
    ) -> TimeInterval {
        let bytesPerSample = bitsPerSample / 8
        let totalSamples = pcmData.count / (bytesPerSample * numChannels)
        return TimeInterval(totalSamples) / TimeInterval(sampleRate)
    }
}
