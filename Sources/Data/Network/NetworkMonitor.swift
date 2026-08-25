import Foundation
#if canImport(Network)
import Network
#endif

public protocol NetworkMonitorProtocol: Sendable {
    var isConnected: Bool { get }
    func startMonitoring()
    func stopMonitoring()
    func registerConnectivityRestoredHandler(_ handler: @escaping @Sendable () -> Void)
}

/// Real-time network reachability monitor for Vialr.
/// Listens for connectivity transitions and automatically signals `SyncEngine`
/// to flush the offline synchronization queue when internet access is restored.
public final class NetworkMonitor: NetworkMonitorProtocol, @unchecked Sendable {
    public static let shared = NetworkMonitor()

    #if canImport(Network)
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.vialr.network-monitor", qos: .utility)
    #endif

    private var _isConnected: Bool = true
    private var wasConnected: Bool = true
    private let lock = NSLock()
    private var connectivityRestoredHandlers: [@Sendable () -> Void] = []

    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }

    public init() {
        startMonitoring()
    }

    public func startMonitoring() {
        #if canImport(Network)
        let monitor = NWPathMonitor()
        self.pathMonitor = monitor

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let connected = path.status == .satisfied
            
            var shouldNotify = false
            self.lock.lock()
            let previouslyConnected = self._isConnected
            self._isConnected = connected
            
            // Detect offline-to-online transition
            if !previouslyConnected && connected {
                shouldNotify = true
            }
            let handlers = self.connectivityRestoredHandlers
            self.lock.unlock()

            if shouldNotify {
                print("[NetworkMonitor] Network connectivity restored. Triggering pending synchronization queue...")
                for handler in handlers {
                    handler()
                }
            }
        }

        monitor.start(queue: monitorQueue)
        #else
        lock.lock()
        _isConnected = true
        lock.unlock()
        #endif
    }

    public func stopMonitoring() {
        #if canImport(Network)
        pathMonitor?.cancel()
        pathMonitor = nil
        #endif
    }

    public func registerConnectivityRestoredHandler(_ handler: @escaping @Sendable () -> Void) {
        lock.lock()
        connectivityRestoredHandlers.append(handler)
        lock.unlock()
    }

    /// Testing helper to simulate offline / online network state transitions.
    public func simulateNetworkStatusChange(isConnected: Bool) {
        var shouldNotify = false
        lock.lock()
        let previouslyConnected = self._isConnected
        self._isConnected = isConnected
        if !previouslyConnected && isConnected {
            shouldNotify = true
        }
        let handlers = self.connectivityRestoredHandlers
        lock.unlock()

        if shouldNotify {
            for handler in handlers {
                handler()
            }
        }
    }
}
