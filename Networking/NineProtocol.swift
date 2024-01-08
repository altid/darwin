//
//  9pProtocol.swift
//  Altid
//
//  Created by halfwit on 2024-01-03.
//

import Foundation
import Network

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

// Main framing protocol
class NineProtocol: NWProtocolFramerImplementation {
    static let definition = NWProtocolFramer.Definition(implementation: NineProtocol.self)
    static var label: String { return "9p" }
    
    required init(framer: NWProtocolFramer.Instance) { }
    
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        return .ready
    }
    func wakeup(framer: NWProtocolFramer.Instance) { }
    func stop(framer: NWProtocolFramer.Instance) -> Bool { return true }
    func cleanup(framer: NWProtocolFramer.Instance) { }
    
    
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        let type = message.nineType
        let header = NineProtocolHeader(length: UInt32(messageLength), type: type.rawValue, tag: message.nineTag)
        framer.writeOutput(data: header.encodedData)
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch let error {
            print("Hit error writing \(error)")
        }
    }
    
    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var tempHeader: NineProtocolHeader? = nil
            let headerSize = NineProtocolHeader.encodedSize
            let parsed = framer.parseInput(minimumIncompleteLength: headerSize,
                                           maximumLength: headerSize) { (buffer, isComplete) -> Int in
                guard let buffer = buffer else {
                    return 0
                }
                if buffer.count < headerSize {
                    return 0
                }
                tempHeader = NineProtocolHeader(buffer)
                return headerSize
            }
            guard parsed, let header = tempHeader else {
                return headerSize
            }
            
            var messageType = nineType.invalid
            if let parsedMessageType = nineType(rawValue: header.type) {
                messageType = parsedMessageType
            }
            let message = NWProtocolFramer.Message(nineType: messageType, nineTag: header.tag)
            if !framer.deliverInputNoCopy(length: Int(header.length), message: message, isComplete: true) {
                return 0
            }
        }
    }
}

// Extend framer messages to handle storing your command types in the message metadata.
extension NWProtocolFramer.Message {
    convenience init(nineType: nineType, nineTag: UInt16) {
        self.init(definition: NineProtocol.definition)
        self["nineType"] = nineType
        self["nineTag"] = nineTag
    }
    
    var nineTag: UInt16 {
        if let tag = self["nineTag"] as? UInt16 {
            return tag
        } else {
            return 0xFFFF
        }
    }
    var nineType: nineType {
        if let type = self["nineType"] as? nineType {
            return type
        } else {
            return .invalid
        }
    }
}

// Encoders/decoders for our headers and data bodies
struct NineProtocolHeader: Codable {
    let length: UInt32
    let type: UInt8
    let tag: UInt16
    
    init(length: UInt32, type: UInt8, tag: UInt16) {
        self.length = length
        self.type = type
        self.tag = tag
    }
    
    // Get the type and tag
    init(_ buffer: UnsafeMutableRawBufferPointer) {
        var tempLength: UInt32 = 0
        var tempType: UInt8 = 0
        var tempTag: UInt16 = 0
        withUnsafeMutableBytes(of: &tempLength) { typePtr in
            typePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0),
                                                            count: MemoryLayout<UInt32>.size))
        }
        withUnsafeMutableBytes(of: &tempType) { tagPtr in
            tagPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt32>.size),
                                                           count: MemoryLayout<UInt8>.size))
        }
        withUnsafeMutableBytes(of: &tempTag) { lengthPtr in
            lengthPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt32>.size + MemoryLayout<UInt8>.size),
                                                              count: MemoryLayout<UInt16>.size))
        }
        length = tempLength
        type = tempType
        tag = tempTag
    }
    
    var encodedData: Data {
        var tempLength = length
        var tempType = type
        var tempTag = tag
        var data = Data(bytes: &tempLength, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempType, count: MemoryLayout<UInt8>.size))
        data.append(Data(bytes: &tempTag, count: MemoryLayout<UInt16>.size))
        return data
    }
    
    static var encodedSize: Int {
        return MemoryLayout<UInt8>.size + MemoryLayout<UInt16>.size + MemoryLayout<UInt32>.size
    }
}

struct Tversion: Encodable {
    let msize: UInt32
    let version: Data
    
    init(msize: UInt32, version: Data) {
        self.msize = msize
        self.version = version
    }
    
    var encodedData: Data {
        var tempMsize = msize
        var data = Data(bytes: &tempMsize, count: MemoryLayout<UInt32>.size)
        data.append(version)
        return data
    }
}

struct Rversion: Decodable {
    let msize: UInt32
    let version: Data
    
