//
//  9pProtocol.swift
//  Altid
//
//  Created by halfwit on 2024-01-03.
//

import Foundation
import Network

var MSIZE: UInt32 = 8192
let version = "9P2000".data(using: .utf8)!

enum NineErrors: Error {
    case decodeError
    case unknownType
    case connectError
}

enum nineType: UInt8 {
    case Tversion = 100
    case Tauth = 102
    case Tattach = 104
    case Tflush = 108
    case Twalk = 110
    case Topen = 112
    case Tcreate = 114
    case Tread = 116
    case Twrite = 118
    case Tclunk = 120
    case Tremove = 122
    case Tstat = 124
    case Twstat = 126
    case Rversion = 101
    case Rauth = 103
    case Rattach = 105
    case Rerror = 107
    case Rflush = 109
    case Rwalk = 111
    case Ropen = 113
    case Rcreate = 115
    case Rread = 117
    case Rwrite = 119
    case Rclunk = 121
    case Rremove = 123
    case Rstat = 125
    case Rwstat = 127
    case invalid = 0
}

enum fileType: UInt8, Codable {
    case dir = 7
    case append = 6
    case excl = 5
    case invalid = 4
    case auth = 3
    case tmp = 2
    case file = 0
}

enum nineMode: UInt32, Codable {
    case read = 0
    case write = 1
    case rdwr = 2
    case exec = 3
    //case trunc = 0x10
    //case rclose = 0x40
    //case excl = 0x1000
}

protocol Messageable {
    var encodedData: Data {get}
    var context: NWConnection.ContentContext {get}
}

struct nineQid: Codable {
    var type: fileType
    var version: UInt32
    var path: UInt64
}

struct nineStat: Codable {
    var size: UInt16
    var type: UInt16
    var dev: UInt32
    var qid: nineQid
    var mode: nineMode
    var atime: UInt32
    var mtime: UInt32
    var length: UInt64
    var name: Data
    var uid: Data
    var gid: Data
    var muid: Data
}

class nineResponse {
    var length: UInt32
    var type: nineType
    var tag: UInt16
    private var err: [Data] = [Data]()
    private var data: Data = Data(count: 0)
    private var qs: [nineQid] = [nineQid]()
    private var count: UInt32 = 0
    private var io: UInt32 = 0
    private var st: nineStat?
    
    init(buffer: UnsafeMutableRawBufferPointer) {
        var offset = 0
        self.length = r32(buffer: buffer, &offset)
        let type = r8(buffer: buffer, &offset) /* Why is this 20? */
        self.type = nineType(rawValue: type) ?? .invalid
        
        self.tag = r16(buffer: buffer, &offset)
    }
    
    // iounit may be needed, check eventually
    var write: UInt32 {
        get {
            return count
        }
        set {
            count = newValue
        }
    }
    var read: (Data, UInt32) {
        get {
            return (data, count)
        }
        set {
            data = newValue.0
            count = newValue.1
        }
    }
    
    var qids: [nineQid] {
        get {
            return qs
        }
        set {
            qs = newValue
        }
    }
    
    var stat: nineStat {
        get {
            return st!
        }
        set {
            st = newValue
        }
    }
    var error: [Data] {
        get {
            return err
        }
        set {
            err = newValue
        }
    }
    var iounit: UInt32 {
        get {
            return io
        }
        set {
            io = newValue
        }
    }
}

// Main framing protocol
class NineProtocol: NWProtocolFramerImplementation {
    static let definition = NWProtocolFramer.Definition(implementation: NineProtocol.self)
    static var label: String { return "9p" }
    
    required init(framer: NWProtocolFramer.Instance) {}
    /* We could write raw bytes here */
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        return .ready
    }
    func wakeup(framer: NWProtocolFramer.Instance) { print("In wakeup")}
    func stop(framer: NWProtocolFramer.Instance) -> Bool { print("In stop"); return true }
    func cleanup(framer: NWProtocolFramer.Instance) { print("In cleanup")}
    
    // TODO: We never receive the Tmessage. Try to break into a header/body pair potentially
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        print("Message count \(messageLength)")
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch {
            print("Heck didn't send")
        }
    }
    
    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var count: Int = 0
            let parsed = framer.parseInput(minimumIncompleteLength: 4,
                                           maximumLength: 4) { (buffer, isComplete) -> Int in
                var offset = 0
                guard let buffer = buffer else {
                    return 0
                }
                count = Int(r32(buffer: buffer, &offset))
                return 0
            }
            guard parsed else {
                return 4
            }
            let message = NWProtocolFramer.Message(count: 0)
            if !framer.deliverInputNoCopy(length: count, message: message, isComplete: true) {
                return 0
            }
        }
    }
}

