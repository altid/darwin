//
//  Connection.swift
//  Altid - Connect with a service over 9p
//
//  Created by halfwit on 2024-01-03.
//

import Foundation
import Network

func applicationServiceParameters() -> NWParameters {
    let parameters = NWParameters.applicationService

    let nineOptions = NWProtocolFramer.Options(definition: NineProtocol.definition)
    parameters.defaultProtocolStack.applicationProtocols.insert(nineOptions, at: 0)

    return parameters
}

var sharedConnection: PeerConnection?

protocol PeerConnectionDelegate: AnyObject {
    func connectionReady()
    func connectionFailed()
    func receivedMessage(content: Data?, message: NWProtocolFramer.Message)
    func displayAdvertiseError(_ error: NWError)
}

class PeerConnection {

    weak var delegate: PeerConnectionDelegate?
    var msize: UInt32 = 8192
    var connection: NWConnection?
    let endpoint: NWEndpoint?
    let initiatedConnection: Bool

    // TODO: One of these will be for dialing with Scanner results, another for eventual hard-coded URLs.
    // Create an outbound connection when the user initiates a game.
    init(endpoint: NWEndpoint, interface: NWInterface?, passcode: String, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.endpoint = nil
        self.initiatedConnection = true

        let connection = NWConnection(to: endpoint, using: NWParameters())
        self.connection = connection

        startConnection()
    }
    
    // Create an outbound connection when the user initiates a game via DeviceDiscoveryUI.
    init(endpoint: NWEndpoint, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.endpoint = endpoint
        self.initiatedConnection = true

        let connection = NWConnection(to: endpoint, using: applicationServiceParameters())
        self.connection = connection

        startConnection()
    }

    func cancel() {
        if let connection = self.connection {
            connection.cancel()
            self.connection = nil
        }
    }

