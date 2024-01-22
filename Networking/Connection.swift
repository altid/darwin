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

  var head: T? {
    return elements.first
  }

  var tail: T? {
    return elements.last
  }
}

func applicationServiceParameters() -> NWParameters {
    let tcpOptions = NWProtocolTCP.Options()
    tcpOptions.enableKeepalive = true
    let params: NWParameters = NWParameters(tls: nil, tcp: tcpOptions)
    let nineOptions = NWProtocolFramer.Options(definition: NineProtocol.definition)
    params.defaultProtocolStack.applicationProtocols.insert(nineOptions, at: 0)
    return params
}

var sharedConnection: PeerConnection?

protocol PeerConnectionDelegate: AnyObject {
    func connectionReady()
    func connectionFailed()
    func receivedMessage(message: NWProtocolFramer.Message, content: Data?)
    func displayAdvertiseError(_ error: NWError)
}

class PeerConnection {
    weak var delegate: PeerConnectionDelegate?
    var msize: UInt32 = 8192
    var connection: NWConnection?
    let result: Result
    let initiatedConnection: Bool
    var sendQueue = Queue<Messageable>()
    
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
    func writeMessages() {
        guard let connection = self.connection else {
            return
        }

        guard let message = sendQueue.dequeue() else {
            return
        }
    
        connection.receiveMessage { (content, context, isComplete, error) in
            if let nineMessage = context?.protocolMetadata(definition: NineProtocol.definition) as? NWProtocolFramer.Message {
                self.delegate?.receivedMessage(message: nineMessage, content: content)
                self.writeMessages()
            }
        }
        let completion = NWConnection.SendCompletion.contentProcessed { error in
            if error != nil {
                print("Error: \(error?.localizedDescription as Any)")
            }
        }
        connection.send(content: message.encodedData, contentContext: message.context, isComplete: true, completion: completion)
    }
}