/* TODO: This will end up taking in a type that conforms to a sendable protocol */
extension NWProtocolFramer.Message {
    /* Set completions here */
    convenience init(count: Int) {
        self.init(definition: NineProtocol.definition)
        self["count"] = count
    }
}

func nineProc(_ data: inout Data) throws -> nineResponse {
    try withUnsafeMutableBytes(of: &data) { buffer in
        var offset = 7 /* 7 bits after the header is pulled out */
        let nineResponse = nineResponse(buffer: buffer)
        
        switch(nineResponse.type) {
        case .Rerror:
            nineResponse.error = rstr(buffer: buffer, &offset).split(separator: 0)
        case .Rattach:
            let qid = try rqid(buffer: buffer, &offset)
            nineResponse.qids = [qid]
        case .Rversion:
            let msize = r32(buffer: buffer, &offset)
            MSIZE = msize != MSIZE ? msize : MSIZE
            guard rstr(buffer: buffer, &offset) == version else {
                throw NineErrors.connectError
            }
            print("Rversion")
        case .Rauth:
            // Not implemented
            print("rauth")
        case .Rflush:
            // Flush the given tag, maybe a global
            print("rflush")
        case .Rwalk:
            var tmpqids = [nineQid]()
            let nwqid = r16(buffer: buffer, &offset)
            for _ in 1...nwqid {
                let tmpqid = try rqid(buffer: buffer, &offset)
                tmpqids.append(tmpqid)
            }
            nineResponse.qids = tmpqids
        case .Ropen:
            let qid = try rqid(buffer: buffer, &offset)
            nineResponse.qids = [qid]
            nineResponse.iounit = r32(buffer: buffer, &offset)
        case .Rcreate:
            let qid = try rqid(buffer: buffer, &offset)
            nineResponse.qids = [qid]
            nineResponse.iounit = r32(buffer: buffer, &offset)
        case .Rread:
            let count = r32(buffer: buffer, &offset)
            let data = rstr(buffer: buffer, &offset)
            nineResponse.read = (data, count)
        case .Rwrite:
            nineResponse.write = r32(buffer: buffer, &offset)
        case .Rclunk:
            print("Rclunk")
        case .Rremove:
            print("Rremove")
        case .Rstat:
            let size = r16(buffer: buffer, &offset)
            let type = r16(buffer: buffer, &offset)
            let dev = r32(buffer: buffer, &offset)
            let qid = try rqid(buffer: buffer, &offset)
            let mode = r32(buffer: buffer, &offset)
            let atime = r32(buffer: buffer, &offset)
            let mtime = r32(buffer: buffer, &offset)
            let length = r64(buffer: buffer, &offset)
            let stdata = rstr(buffer: buffer, &offset)
            let chunks = stdata.split(separator: 0)
            if chunks.count != 4 {
                throw NineErrors.decodeError
            }
            
            nineResponse.stat = nineStat(size: size, type: type, dev: dev, qid: qid, mode: nineMode(rawValue: mode)!, atime: atime, mtime: mtime, length: length, name: chunks[0], uid: chunks[1], gid: chunks[2], muid: chunks[3])
        case .Rwstat:
            print("Rwstat")
        default:
            print("ERROR WILL ROBINSON") /* Invalid */
        }
        
        return nineResponse
    }
}

struct Tversion: Messageable, Encodable {
    var encodedData: Data {
        var data = Data(count: 0)
        w32(&data, input: 19)
        w8(&data, input: nineType.Tversion.rawValue)
        w16(&data, input: 0)
        w32(&data, input: MSIZE)
        wstr(&data, input: version)
        return data
    }
    
    var context: NWConnection.ContentContext {
        let message = NWProtocolFramer.Message(count: 19)
        return NWConnection.ContentContext(identifier: "Tversion", metadata: [message])
    }
}

struct Tattach: Messageable, Encodable {
    let length: UInt32
    let fid: UInt32
    let afid: UInt32
    let uname: Data
    let aname: Data
    