    init(_ buffer: UnsafeMutableRawBufferPointer) {
        var tempMsize: UInt32 = 8192
        var tempVersion: Data = Data(count: 0)
        withUnsafeMutableBytes(of: &tempMsize) { msizePtr in
            msizePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0),
                                                             count: MemoryLayout<UInt32>.size))
        }
        withUnsafeMutableBytes(of: &tempVersion) { vPtr in
            vPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt32>.size), count: .max))
        }
        msize = tempMsize
        version = tempVersion
    }
}

struct Tattach: Encodable {
    let fid: UInt32
    let afid: UInt32
    let uname: Data
    let aname: Data
    
    init(fid: UInt32, afid: UInt32, uname: Data, aname: Data) {
        self.fid = fid
        self.afid = afid
        self.uname = uname
        self.aname = aname
    }
    
    var encodedData: Data {
        var tempFid: UInt32 = fid
        var tempAfid: UInt32 = afid
        var data = Data(bytes: &tempFid, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempAfid, count: MemoryLayout<UInt32>.size))
        data.append(uname)
        data.append(aname)
        return data
    }
}

struct Rattach: Decodable {
    let qid: nineQid
    
    init(_ buffer: UnsafeMutableRawBufferPointer) throws {
        qid = try toQid(buffer: buffer)
    }
}

struct Tflush: Encodable {
    let oldtag: UInt16
    init(oldtag: UInt16) {
        self.oldtag = oldtag
    }
    
    var encodedData: Data {
        var tempOldTag: UInt16 = oldtag
        let data = Data(bytes: &tempOldTag, count: MemoryLayout<UInt16>.size)
        return data
    }
}

struct Rflush: Decodable {
    // No data in body
}

struct Twalk: Encodable {
    let fid: UInt32
    let newFid: UInt32
    let nwname: UInt16
    let wnames: [Data]
    
    init(fid: UInt32, newFid: UInt32, nwname: UInt16, wnames: [Data]) {
        self.fid = fid
        self.newFid = newFid
        self.nwname = nwname
        self.wnames = wnames
    }
    
    var encodedData: Data {
        var tempFid = fid
        var tempNewFid = newFid
        var tempNwname = nwname
        
        var data = Data(bytes: &tempFid, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempNewFid, count: MemoryLayout<UInt32>.size))
        data.append(Data(bytes: &tempNwname, count: MemoryLayout<UInt16>.size))
        for wname in wnames {
            data.append(wname)
        }
        return data
    }
}

struct Rwalk: Decodable {
    let nwqid: UInt16
    let qid: [nineQid]
    
    init(_ buffer: UnsafeMutableRawBufferPointer) {
        var offset = MemoryLayout<UInt16>.size
        var tempnwqid: UInt16 = 0
        var qids: [nineQid] = []
        withUnsafeMutableBytes(of: &tempnwqid) { nwqidPtr in
            nwqidPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0),
                                                             count: MemoryLayout<UInt16>.size))
        }

        for _ in 1...tempnwqid {
            do {
                let tmpqid: nineQid = try toQid(buffer: buffer, base: offset)
                qids.append(tmpqid)
            } catch {
                print("Error")
            }
            offset += MemoryLayout<nineQid>.size
        }
        nwqid = tempnwqid
        qid = qids
    }
}

struct Topen: Encodable {
    let fid: UInt32
    let mode: nineMode
    
    init(fid: UInt32, mode: nineMode) {
        self.fid = fid
        self.mode = mode
    }
    
    var encodedData: Data {
        var tempFid = fid
        var tempMode = mode
        
        var data = Data(bytes: &tempFid, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempMode, count: MemoryLayout<nineMode>.size))
        return data
    }
}

struct Ropen: Decodable {
    let qid: nineQid
    let iounit: UInt32
    
    init(_ buffer: UnsafeMutableRawBufferPointer) throws {
        var tempIOUnit: UInt32 = 0
        qid = try toQid(buffer: buffer)
        withUnsafeMutableBytes(of: &tempIOUnit) { iounitPtr in
            iounitPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<nineQid>.size),
                                                             count: MemoryLayout<UInt32>.size))
        }
        iounit = tempIOUnit
    }
}

struct Tcreate: Encodable {
    let fid: UInt32
    let name: Data
    let perm: UInt32
    let mode: UInt8
    
    init(fid: UInt32, name: Data, perm: UInt32, mode: UInt8) {
        self.fid = fid
        self.name = name
        self.perm = perm
        self.mode = mode
    }
    
    var encodedData: Data {
        var tempFid = fid
        var tempPerm = perm
        var tempMode = mode
        
        var data = Data(bytes: &tempFid, count: MemoryLayout<UInt32>.size)
        data.append(name)
        data.append(Data(bytes: &tempPerm, count: MemoryLayout<UInt32>.size))
        data.append(Data(bytes: &tempMode, count: MemoryLayout<UInt8>.size))
        return data
    }
}

