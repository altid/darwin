//
//  Connection.swift
//  Altid - Connect with a service over 9p
//
//  Created by halfwit on 2024-01-03.
//

import Foundation
import Network

struct Queue<T> {
    private var elements: [T] = []
    
    mutating func enqueue(_ value: T) {
        elements.append(value)
    }
    
    mutating func dequeue() -> T? {
        guard !elements.isEmpty else {
            return nil
        }
        return elements.removeFirst()
    }
    
    var size: Int {
        get {
            return elements.count
        }
    }
}

struct Enqueued {
    let message: Messageable
    let action: (NWProtocolFramer.Message, Data?, NWError?) -> Void
    init(message: Messageable, action: @escaping (NWProtocolFramer.Message, Data?, NWError?) -> Void) {
        self.message = message
        self.action = action
    }
}

func applicationServiceParameters() -> NWParameters {
    let tcpOptions = NWProtocolTCP.Options()
    tcpOptions.enableKeepalive = true
    tcpOptions.keepaliveInterval = 30
    let params: NWParameters = NWParameters(tls: nil, tcp: tcpOptions)
    let nineOptions = NWProtocolFramer.Options(definition: NineProtocol.definition)
    params.defaultProtocolStack.applicationProtocols.insert(nineOptions, at: 0)
    return params
}

var sharedConnection: PeerConnection?

protocol PeerConnectionDelegate: AnyObject {
    func connectionReady()
    func connectionFailed()
    func displayAdvertiseError(_ error: NWError)
}

class PeerConnection {
    weak var delegate: PeerConnectionDelegate?
    var msize: UInt32 = 8192
    var connection: NWConnection?
    let result: Result
    let initiatedConnection: Bool
    var sendQueue = Queue<Enqueued>()
    var running: Bool = false

    /* Connect to a service */
    init(result: Result, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.result = result
        self.initiatedConnection = true
        
        guard let endpointPort = NWEndpoint.Port("12345") else { return }
        let connectionEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host("127.0.0.1"), port: endpointPort)
        connection = NWConnection(to: connectionEndpoint, using: applicationServiceParameters())
        //connection = NWConnection(to: .service(name: result.name, type: "_altid._tcp.", domain: "local.", interface: nil), using: applicationServiceParameters())
    }

    func cancel() {
        if let connection = self.connection {
            connection.cancel()
            self.connection = nil
        }
    }
    
    // Handle starting the peer-to-peer connection for both inbound and outbound connections.
    func startConnection() {
        guard let connection = self.connection else {
            return
        }
        
        connection.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                print("Connection ready")
                if let delegate = self?.delegate {
                    delegate.connectionReady()
                }
            case .failed(let error):
                print("\(connection) failed with \(error)")
                connection.cancel()
                if let endpoint = self?.result.result.endpoint, let initiated = self?.initiatedConnection,
                   initiated && error == NWError.posix(.ECONNABORTED) {
                    // Reconnect if the user suspends the app on the nearby device.
                    let connection = NWConnection(to: endpoint, using: applicationServiceParameters())
                    self?.connection = connection
                    self?.startConnection()
                } else if let delegate = self?.delegate {
                    delegate.connectionFailed()
                }
            default:
                break
            }
        }
        
        connection.start(queue: .main)
    }
}

extension PeerConnection {
    func connect(uname: String) {
        send(Tversion())
        send(Tattach(fid: 0, afid: 0, uname: uname, aname: "/"))
    }
    
    func run() {
        if sendQueue.size > 0 {
            _runjob()
        }
    }

    func read(_ names: [String], fid: UInt32 = 0, tag: UInt16 = 0, offset: UInt64 = 0, count: UInt32 = 8068, callback: @escaping (String) -> Void) {
        send(Twalk(fid: fid, newFid: fid+1, wnames: names))
        send(Topen(tag: tag, fid: fid+1, mode: nineMode.read))
        send(Tread(tag: tag, fid: fid+1, offset: offset, count: count)) { (data: String) in
            callback(data)
            self.send(Tclunk(tag: tag, fid: fid))
        }

    }
    
    func write(_ names: [String], data: Data, fid: UInt32 = 0, tag: UInt16 = 0, offset: UInt64 = 0, callback: @escaping (NineErrors) -> Void) {
        send(Twalk(fid: fid, newFid: fid+1, wnames: names))
        send(Topen(tag: tag, fid: fid+1, mode: nineMode.write))
        // TODO: Make sure we do the right thing on write
        send(Twrite(tag: tag, fid: fid+1, offset: offset, count: UInt32(data.count), bytes: data)) { (error: NineErrors) in
            callback(error)
            self.send(Tclunk(tag: tag, fid: fid))
        }
    }
    
    private func send(_ message: Messageable) {
        _enqueue(message) { (msg, content, error) in
            // Probably error logging, etc
        }
    }
    
    private func send(_ message: Messageable, callback: @escaping (String) -> Void) {
        _enqueue(message) { (msg, content, error) in
            guard let content = content else {
                return
            }
            var str = ""
            for c in content {
                str.append(c.char)
            }
            callback(str)
        }
    }
    
    private func send(_ message: Messageable, callback: @escaping (NineErrors) -> Void) {
        _enqueue(message) { (msg, content, error ) in
            switch error {
            case .none:
                callback(.success)
            case .some(_):
                callback(.decodeError)
            }
        }
    }
    
    private func _enqueue( _ message: Messageable, callback: @escaping (NWProtocolFramer.Message, Data?, NWError?) -> Void) {
        sendQueue.enqueue(Enqueued(message: message, action: callback))
    }
    
    func _runjob() {
        guard let connection = self.connection else { return }
        guard let queue = sendQueue.dequeue() else { return }
        let completion = NWConnection.SendCompletion.contentProcessed { error in
            if error != nil {
                print("Error: \(error?.localizedDescription as Any)")
                return
            }
            connection.receiveMessage { (content, context, isComplete, error) in
                if let nineMessage = context?.protocolMetadata(definition: NineProtocol.definition) as? NWProtocolFramer.Message {
                    queue.action(nineMessage, content, error)
                    self._runjob()
                }
            }
        }
        connection.send(content: queue.message.encodedData, contentContext: queue.message.context, isComplete: true, completion: completion)

    }
}