    init(fid: UInt32, afid: UInt32, uname: String, aname: String) {

        let size = aname.withPadding + uname.withPadding + 16
        self.length = UInt32(size)
        self.fid = fid
        self.afid = afid /* No auth? Have a global or so to switch */
        self.uname = uname.data(using: .utf8)!
        self.aname = aname.data(using: .utf8)!
    }
    
    var encodedData: Data {
        var data = Data(count: 0)
        w32(&data, input: length)
        w8(&data, input: nineType.Tattach.rawValue)
        w16(&data, input: 0)
        w32(&data, input: 0)
        w32(&data, input: afid)
        wstr(&data, input: uname)
        wstr(&data, input: aname)
        return data
    }
    
    var context: NWConnection.ContentContext {
        return NWConnection.ContentContext(identifier: "Tattach")
    }
}

struct Tflush: Messageable, Encodable {
    let tag: UInt16
    let oldtag: UInt16
    init(tag: UInt16, oldtag: UInt16) {
        self.tag = 0
        self.oldtag = oldtag
    }
    
    var encodedData: Data {
        var data = Data(count: 0)
        w32(&data, input: 11)
        w8(&data, input: nineType.Tflush.rawValue)
        w16(&data, input: tag)
        w16(&data, input: oldtag)
        return data
    }
    
    var context: NWConnection.ContentContext {
        return NWConnection.ContentContext(identifier: "Tflush")
    }
}

struct Twalk: Messageable, Encodable {
    let length: UInt32
    let tag: UInt16
    let fid: UInt32
    let newFid: UInt32
    let nwname: UInt16
    let wnames: [Data]
    
    init(fid: UInt32, newFid: UInt32, nwname: UInt16, wnames: [Data]) {
        var size = 17
        for wname in wnames {
            size += wname.count
        }
        self.length = UInt32(size)
        self.tag = 0
        self.fid = fid
        self.newFid = newFid
        self.nwname = nwname
        self.wnames = wnames
    }
    
    var encodedData: Data {
        var data = Data(count: 0)
        w32(&data, input: length)
        w8(&data, input: nineType.Twalk.rawValue)
        w16(&data, input: tag)
        w32(&data, input: fid)
        w32(&data, input: newFid)
        w16(&data, input: nwname)
        for wname in wnames {
            wstr(&data, input: wname)
        }
        return data
    }
    
    var context: NWConnection.ContentContext {
        return NWConnection.ContentContext(identifier: "Twalk")
    }
}

struct Topen: Messageable, Encodable {
    let tag: UInt16
    let fid: UInt32
    let mode: nineMode
    
    init(tag: UInt16, fid: UInt32, mode: nineMode) {
        self.tag = tag
        self.fid = fid
        self.mode = mode
    }
    
    var encodedData: Data {
        var data = Data(count: 0)
        w32(&data, input: 15)
        w8(&data, input: nineType.Topen.rawValue)
        w16(&data, input: tag)
        w32(&data, input: fid)
        w32(&data, input: mode.rawValue)
        return data
    }
    
    var context: NWConnection.ContentContext {
        return NWConnection.ContentContext(identifier: "Topen")
    }
}

struct Tcreate: Messageable, Encodable {
    let tag: UInt16
    let fid: UInt32
    let name: Data
    let perm: UInt32
    let mode: UInt8
    
    init(tag: UInt16, fid: UInt32, name: String, perm: UInt32, mode: UInt8) {
        self.tag = tag
        self.fid = fid
        self.name = name.data(using: .utf8)!
        self.perm = perm
        self.mode = mode
    }
    
    var encodedData: Data {
        var data = Data(count: 0)
        w32(&data, input: UInt32(name.count + 16))
        w8(&data, input: nineType.Tcreate.rawValue)
        w16(&data, input: tag)
        w32(&data, input: fid)
        wstr(&data, input: name)
        w32(&data, input: perm)
        w8(&data, input: mode)
        return data
    }
    var context: NWConnection.ContentContext {
        return NWConnection.ContentContext(identifier: "Tcreate")
    }
}

struct Tread: Messageable, Encodable {
    let tag: UInt16
    let fid: UInt32
    let offset: UInt64
    let count: UInt32
    
    init(tag: UInt16, fid: UInt32, offset: UInt64, count: UInt32) {
        self.tag = tag
        self.fid = fid
        self.offset = offset
        self.count = count
    }
    