struct Rcreate: Decodable {
    let qid: nineQid
    let iounit: UInt32
    
    init(_ buffer: UnsafeMutableRawBufferPointer) throws {
        var tempIOUnit: UInt32 = 0
        qid = try toQid(buffer: buffer)
        withUnsafeMutableBytes(of: &tempIOUnit) { iounitPtr in
            iounitPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<nineQid>.size),
                                                             count: MemoryLayout<UInt32>.size))
        }
        iounit = tempIOUnit
    }
}

struct Tread: Encodable {
    let fid: UInt32
    let offset: UInt64
    let count: UInt32
    
    init(fid: UInt32, offset: UInt64, count: UInt32) {
        self.fid = fid
        self.offset = offset
        self.count = count
    }
    
    var encodedData: Data {
        var tempFid = fid
        var tempOffset = offset
        var tempCount = count
        var data = Data(bytes: &tempFid, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempOffset, count: MemoryLayout<UInt64>.size))
        data.append(Data(bytes: &tempCount, count: MemoryLayout<UInt32>.size))
        return data
    }
    
    static var encodedSize: Int {
        return MemoryLayout<UInt32>.size * 4
    }
}

struct Rread: Decodable {
    let count: UInt32
    let data: Data
    
    init(_ buffer: UnsafeMutableRawBufferPointer) {
        var tempCount: UInt32 = 0
        var tempData: Data = Data(count :0)
        withUnsafeMutableBytes(of: &tempCount) { countPtr in
            countPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0),
                                                             count: MemoryLayout<UInt32>.size))
        }
        withUnsafeMutableBytes(of: &tempData) { dataPtr in
            dataPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt32>.size),
                                                            count: Int(tempCount)))
        }
        count = tempCount
        data = tempData
    }
}

struct Twrite: Encodable {
    let fid: UInt32
    let offset: UInt64
    let count: UInt32
    let bytes: Data
    
    init(fid: UInt32, offset: UInt64, count: UInt32, bytes: Data) {
        self.fid = fid
        self.offset = offset
        self.count = count
        self.bytes = bytes
    }
    
    var encodedData: Data {
        var tempFid = fid
        var tempOffset = offset
        var tempCount = count
        var data = Data(bytes: &tempFid, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempOffset, count: MemoryLayout<UInt64>.size))
        data.append(Data(bytes: &tempCount, count: MemoryLayout<UInt32>.size))
        data.append(bytes)
        return data
    }
    
    static var encodedSize: Int {
        return MemoryLayout<UInt32>.size * 4
    }
}

struct Rwrite: Decodable {
    let count: UInt32
    
    init(_ buffer: UnsafeMutableRawBufferPointer) {
        var tempCount: UInt32 = 0
        withUnsafeMutableBytes(of: &tempCount) { countPtr in
            countPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0),
                                                             count: MemoryLayout<UInt32>.size))
        }
        count = tempCount
    }
}

struct Tclunk: Encodable {
    let fid: UInt32
    init(fid: UInt32) {
        self.fid = fid
    }
    
    var encodedData: Data {
        var tempFid = fid
        return Data(bytes: &tempFid, count: MemoryLayout<UInt32>.size)
    }
}

struct Rclunk: Decodable {
    // No data in body
}

struct Tremove: Encodable {
    let fid: UInt32
    init(fid: UInt32) {
        self.fid = fid
    }
    
    var encodedData: Data {
        var tempFid = fid
        return Data(bytes: &tempFid, count: MemoryLayout<UInt32>.size)
    }
}

struct Rremove: Decodable {
    // No data in body
}

struct Tstat: Encodable {
    let fid: UInt32
    init(fid: UInt32) {
        self.fid = fid
    }
    
    var encodedData: Data {
        var tempFid = fid
        return Data(bytes: &tempFid, count: MemoryLayout<UInt32>.size)
    }
}

struct Rstat: Decodable {
    let stat: nineStat
    
