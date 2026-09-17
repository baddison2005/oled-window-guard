import AppKit
import Carbon

@MainActor
final class BrightnessHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?
    func register() -> Bool {
        unregister()
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            var pressed = EventHotKeyID()
            guard let event, GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed) == noErr,
                  pressed.signature == 0x4F574742, pressed.id == 1 else { return OSStatus(eventNotHandledErr) }
            guard let context else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<BrightnessHotKey>.fromOpaque(context).takeUnretainedValue().action?()
            }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { return false }
        let id = EventHotKeyID(signature: 0x4F574742, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(controlKey | optionKey | cmdKey), id, GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr { unregister() }
        return result == noErr
    }
    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }; hotKey = nil
        if let handler { RemoveEventHandler(handler) }; handler = nil
    }
    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
