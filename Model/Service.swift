//
//  Service.swift
//  Altid
//
//  Created by halfwit on 2024-01-08.
//

import SwiftUI
import Network
import Observation

struct Handle {
    let fid: UInt32
    let tag: UInt16
    let name: String
    
    init(fid: UInt32, tag: UInt16, name: String) {
        self.fid = fid
        self.tag = tag
        self.name = name
    }
}

@Observable
class Service: Hashable, Identifiable {
    private var browser: Result
    var buffers: [Buffer]
    var current: Buffer?
    var session: PeerConnection?
    var error: Data?
    var handles = [Handle]()

    enum CodingKeys: CodingKey {
        case browser
        case connection
    }
    
    var displayName: String {
        return browser.name
    }

    var connected: Bool {
        return session?.initiatedConnection ?? false
    }

    init(result: Result) {
        self.buffers = [Buffer]()
        self.browser = result
    }
    
    static func == (lhs: Service, rhs: Service) -> Bool {
        return lhs.displayName == rhs.displayName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
    }
    
    func connect() {
        self.session = PeerConnection(result: self.browser, delegate: self)
        self.session?.startConnection()
    }
    
    func selectBuffer(buffer: Buffer) {
        current = buffer
        /*
        let ctrlHandle = Handle(fid: 1, tag: 0, name: "ctrl")
        let bytes = "buffer \(buffer.displayName)".data(using: .utf8)!
        session?.sendQueue.enqueue(Twalk(fid: 0, newFid: ctrlHandle.fid, wnames: ["ctrl"]))
        session?.sendQueue.enqueue(Topen(tag: ctrlHandle.tag, fid: ctrlHandle.fid, mode: nineMode.rdwr))
        session?.sendQueue.enqueue(Twrite(tag: ctrlHandle.tag, fid: ctrlHandle.fid, offset: 0, count: UInt32(bytes.count), bytes: bytes))
        session?.sendQueue.enqueue(Tclunk(tag: ctrlHandle.tag, fid: ctrlHandle.fid))
        //session?.writeMessages()

        let titleHandle = Handle(fid: 2, tag: 0, name: "title")
        handles.append(titleHandle)
        session?.sendQueue.enqueue(Twalk(fid: 0, newFid: titleHandle.fid, wnames: ["title"]))
        session?.sendQueue.enqueue(Topen(tag: titleHandle.tag, fid: titleHandle.fid, mode: nineMode.read))
        session?.sendQueue.enqueue(Tread(tag: titleHandle.tag, fid: titleHandle.fid, offset: 0, count: 8000))
        session?.sendQueue.enqueue(Tclunk(tag: titleHandle.tag, fid: titleHandle.fid))
        
        let statusHandle = Handle(fid: 3, tag: 0, name: "status")
        handles.append(statusHandle)
        session?.sendQueue.enqueue(Twalk(fid: 0, newFid: statusHandle.fid, wnames: ["status"]))
        session?.sendQueue.enqueue(Topen(tag: statusHandle.tag, fid: statusHandle.fid, mode: nineMode.read))
        session?.sendQueue.enqueue(Tread(tag: statusHandle.tag, fid: statusHandle.fid, offset: 0, count: 8000))
        session?.sendQueue.enqueue(Tclunk(tag: statusHandle.tag, fid: statusHandle.fid))
        
        
        let feedHandle = Handle(fid: 4, tag: 0, name: "feed")
        handles.append(feedHandle)
        session?.sendQueue.enqueue(Twalk(fid: 0, newFid: feedHandle.fid, wnames: ["feed"]))
        session?.sendQueue.enqueue(Topen(tag: feedHandle.tag, fid: feedHandle.fid, mode: nineMode.read))
        session?.sendQueue.enqueue(Tread(tag: feedHandle.tag, fid: feedHandle.fid, offset: 0, count: 8000))
        // Here, we only have a bit. We likely need a lot. Grab a stat for feed, and seek to total - 1000 first
        // eventually reading backwards on scrollup
        session?.sendQueue.enqueue(Tclunk(tag: feedHandle.tag, fid: feedHandle.fid))

        session?.writeMessages()
        */
    }
    
    // Probably better to parse this out in a state method. We only have two cases, in name and in unread
    // Use a utility function though as this gets big.
    func buildBuffers(data: Data) {
        var tmp = [Buffer]()
        let inputs = data.split(separator: 10)
        for input in inputs {
            let parts = input.split(separator: 32)
            var name: String = ""
            for d in parts[0] {
                name.append(d.char)
            }
            var seen = false
            for buffer in buffers {
                if buffer.displayName == name {
                    tmp.append(buffer)
                    //buffer.updateUnread(data: parts[1])
                    seen = true
                }
            }
            if !seen {
                tmp.append(Buffer(displayName: name))
            }
        }
        buffers = tmp
    }
}

extension Service: PeerConnectionDelegate {
    func receivedMessage(message: NWProtocolFramer.Message, content: Data?) {
        let handle = handles.first(where: { $0.tag == message.tag})
        switch message.type {
        case .Rerror:
            break
        case .Rversion:
            // If we don't match version, something is wrong.
            if version.hashValue != content?.hashValue {
                print("Weird error")
            }
        case .Rattach:
            // Set buffer list to loading indicator
            //print(message.qids!)
            break
        case .Rflush:
            // Flush our fid
            break
        case .Rwalk:
            //print(message.qids!)
            break
        case .Ropen:
            // We get a qid and our iounit from this
            break
        case .Rcreate:
            // Same as open
            break
        case .Rread:
            print("Arrr read")
            switch handle?.name {
            case "tabs":
                print("In tabs")
                buildBuffers(data: content!)
            case "title":
                print("In title")
                current?.setTitle(data: content)
            case "feed":
                print("In feed")
            case "status":
                print("In status")
            default:
                return
            }
        case .Rwrite:
            // Update our to-write offset pointer, possibly call the next write?
            break
        case .Rclunk:
            print("Clunkin' ain't easy")
            //handles.remove()
            break
        case .Rremove:
            break
        case .Rstat:
            // Manage our stat here
            break
        case .Rwstat:
            // Stat was updated, good!
            break
        default:
            break
        }
    }
    
    func connectionReady() {
        let tabHandle = Handle(fid: 1, tag: 0, name: "tabs")
        handles.append(tabHandle)
        session?.sendQueue.enqueue(Tversion())
        session?.sendQueue.enqueue(Tattach(fid: 0, afid: 0, uname: "halfwit", aname: "/"))
        session?.sendQueue.enqueue(Twalk(fid: 0, newFid: tabHandle.fid, wnames: ["tabs"]))
        session?.sendQueue.enqueue(Topen(tag: 0, fid: tabHandle.fid, mode: nineMode.read))
        session?.sendQueue.enqueue(Tread(tag: 0, fid: tabHandle.fid, offset: 0, count: 8068))
        session?.writeMessages()
    }
    
    func connectionFailed() {
        print("Connection failed")
    }
    
    func displayAdvertiseError(_ error: NWError) {
        print("Advertise Error: \(error)")
    }
    
    
}
