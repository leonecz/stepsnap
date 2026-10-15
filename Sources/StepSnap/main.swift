import AppKit

// Порядок важен: сначала NSApplication.shared (он поднимает соединение с оконным сервером),
// и только потом делегат — в его инициализаторах свойств создаётся иконка в строке меню.
// Наоборот приложение падает на старте с CGSConnectionByID.
let application = NSApplication.shared

// NSApplication.delegate хранит делегата слабо, поэтому держим сильную ссылку глобально.
let appDelegate: AppDelegate = MainActor.assumeIsolated {
    // Верхнеуровневый код в Swift 5 не изолирован на главном акторе, а AppDelegate — да.
    // assumeIsolated тут безопасен: main.swift и так исполняется на главном потоке.
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    return delegate
}

application.run()