    init(_ buffer: UnsafeMutableRawBufferPointer) throws {
        var offset: Int = 0
        var tempSize: UInt16 = 0
        var tempType: UInt16 = 0
        var tempDev: UInt32 = 0
        var tempQid: nineQid
        var tempMode: UInt32 = 0
        var tempAtime: UInt32 = 0
        var tempMtime: UInt32 = 0
        var tempLength: UInt64 = 0
        var tempData: Data = Data(count: 0)
        withUnsafeMutableBytes(of: &tempSize) { sizePtr in
            sizePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: offset),
                                                             count: MemoryLayout<UInt16>.size))
        }
        offset += MemoryLayout<UInt16>.size
        withUnsafeMutableBytes(of: &tempType) { typePtr in
            typePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: offset),
                                                            count: MemoryLayout<UInt16>.size))
        }
        offset += MemoryLayout<UInt16>.size
        withUnsafeMutableBytes(of: &tempDev) { devPtr in
            devPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: offset),
                                                            count: MemoryLayout<UInt32>.size))
        }
        offset += MemoryLayout<UInt32>.size
        tempQid = try toQid(buffer: buffer, base: offset)
        offset += MemoryLayout<nineQid>.size
        withUnsafeMutableBytes(of: &tempMode) { modePtr in
            modePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: offset),
                                                            count: MemoryLayout<nineMode>.size))
        }
        offset += MemoryLayout<UInt32>.size
        withUnsafeMutableBytes(of: &tempAtime) { atimePtr in
            atimePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: offset),
                                                            count: MemoryLayout<UInt32>.size))
        }
        offset += MemoryLayout<UInt32>.size
        withUnsafeMutableBytes(of: &tempMtime) { mtimePtr in
            mtimePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: offset),
                                                            count: MemoryLayout<UInt32>.size))
        }
        offset += MemoryLayout<UInt32>.size
        withUnsafeMutableBytes(of: &tempLength) { lenPtr in
            lenPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: offset),
                                                            count: MemoryLayout<UInt64>.size))
        }
        offset += MemoryLayout<UInt64>.size
        withUnsafeMutableBytes(of: &tempData) { dataPtr in
            dataPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: offset),
                                                            count: buffer.count - offset))
        }
        let chunks = tempData.split(separator: 0)
        if chunks.count != 4 {
            throw NineErrors.decodeError
        }
        
        stat = nineStat(size: tempSize, type: tempType, dev: tempDev, qid: tempQid, mode: nineMode(rawValue: tempMode)!, atime: tempAtime, mtime: tempMtime, length: tempLength, name: chunks[0], uid: chunks[1], gid: chunks[2], muid: chunks[3])
    }
}

struct Twstat: Encodable {
    let fid: UInt32
    let stat: nineStat
    
    init(fid: UInt32, stat: nineStat) {
        self.fid = fid
        self.stat = stat
    }
    
    var encodedData: Data {
        var tempFid = fid
        var tempSize = stat.size
        var tempType = stat.type
        var tempDev = stat.dev
        var tempQid = stat.qid
        var tempMode = stat.mode
        var tempAtime = stat.atime
        var tempMtime = stat.mtime
        var tempLength = stat.length

        var data = Data(bytes: &tempFid, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempSize, count: MemoryLayout<UInt16>.size))
        data.append(Data(bytes: &tempType, count: MemoryLayout<UInt16>.size))
        data.append(Data(bytes: &tempDev, count: MemoryLayout<UInt32>.size))
        data.append(Data(bytes: &tempQid.type, count: MemoryLayout<UInt8>.size))
        data.append(Data(bytes: &tempQid.version, count: MemoryLayout<UInt32>.size))
        data.append(Data(bytes: &tempQid.path, count: MemoryLayout<UInt64>.size))
        data.append(Data(bytes: &tempMode, count: MemoryLayout<UInt32>.size))
        data.append(Data(bytes: &tempAtime, count: MemoryLayout<UInt32>.size))
        data.append(Data(bytes: &tempMtime, count: MemoryLayout<UInt32>.size))
        data.append(Data(bytes: &tempLength, count: MemoryLayout<UInt32>.size))
        data.append(stat.name)
        data.append(stat.uid)
        data.append(stat.gid)
        data.append(stat.muid)
        return data
    }
}

struct Rwstat: Decodable {
    // No data in body
}

/* Utility functions */
func toQid(buffer: UnsafeMutableRawBufferPointer, base: Int = 0) throws -> nineQid {
    // Read in the three values, create the qid
    var tempType: UInt8 = 0
    var tempVer: UInt32 = 0
    var tempPath: UInt64 = 0
    withUnsafeMutableBytes(of: &tempType) { typePtr in
        typePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: base),
                                                        count: MemoryLayout<UInt8>.size))
    }
    withUnsafeMutableBytes(of: &tempVer) { verPtr in
        verPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: base + MemoryLayout<UInt8>.size),
                                                       count: MemoryLayout<UInt32>.size))
    }
    withUnsafeMutableBytes(of: &tempPath) { pathPtr in
        pathPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: base + MemoryLayout<UInt32>.size + MemoryLayout<UInt8>.size),
                                                       count: MemoryLayout<UInt64>.size))
    }
    if let parsedFileType = fileType(rawValue: tempType) {
        return nineQid(type: parsedFileType, version: tempVer, path: tempPath)
    }
    throw NineErrors.decodeError
}
