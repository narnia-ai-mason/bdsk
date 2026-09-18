import AudioToolbox
import AVFoundation
import CoreAudio
import Foundation

enum AudioInputPreference {
    static let systemDefaultUID = ""
    private static let uidKey = "audioInputDeviceUID"
    private static let nameKey = "audioInputDeviceName"

    static var uid: String {
        UserDefaults.standard.string(forKey: uidKey) ?? systemDefaultUID
    }

    static var name: String {
        UserDefaults.standard.string(forKey: nameKey) ?? ""
    }

    static func set(uid: String, name: String) {
        UserDefaults.standard.set(uid, forKey: uidKey)
        UserDefaults.standard.set(name, forKey: nameKey)
    }
}

enum AudioInput {
    struct Device: Hashable, Identifiable, Sendable {
        var id: String { uid }
        let deviceID: AudioDeviceID
        let uid: String
        let name: String
        let transport: Transport

        enum Transport: Sendable {
            case builtIn
            case usb
            case bluetooth
            case aggregate
            case other

            var label: String? {
                switch self {
                case .bluetooth: return "블루투스"
                case .usb: return "USB"
                case .builtIn, .aggregate, .other: return nil
                }
            }

            var opensHandsFree: Bool {
                self == .bluetooth
            }
        }

        var pickerTitle: String {
            if let label = transport.label {
                return "\(name) · \(label)"
            }
            return name
        }
    }

    /// Bluetooth devices are listed, but their input streams are not probed.
    /// Reading stream configuration on a headset opens HFP and knocks A2DP off.
    static func devices() -> [Device] {
        deviceIDs()
            .compactMap(describe)
            .filter { $0.transport.opensHandsFree || hasInputChannels($0.deviceID) }
            .sorted(by: listOrder)
    }

    private static func listOrder(_ lhs: Device, _ rhs: Device) -> Bool {
        if lhs.transport.opensHandsFree != rhs.transport.opensHandsFree {
            return !lhs.transport.opensHandsFree
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    static func defaultDevice() -> Device? {
        guard let id = defaultInputID() else { return nil }
        return describe(id)
    }

    static func hasAnyInput() -> Bool {
        resolvedCaptureDevice() != nil
    }

    static func resolve(uid: String, devices: [Device]) -> Device? {
        guard !uid.isEmpty else { return nil }
        return devices.first { $0.uid == uid }
    }

    static func effectiveUID(preferred: String, devices: [Device]) -> String {
        resolve(uid: preferred, devices: devices)?.uid ?? AudioInputPreference.systemDefaultUID
    }

    static func resolvedDevice(
        preferredUID: String,
        devices: [Device],
        defaultDevice: Device?
    ) -> Device? {
        if let preferred = resolve(uid: preferredUID, devices: devices) {
            return preferred
        }
        if let defaultDevice,
           !defaultDevice.transport.opensHandsFree,
           devices.contains(where: { $0.uid == defaultDevice.uid }) || devices.isEmpty
        {
            if let match = devices.first(where: { $0.uid == defaultDevice.uid }) {
                return match
            }
            return defaultDevice
        }
        return devices.first { $0.transport == .usb }
            ?? devices.first { $0.transport == .builtIn }
            ?? devices.first
    }

    static func resolvedCaptureDevice() -> Device? {
        resolvedDevice(
            preferredUID: AudioInputPreference.uid,
            devices: devices(),
            defaultDevice: defaultDevice()
        )
    }

    @MainActor
    static func startCapture() throws -> AudioInputCapture {
        guard let device = resolvedCaptureDevice() else {
            throw DictationSessionError.noAudioInput
        }
        return try AudioInputCapture.start(device: device)
    }

    static func observeChanges(_ handler: @escaping @MainActor () -> Void) -> AudioInputObservation {
        AudioInputObservation(handler: handler)
    }

    private static func deviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &dataSize) == noErr else {
            return []
        }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &dataSize, &ids) == noErr else {
            return []
        }
        return ids
    }

    private static func defaultInputID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private static func describe(_ deviceID: AudioDeviceID) -> Device? {
        guard let uid = stringProperty(deviceID, kAudioDevicePropertyDeviceUID), !uid.isEmpty else {
            return nil
        }
        let name = stringProperty(deviceID, kAudioObjectPropertyName)
            ?? stringProperty(deviceID, kAudioDevicePropertyDeviceNameCFString)
            ?? uid
        return Device(
            deviceID: deviceID,
            uid: uid,
            name: name,
            transport: transport(of: deviceID)
        )
    }

    private static func transport(of deviceID: AudioDeviceID) -> Device.Transport {
        guard let raw = uint32Property(deviceID, kAudioDevicePropertyTransportType) else {
            return .other
        }
        switch raw {
        case kAudioDeviceTransportTypeBuiltIn:
            return .builtIn
        case kAudioDeviceTransportTypeUSB:
            return .usb
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return .bluetooth
        case kAudioDeviceTransportTypeAggregate:
            return .aggregate
        default:
            return .other
        }
    }

    private static func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0
        else {
            return false
        }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, raw) == noErr else {
            return false
        }
        let list = raw.assumingMemoryBound(to: AudioBufferList.self)
        return UnsafeMutableAudioBufferListPointer(list).contains { $0.mNumberChannels > 0 }
    }

    private static func stringProperty(
        _ deviceID: AudioDeviceID,
        _ selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: CFString?
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        guard status == noErr else { return nil }
        return value as String?
    }

    private static func uint32Property(
        _ deviceID: AudioDeviceID,
        _ selector: AudioObjectPropertySelector
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        guard status == noErr else { return nil }
        return value
    }
}

