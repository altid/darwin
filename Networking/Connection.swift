//
//  Connection.swift
//  Altid - Connect with a service over 9p
//
//  Created by halfwit on 2024-01-03.
//

import Foundation
import Network

func applicationServiceParameters() -> NWParameters {
    let tcpOptions = NWProtocolTCP.Options()
    tcpOptions.enableKeepalive = true
    tcpOptions.keepaliveInterval = 15
    
    let params: NWParameters = NWParameters(tls: nil, tcp: tcpOptions)
    params.includePeerToPeer = true
    
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
    var connection: NWConnection?
    let name: String
    let initiatedConnection: Bool
    var sendQueue = Queue<Enqueued>()
    var handles: [Handle] = [Handle]()
    var running: Bool = false
    
    /* Connect to a service */
    init(name: String, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.name = name
        self.initiatedConnection = true
        
        guard let endpointPort = NWEndpoint.Port("12345") else { return }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host("192.168.0.73"), port: endpointPort)
        //let endpoint = NWEndpoint.service(name: name, type: "_altid._tcp", domain: "local.", interface: nil)
        connection = NWConnection(to: endpoint, using: applicationServiceParameters())
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
                if let delegate = self?.delegate {
                    delegate.connectionReady()
                }
            case .failed(let error):
                print("\(connection) failed with \(error)")
                connection.cancel()
                if let initiated = self?.initiatedConnection,
                   initiated && error == NWError.posix(.ECONNABORTED) {
                    // Reconnect if the user suspends the app on the nearby device.
                    let service = NWEndpoint.service(name: self!.name, type: "_altid._tcp", domain: "local", interface: nil)
                    let connection = NWConnection(to: service, using: applicationServiceParameters())
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

/* Utility functions */
extension PeerConnection {
    func connect(uname: String = "none") {
        send(Tversion())
        send(Tattach(fid: 0, afid: 0, uname: uname, aname: "/"))
    }
    
    func run() {
        if sendQueue.size > 0 {
            _runjob()
        }
    }
    
    func flush(_ handle: Handle) {
        let tag = UInt16(handles.count > 1 ? handles.count : 1)
        send(Tflush(tag: tag, oldtag: handle.tag))
    }

    func close(_ handle: Handle) {
        send(Tclunk(tag: handle.tag, fid: handle.fid))
        if let index = handles.firstIndex(where: { $0.fid == handle.fid }) {
            handles.remove(at: index)
        }
    }
    
    func open(_ wnames: [String], mode: nineMode) -> Handle {
        let fid = UInt32(handles.count + 1)
        let tag = UInt16(handles.count > 1 ? handles.count : 1) - 1
        let handle = Handle(fid: fid, tag: tag, name: wnames.last!)

        send(Twalk(fid: 0, newFid: handle.fid, wnames: wnames))
        send(Topen(tag: 0, fid: handle.fid, mode: mode))
        handles.append(handle)
        return handle
    }
    
    func read(_ handle: Handle, offset: UInt64 = 0, count: UInt32 = 8168, callback: @escaping (String) -> Void) {
        send(Tread(tag: handle.tag, fid: handle.fid, offset: offset, count: count)) { (data: String) in
            callback(data)
        }
    }
    
    func write(_ handle: Handle, data: Data, offset: UInt64 = 0, callback: @escaping (NineErrors) -> Void) {
        send(Twrite(tag: handle.tag, fid: handle.fid, offset: offset, count: UInt32(data.count), bytes: data)) { (error: NineErrors) in
            callback(error)
        }
    }
    
    private func send(_ message: QueueableMessage) {
        _enqueue(message) { (msg, content, error) in
        }
    }
    
    private func send(_ message: QueueableMessage, callback: @escaping (String) -> Void) {
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
    
    private func send(_ message: QueueableMessage, callback: @escaping (NineErrors) -> Void) {
        _enqueue(message) { (msg, content, error ) in
            switch error {
            case .none:
                callback(.success)
            case .some(_):
                callback(.decodeError)
            }
        }
    }
    
    private func _enqueue( _ message: QueueableMessage, callback: @escaping (NWProtocolFramer.Message, Data?, NWError?) -> Void) {
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
                }
                self._runjob()
            }
        }
        connection.send(content: queue.message.encodedData, contentContext: queue.message.context, isComplete: true, completion: completion)
    }
}