    var encodedData: Data {
        var data = Data(count: 0)
        w32(&data, input: 23)
        w8(&data, input: nineType.Tread.rawValue)
        w16(&data, input: tag)
        w32(&data, input: fid)
        w64(&data, input: offset)
        w32(&data, input: count)
        return data
    }
    
    var context: NWConnection.ContentContext {
        return NWConnection.ContentContext(identifier: "Tread")
    }
}

struct Twrite: Messageable, Encodable {
    let tag: UInt16
    let fid: UInt32
    let offset: UInt64
    let count: UInt32
    let bytes: Data
    
    init(tag: UInt16, fid: UInt32, offset: UInt64, count: UInt32, bytes: Data) {
        self.tag = tag
        self.fid = fid
        self.offset = offset
        self.count = count
        self.bytes = bytes
    }
    
    var encodedData: Data {
        var data = Data(count: 0)
        w32(&data, input: UInt32(bytes.count + 23))
        w8(&data, input: nineType.Twrite.rawValue)
        w16(&data, input: tag)
        w32(&data, input: fid)
        w64(&data, input: offset)
        w32(&data, input: count)
        wstr(&data, input: bytes)
        return data
    }
    
    var context: NWConnection.ContentContext {
        return NWConnection.ContentContext(identifier: "Twrite")
    }
}

struct Tclunk: Messageable, Encodable {
    let tag: UInt16
    let fid: UInt32
    init(tag: UInt16, fid: UInt32) {
        self.tag = tag
        self.fid = fid
    }
    
    var encodedData: Data {
        var data = Data(count: 0)
        w32(&data, input: 11)
        w8(&data, input: nineType.Tclunk.rawValue)
        w16(&data, input: tag)
        w32(&data, input: fid)
        return data
    }
    
    var context: NWConnection.ContentContext {
        return NWConnection.ContentContext(identifier: "Tclunk")
    }
}

struct Tremove: Messageable, Encodable {
    let tag: UInt16
    let fid: UInt32
    init(tag: UInt16, fid: UInt32) {
        self.tag = tag
        self.fid = fid
    }
    
    var encodedData: Data {
        var data = Data(count: 0)
        w32(&data, input: 11)
        w8(&data, input: nineType.Tremove.rawValue)
        w16(&data, input: tag)
        w32(&data, input: fid)
        return data
    }
    
    var context: NWConnection.ContentContext {
        return NWConnection.ContentContext(identifier: "Tremove")
    }
}

struct Tstat: Messageable, Encodable {
    let tag: UInt16
    let fid: UInt32
    init(tag: UInt16, fid: UInt32) {
        self.tag = tag
        self.fid = fid
    }
    
    var encodedData: Data {
        var data = Data(count: 0)
        w32(&data, input: 11)
        w8(&data, input: nineType.Tstat.rawValue)
        w16(&data, input: tag)
        w32(&data, input: fid)
        return data
    }
    
    var context: NWConnection.ContentContext {
        return NWConnection.ContentContext(identifier: "Tstat")
    }
}

struct Twstat: Messageable, Encodable {
    let tag: UInt16
    let fid: UInt32
    let stat: nineStat
    
    init(tag: UInt16, fid: UInt32, stat: nineStat) {
        self.tag = tag
        self.fid = fid
        self.stat = stat
    }
    
    var encodedData: Data {
        var data = Data(count: 0)
        let length = 52 + stat.name.count + stat.uid.count + stat.gid.count + stat.muid.count
        w32(&data, input: UInt32(length))
        w8(&data, input: nineType.Twstat.rawValue)
        w16(&data, input: tag)
        w32(&data, input: fid)
        w16(&data, input: stat.size)
        w16(&data, input: stat.type)
        w32(&data, input: stat.dev)
        w8(&data, input: stat.qid.type.rawValue)
        w32(&data, input: stat.qid.version)
        w64(&data, input: stat.qid.path)
        w32(&data, input: stat.mode.rawValue)
        w32(&data, input: stat.atime)
        w32(&data, input: stat.mtime)
        w64(&data, input: stat.length)
        wstr(&data, input: stat.name)
        wstr(&data, input: stat.name)
        wstr(&data, input: stat.uid)
        wstr(&data, input: stat.gid)
        wstr(&data, input: stat.muid)
        return data
    }
    
