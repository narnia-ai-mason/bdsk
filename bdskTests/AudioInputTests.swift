import XCTest
@testable import bdsk

final class AudioInputTests: XCTestCase {
    private let yeti = AudioInput.Device(
        deviceID: 11,
        uid: "usb-yeti",
        name: "Blue Yeti",
        transport: .usb
    )
    private let airpods = AudioInput.Device(
        deviceID: 22,
        uid: "bt-airpods",
        name: "AirPods Pro",
        transport: .bluetooth
    )

    func testResolveEmptyUIDUsesSystemDefault() {
        XCTAssertNil(AudioInput.resolve(uid: "", devices: [yeti, airpods]))
    }

    func testResolveMatchesUID() {
        XCTAssertEqual(AudioInput.resolve(uid: "usb-yeti", devices: [yeti, airpods])?.name, "Blue Yeti")
    }

    func testResolveMissingUIDReturnsNil() {
        XCTAssertNil(AudioInput.resolve(uid: "gone", devices: [yeti, airpods]))
    }

    func testEffectiveUIDFallsBackWhenPreferredIsMissing() {
        XCTAssertEqual(AudioInput.effectiveUID(preferred: "gone", devices: [yeti]), "")
        XCTAssertEqual(AudioInput.effectiveUID(preferred: "", devices: [yeti]), "")
        XCTAssertEqual(AudioInput.effectiveUID(preferred: "usb-yeti", devices: [yeti]), "usb-yeti")
    }

    func testPickerTitleAnnotatesBluetoothAndUSB() {
        XCTAssertEqual(yeti.pickerTitle, "Blue Yeti · USB")
        XCTAssertEqual(airpods.pickerTitle, "AirPods Pro · 블루투스")
        let builtIn = AudioInput.Device(
            deviceID: 33,
            uid: "built-in",
            name: "MacBook Pro 마이크",
            transport: .builtIn
        )
        XCTAssertEqual(builtIn.pickerTitle, "MacBook Pro 마이크")
    }

    func testDevicesHaveUniqueUIDs() {
        let uids = AudioInput.devices().map(\.uid)
        XCTAssertEqual(uids.count, Set(uids).count)
        XCTAssertFalse(uids.contains(where: \.isEmpty))
    }

    func testResolvedDeviceSkipsBluetoothDefault() {
        let builtIn = AudioInput.Device(
            deviceID: 33,
            uid: "built-in",
            name: "MacBook Pro 마이크",
            transport: .builtIn
        )
        let resolved = AudioInput.resolvedDevice(
            preferredUID: "",
            devices: [yeti, builtIn],
            defaultDevice: airpods
        )
        XCTAssertEqual(resolved?.uid, "usb-yeti")
    }

    func testResolvedDeviceUsesPreferredWiredMic() {
        let builtIn = AudioInput.Device(
            deviceID: 33,
            uid: "built-in",
            name: "MacBook Pro 마이크",
            transport: .builtIn
        )
        let resolved = AudioInput.resolvedDevice(
            preferredUID: "built-in",
            devices: [yeti, builtIn],
            defaultDevice: airpods
        )
        XCTAssertEqual(resolved?.uid, "built-in")
    }

    func testResolvedDeviceUsesExplicitBluetoothMic() {
        let resolved = AudioInput.resolvedDevice(
            preferredUID: "bt-airpods",
            devices: [yeti, airpods],
            defaultDevice: airpods
        )
        XCTAssertEqual(resolved?.uid, "bt-airpods")
    }

    func testResolvedDeviceIgnoresMissingBluetoothUID() {
        let resolved = AudioInput.resolvedDevice(
            preferredUID: "bt-airpods",
            devices: [yeti],
            defaultDevice: airpods
        )
        XCTAssertEqual(resolved?.uid, "usb-yeti")
    }
}
