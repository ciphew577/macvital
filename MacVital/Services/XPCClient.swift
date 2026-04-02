// MacVital/Services/XPCClient.swift
import Foundation

final class XPCClient: @unchecked Sendable {
    private var connection: NSXPCConnection?
    private let lock = NSLock()

    var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return connection != nil
    }

    func connect() {
        lock.lock()
        defer { lock.unlock() }

        let conn = NSXPCConnection(machServiceName: macVitalHelperMachServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: MacVitalHelperProtocol.self)
        conn.invalidationHandler = { [weak self] in
            self?.lock.lock()
            self?.connection = nil
            self?.lock.unlock()
        }
        conn.resume()
        connection = conn
    }

    func disconnect() {
        lock.lock()
        defer { lock.unlock() }
        connection?.invalidate()
        connection = nil
    }

    func getProxy() -> MacVitalHelperProtocol? {
        lock.lock()
        // Auto-connect if connection was never established or was invalidated.
        // This ensures fan control works even if the initial connect() was missed
        // (e.g. due to a race condition during app startup).
        if connection == nil {
            lock.unlock()
            connect()
            lock.lock()
        }
        defer { lock.unlock() }
        return connection?.remoteObjectProxyWithErrorHandler { error in
            print("XPC error: \(error)")
        } as? MacVitalHelperProtocol
    }

    // MARK: - Typed Fetchers

    func fetchCPU() async -> CPUData? {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else { continuation.resume(returning: nil); return }
            proxy.getCPUData { data in
                continuation.resume(returning: try? JSONDecoder().decode(CPUData.self, from: data))
            }
        }
    }

    func fetchMemory() async -> MemoryData? {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else { continuation.resume(returning: nil); return }
            proxy.getMemoryData { data in
                continuation.resume(returning: try? JSONDecoder().decode(MemoryData.self, from: data))
            }
        }
    }

    func fetchStorage() async -> StorageData? {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else { continuation.resume(returning: nil); return }
            proxy.getStorageData { data in
                continuation.resume(returning: try? JSONDecoder().decode(StorageData.self, from: data))
            }
        }
    }

    func fetchBattery() async -> BatteryData? {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else { continuation.resume(returning: nil); return }
            proxy.getBatteryData { data in
                continuation.resume(returning: try? JSONDecoder().decode(BatteryData.self, from: data))
            }
        }
    }

    func fetchSensors() async -> SensorData? {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else { continuation.resume(returning: nil); return }
            proxy.getSensorData { data in
                continuation.resume(returning: try? JSONDecoder().decode(SensorData.self, from: data))
            }
        }
    }

    func fetchGPU() async -> GPUData? {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else { continuation.resume(returning: nil); return }
            proxy.getGPUData { data in
                continuation.resume(returning: try? JSONDecoder().decode(GPUData.self, from: data))
            }
        }
    }

    func fetchNetwork() async -> NetworkData? {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else { continuation.resume(returning: nil); return }
            proxy.getNetworkData { data in
                continuation.resume(returning: try? JSONDecoder().decode(NetworkData.self, from: data))
            }
        }
    }

    func fetchDiagnostic() async -> DiagnosticReport? {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else { continuation.resume(returning: nil); return }
            proxy.runFullDiagnostic { data in
                continuation.resume(returning: try? JSONDecoder().decode(DiagnosticReport.self, from: data))
            }
        }
    }

}