@MainActor
final class AudioInputCapture {
    let format: AVAudioFormat
    private var unit: AudioUnit?
    private let state: AudioInputCaptureState

    fileprivate init(format: AVAudioFormat, unit: AudioUnit, state: AudioInputCaptureState) {
        self.format = format
        self.unit = unit
        self.state = state
    }

    static func start(device: AudioInput.Device) throws -> AudioInputCapture {
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard let component = AudioComponentFindNext(nil, &desc) else {
            throw DictationSessionError.noAudioInput
        }
        var unit: AudioUnit?
        guard AudioComponentInstanceNew(component, &unit) == noErr, let unit else {
            throw DictationSessionError.noAudioInput
        }

        func tearDownAndThrow(_ error: DictationSessionError) throws -> Never {
            AudioComponentInstanceDispose(unit)
            throw error
        }

        var enable: UInt32 = 1
        var disable: UInt32 = 0
        let uintSize = UInt32(MemoryLayout<UInt32>.size)
        guard AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            1,
            &enable,
            uintSize
        ) == noErr else {
            try tearDownAndThrow(.formatUnavailable)
        }
        guard AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            0,
            &disable,
            uintSize
        ) == noErr else {
            try tearDownAndThrow(.formatUnavailable)
        }

        var deviceID = device.deviceID
        guard AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        ) == noErr else {
            try tearDownAndThrow(.noAudioInput)
        }

        var hardware = AudioStreamBasicDescription()
        var asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioUnitGetProperty(
            unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            1,
            &hardware,
            &asbdSize
        ) == noErr, hardware.mSampleRate > 0, hardware.mChannelsPerFrame > 0 else {
            try tearDownAndThrow(.formatUnavailable)
        }

        var client = AudioStreamBasicDescription(
            mSampleRate: hardware.mSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: hardware.mChannelsPerFrame,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        guard AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            1,
            &client,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        ) == noErr, let format = AVAudioFormat(streamDescription: &client) else {
            try tearDownAndThrow(.formatUnavailable)
        }

        let state = AudioInputCaptureState(format: format)
        state.unit = unit
        var callback = AURenderCallbackStruct(
            inputProc: audioInputCaptureCallback,
            inputProcRefCon: Unmanaged.passUnretained(state).toOpaque()
        )
        guard AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_SetInputCallback,
            kAudioUnitScope_Global,
            0,
            &callback,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        ) == noErr else {
            try tearDownAndThrow(.formatUnavailable)
        }
        guard AudioUnitInitialize(unit) == noErr else {
            try tearDownAndThrow(.formatUnavailable)
        }
        guard AudioOutputUnitStart(unit) == noErr else {
            AudioUnitUninitialize(unit)
            try tearDownAndThrow(.noAudioInput)
        }
        return AudioInputCapture(format: format, unit: unit, state: state)
    }

    func installTap(_ handler: @escaping @Sendable (AVAudioPCMBuffer) -> Void) {
        state.lock.lock()
        state.handler = handler
        state.lock.unlock()
    }

    func stop() {
        state.lock.lock()
        state.handler = nil
        state.lock.unlock()
        guard let unit else { return }
        AudioOutputUnitStop(unit)
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
        self.unit = nil
        state.unit = nil
    }
}

final class AudioInputCaptureState: @unchecked Sendable {
    let format: AVAudioFormat
    var unit: AudioUnit?
    var handler: ((AVAudioPCMBuffer) -> Void)?
    let lock = NSLock()
    private var pcm: AVAudioPCMBuffer?

    init(format: AVAudioFormat) {
        self.format = format
    }

    func render(
        actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        frames: UInt32
    ) -> OSStatus {
        lock.lock()
        let handler = self.handler
        let unit = self.unit
        lock.unlock()
        guard let handler, let unit else { return noErr }

        if pcm == nil || pcm!.frameCapacity < frames {
            pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(frames, 4096))
        }
        guard let pcm else { return kAudio_MemFullError }
        pcm.frameLength = frames
        let status = AudioUnitRender(unit, actionFlags, timestamp, 1, frames, pcm.mutableAudioBufferList)
        guard status == noErr else { return status }
        handler(pcm)
        return noErr
    }
}

private func audioInputCaptureCallback(
    inRefCon: UnsafeMutableRawPointer,
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    let state = Unmanaged<AudioInputCaptureState>.fromOpaque(inRefCon).takeUnretainedValue()
    return state.render(actionFlags: ioActionFlags, timestamp: inTimeStamp, frames: inNumberFrames)
}

final class AudioInputObservation {
    private var devicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private let queue = DispatchQueue(label: "dev.bdsk.audio-input")
    private let block: AudioObjectPropertyListenerBlock
    private let debouncer: Debouncer

    init(handler: @escaping @MainActor () -> Void) {
        let debouncer = Debouncer(handler: handler)
        self.debouncer = debouncer
        block = { _, _ in
            debouncer.ping()
        }
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            queue,
            block
        )
    }

    deinit {
        debouncer.cancel()
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            queue,
            block
        )
    }

    private final class Debouncer: @unchecked Sendable {
        private let handler: @MainActor () -> Void
        private let lock = NSLock()
        private var pending: DispatchWorkItem?

        init(handler: @escaping @MainActor () -> Void) {
            self.handler = handler
        }

        func ping() {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.handler()
                }
            }
            lock.lock()
            pending?.cancel()
            pending = work
            lock.unlock()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.6, execute: work)
        }

        func cancel() {
            lock.lock()
            pending?.cancel()
            pending = nil
            lock.unlock()
        }
    }
}