    // Handle starting the peer-to-peer connection for both inbound and outbound connections.
    func startConnection() {
        guard let connection = connection else {
            return
        }

        connection.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                print("\(connection) established")

                self?.receiveNextMessage()

                if let delegate = self?.delegate {
                    delegate.connectionReady()
                }
            case .failed(let error):
                print("\(connection) failed with \(error)")
                connection.cancel()

                if let endpoint = self?.endpoint, let initiated = self?.initiatedConnection,
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
    
    func version() {
        guard let connection = connection else {
            return
        }
        let content = Tversion(msize: msize, version: "9P2000".data(using: .utf8)!)
        let message = NWProtocolFramer.Message(nineType: nineType.Tversion, nineTag: 0xFFFF)
        let context = NWConnection.ContentContext(identifier: "Version", metadata: [message])
        connection.send(content: content.encodedData, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    //func auth() {}
    
    func attach(user: String = "guest") {
        guard let connection = connection else {
            return
        }
        let content = Tattach(fid: 0, afid: 0, uname: user.data(using: .utf8)!, aname: "/".data(using: .utf8)!)
        let message = NWProtocolFramer.Message(nineType: nineType.Tattach, nineTag: 0)
        let context = NWConnection.ContentContext(identifier: "Attach", metadata: [message])
        connection.send(content: content.encodedData, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    func flush(tag: UInt16, old: UInt16) {
        guard let connection = connection else {
            return
        }
        let content = Tflush(oldtag: old)
        let message = NWProtocolFramer.Message(nineType: nineType.Tflush, nineTag: tag)
        let context = NWConnection.ContentContext(identifier: "Flush", metadata: [message])
        connection.send(content: content.encodedData, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    func walk(tag: UInt16, fid: UInt32, newfid: UInt32, target: String) {
        guard let connection = connection else {
            return
        }
        var wnames: [Data] = []
        let paths = target.split(separator: "/")
        for path in paths {
            wnames.append(path.data(using: .utf8)!)
        }
        let content = Twalk(fid: fid, newFid: newfid, nwname: UInt16(wnames.count), wnames: wnames)
        let message = NWProtocolFramer.Message(nineType: nineType.Twalk, nineTag: tag)
        let context = NWConnection.ContentContext(identifier: "Walk", metadata: [message])
        connection.send(content: content.encodedData, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    func open(tag: UInt16, fid: UInt32, mode: nineMode) {
        guard let connection = connection else {
            return
        }
        let content = Topen(fid: fid, mode: mode)
        let message = NWProtocolFramer.Message(nineType: nineType.Topen, nineTag: tag)
        let context = NWConnection.ContentContext(identifier: "Open", metadata: [message])
        connection.send(content: content.encodedData, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    func create(tag: UInt16, fid: UInt32, name: String, perm: UInt32, mode: UInt8) {
        guard let connection = connection else {
            return
        }
        let content = Tcreate(fid: fid, name: name.data(using: .utf8)!, perm: perm, mode: mode)
        let message = NWProtocolFramer.Message(nineType: nineType.Tcreate, nineTag: tag)
        let context = NWConnection.ContentContext(identifier: "Create", metadata: [message])
        connection.send(content: content.encodedData, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    func read(tag: UInt16, fid: UInt32, offset: UInt64, count: UInt32) -> UInt32 {
        guard let connection = connection else {
            return 0
        }
        let packSize: UInt32 = UInt32(Tread.encodedSize + NineProtocolHeader.encodedSize)
        let cc = count > msize - packSize ? msize - packSize : count
        let content = Tread(fid: fid, offset: offset, count: cc)
        let message = NWProtocolFramer.Message(nineType: nineType.Tread, nineTag: tag)
        let context = NWConnection.ContentContext(identifier: "Read", metadata: [message])
        connection.send(content: content.encodedData, contentContext: context, isComplete: true, completion: .idempotent)
        return cc
    }

    func write(tag: UInt16, fid: UInt32, offset: UInt64, count: UInt32, bytes: String) -> UInt32 {
        guard let connection = connection else {
            return 0
        }
        let packSize = UInt32(Twrite.encodedSize + NineProtocolHeader.encodedSize)
        let cc = count > msize - packSize ? msize - packSize : count
        let content = Twrite(fid: fid, offset: offset, count: cc, bytes: bytes.data(using: .utf8)!)
        let message = NWProtocolFramer.Message(nineType: nineType.Twrite, nineTag: tag)
        let context = NWConnection.ContentContext(identifier: "Write", metadata: [message])
        connection.send(content: content.encodedData, contentContext: context, isComplete: true, completion: .idempotent)
        return cc
    }
    
    func clunk(tag: UInt16, fid: UInt32) {
        guard let connection = connection else {
            return
        }
        let content = Tclunk(fid: fid)
        let message = NWProtocolFramer.Message(nineType: nineType.Tclunk, nineTag: tag)
        let context = NWConnection.ContentContext(identifier: "Clunk", metadata: [message])
        connection.send(content: content.encodedData, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    func remove(tag: UInt16, fid: UInt32) {
        guard let connection = connection else {
            return
        }
        let content = Tremove(fid: fid)
        let message = NWProtocolFramer.Message(nineType: nineType.Tremove, nineTag: tag)
        let context = NWConnection.ContentContext(identifier: "Remove", metadata: [message])
        connection.send(content: content.encodedData, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    func stat(tag: UInt16, fid: UInt32) {
        guard let connection = connection else {
            return
        }
        let content = Tstat(fid: fid)
        let message = NWProtocolFramer.Message(nineType: nineType.Tstat, nineTag: tag)
        let context = NWConnection.ContentContext(identifier: "Stat", metadata: [message])
        connection.send(content: content.encodedData, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    func wstat(tag: UInt16, fid: UInt32, stat: nineStat) {
        guard let connection = connection else {
            return
        }
        let content = Twstat(fid: fid, stat: stat)
        let message = NWProtocolFramer.Message(nineType: nineType.Tremove, nineTag: tag)
        let context = NWConnection.ContentContext(identifier: "Remove", metadata: [message])
        connection.send(content: content.encodedData, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    // Receive a message, deliver it to your delegate, and continue receiving more messages.
    func receiveNextMessage() {
        guard let connection = connection else {
            return
        }
        connection.receiveMessage { (content, context, isComplete, error) in
            // Extract your message type from the received context.
            if let nineMsg = context?.protocolMetadata(definition: NineProtocol.definition) as? NWProtocolFramer.Message {
                self.delegate?.receivedMessage(content: content, message: nineMsg)
            }
            if error == nil {
                // Continue to receive more messages until you receive an error.
                self.receiveNextMessage()
            }
        }
    }
}