    var context: NWConnection.ContentContext {
        return NWConnection.ContentContext(identifier: "Twstat")
    }
}

/* Utility functions */
func rqid(buffer: UnsafeMutableRawBufferPointer, _ base: inout Int) throws -> nineQid {
    let type = r8(buffer: buffer, &base)
    let vers = r32(buffer: buffer, &base)
    let path = r64(buffer: buffer, &base)
    
    if let parsedFileType = fileType(rawValue: type) {
        return nineQid(type: parsedFileType, version: vers, path: path)
    }
    throw NineErrors.decodeError
}

func w8(_ data: inout Data, input: UInt8) {
    var tempInput = input.littleEndian
    data.append(Data(bytes: &tempInput, count: MemoryLayout<UInt8>.size))
}

func w16(_ data: inout Data, input: UInt16) {
    w8(&data, input: UInt8(input & 0x00ff))
    w8(&data, input: UInt8(input >> 8))
}

func w32(_ data: inout Data, input: UInt32) {
    w16(&data, input: UInt16(input & 0x0000ffff))
    w16(&data, input: UInt16(input >> 16))
}

func w64(_ data: inout Data, input: UInt64) {
    w32(&data, input: UInt32(input & 0x00000000ffffffff))
    w32(&data, input: UInt32(input >> 32))
}

func wstr(_ data: inout Data, input: Data) {
    let rev = input.reversed()
    let padding = rev.count % 4
    if padding > 0 {
        for _ in 1...4 - padding {
            w8(&data, input: 0x0)
        }
    }
    // Write out the rest of our bytes
    for i in 0...rev.count - 1 {
        var tempInput = input[i].bigEndian
        data.append(Data(bytes: &tempInput, count: MemoryLayout<UInt8>.size))

    }
}

func r8(buffer: UnsafeMutableRawBufferPointer, _ base: inout Int) -> UInt8 {
    var tempVar: UInt8 = 0
    withUnsafeMutableBytes(of: &tempVar) { ptr in
        ptr.copyBytes(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: base),
                                                   count: MemoryLayout<UInt8>.size ))
    }
    base += MemoryLayout<UInt8>.size
    print("Reading UInt8 \(tempVar)")
    return tempVar.littleEndian
}

func r16(buffer: UnsafeMutableRawBufferPointer, _ base: inout Int) -> UInt16 {
    var tempVar: UInt16 = 0
    withUnsafeMutableBytes(of: &tempVar) { ptr in
        ptr.copyBytes(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: base),
                                                   count: MemoryLayout<UInt16>.size))
    }
    base += MemoryLayout<UInt16>.size
    print("Reading UInt16 \(tempVar)")
    return tempVar.littleEndian
}

func r32(buffer: UnsafeMutableRawBufferPointer, _ base: inout Int) -> UInt32 {
    var tempVar: UInt32 = 0
    if buffer.isEmpty {
        return 0
    }
    withUnsafeMutableBytes(of: &tempVar) { ptr in
        ptr.copyBytes(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: base),
                                                   count: MemoryLayout<UInt32>.size))
    }
    base += MemoryLayout<UInt32>.size
    print("Reading UInt32 \(tempVar)")
    return tempVar.littleEndian
}

func r64(buffer: UnsafeMutableRawBufferPointer, _ base: inout Int) -> UInt64 {
    var tempVar: UInt64 = 0
    withUnsafeMutableBytes(of: &tempVar) { ptr in
        ptr.copyBytes(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: base),
                                                   count: MemoryLayout<UInt64>.size))
    }
    base += MemoryLayout<UInt64>.size
    print("Reading UInt64 \(tempVar)")
    return tempVar.littleEndian
}

func rstr(buffer: UnsafeMutableRawBufferPointer, _ base: inout Int) -> Data {
    var tempVar: Data = Data(count: 0)
    while base < buffer.count {
        withUnsafeMutableBytes(of: &tempVar) { ptr in
            ptr.copyBytes(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: base), count: MemoryLayout<UInt8>.size))
        }
        // This may be a break here
        if tempVar[base] == 0 {
            break
        }
        base += MemoryLayout<UInt8>.size
    }
    return tempVar
}

extension Data {
    public var bytes: [UInt8]
    {
        return [UInt8](self)
    }
}

extension String {
    public var withPadding: Int {
         return (self.count % 4 > 0) ? (self.count / 4 + 1) * 4 : self.count
    }
}
