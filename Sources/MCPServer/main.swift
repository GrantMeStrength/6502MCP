import Foundation
import Darwin
import Emulator6502

final class EmulatorSession {
    private let cpu = CPU()
    private let assembler = Assembler6502()

    init() {
        reset(computer: "KIM1")
    }

    func reset(computer: String) {
        let mode = computer.uppercased() == "APL" ? "APL" : "KIM1"
        cpu.Init(ProgramName: "", computer: mode)
        cpu.RESET()
    }

    func assemble(source: String) -> AssemblyResult {
        assembler.assemble(source: source)
    }

    func load(origin: UInt16, bytes: [UInt8]) -> Int {
        for (offset, byte) in bytes.enumerated() {
            let address = origin &+ UInt16(offset)
            cpu.Write(address: address, byte: byte)
        }
        return bytes.count
    }

    func setPC(_ address: UInt16) {
        cpu.SetPC(ProgramCounter: address)
    }

    func run(steps: Int, startAddress: UInt16?) -> (executed: Int, last: (address: UInt16, Break: Bool, opcode: String, display: Bool)) {
        if let startAddress {
            cpu.SetPC(ProgramCounter: startAddress)
        }
        var executed = 0
        var last = (address: cpu.GetPC(), Break: false, opcode: "", display: false)
        while executed < steps {
            last = cpu.Step()
            executed += 1
            if last.Break {
                break
            }
        }
        return (executed, last)
    }

    func readMemory(address: UInt16, length: Int) -> [UInt8] {
        guard length > 0 else { return [] }
        return (0..<length).map { offset in
            cpu.Read(address: address &+ UInt16(offset))
        }
    }

    func writeMemory(address: UInt16, bytes: [UInt8]) -> Int {
        for (offset, byte) in bytes.enumerated() {
            cpu.Write(address: address &+ UInt16(offset), byte: byte)
        }
        return bytes.count
    }

    func registers() -> [String: Any] {
        [
            "A": Int(cpu.getA()),
            "X": Int(cpu.getX()),
            "Y": Int(cpu.getY()),
            "PC": Int(cpu.GetPC()),
            "status": Int(cpu.GetStatusRegister())
        ]
    }
}

final class MCPServer {
    private let input = FileHandle.standardInput
    private let output: FileHandle
    private let session = EmulatorSession()

    init(output: FileHandle) {
        self.output = output
    }

    func run() {
        var buffer = Data()
        while true {
            let chunk = input.readData(ofLength: 4096)
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let messageData = extractMessage(from: &buffer) {
                handle(messageData: messageData)
            }
        }
    }

    private func extractMessage(from buffer: inout Data) -> Data? {
        let delimiter = Data("\r\n\r\n".utf8)
        guard let headerRange = buffer.range(of: delimiter) else {
            return nil
        }
        let headerData = buffer.subdata(in: buffer.startIndex..<headerRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            return nil
        }
        var contentLength: Int?
        for line in headerString.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                contentLength = Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
        guard let length = contentLength else {
            return nil
        }
        let messageStart = headerRange.upperBound
        let messageEnd = messageStart + length
        guard buffer.count >= messageEnd else {
            return nil
        }
        let messageData = buffer.subdata(in: messageStart..<messageEnd)
        buffer.removeSubrange(buffer.startIndex..<messageEnd)
        return messageData
    }

    private func handle(messageData: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] else {
            sendError(id: nil, code: -32700, message: "Invalid JSON")
            return
        }
        let id = json["id"]
        guard let method = json["method"] as? String else {
            sendError(id: id, code: -32600, message: "Missing method")
            return
        }

        switch method {
        case "initialize":
            let result: [String: Any] = [
                "protocolVersion": "2024-11-05",
                "capabilities": [
                    "tools": ["listChanged": false]
                ],
                "serverInfo": [
                    "name": "6502MCP",
                    "version": "0.1.0"
                ]
            ]
            sendResult(id: id, result: result)
        case "initialized":
            break
        case "tools/list":
            sendResult(id: id, result: ["tools": toolDefinitions()])
        case "tools/call":
            guard let params = json["params"] as? [String: Any],
                  let name = params["name"] as? String,
                  let arguments = params["arguments"] as? [String: Any] else {
                sendError(id: id, code: -32602, message: "Missing tool parameters")
                return
            }
            let result = callTool(name: name, arguments: arguments)
            sendResult(id: id, result: result)
        case "shutdown":
            sendResult(id: id, result: NSNull())
        case "exit":
            exit(0)
        default:
            sendError(id: id, code: -32601, message: "Method not found")
        }
    }

    private func callTool(name: String, arguments: [String: Any]) -> [String: Any] {
        switch name {
        case "assemble":
            guard let source = arguments["source"] as? String else {
                return toolError("assemble requires a source string.")
            }
            let result = session.assemble(source: source)
            let originValue: Any = result.origin.map { Int($0) } as Any
            let objectCode = result.objectCode.map(Int.init)
            let bytes = Array(result.objectCode.dropFirst(2)).map(Int.init)
            let symbols = result.symbolTable.mapValues { Int($0) }
            let payload: [String: Any] = [
                "origin": originValue,
                "objectCode": objectCode,
                "bytes": bytes,
                "listing": result.listing,
                "symbols": symbols
            ]
            return toolResult(payload)
        case "assemble_and_load":
            guard let source = arguments["source"] as? String else {
                return toolError("assemble_and_load requires a source string.")
            }
            let result = session.assemble(source: source)
            guard let origin = result.origin else {
                return toolError("Assembly did not produce an origin.")
            }
            let bytes = Array(result.objectCode.dropFirst(2))
            let loaded = session.load(origin: origin, bytes: bytes)
            session.setPC(origin)
            return toolResult([
                "origin": Int(origin),
                "loaded": loaded,
                "bytes": bytes.map(Int.init),
                "listing": result.listing
            ])
        case "load":
            guard let origin = intParam(arguments["origin"]),
                  let bytes = byteArray(arguments["bytes"]) else {
                return toolError("load requires origin and bytes.")
            }
            let loaded = session.load(origin: UInt16(origin), bytes: bytes)
            return toolResult([
                "origin": origin,
                "loaded": loaded
            ])
        case "reset":
            let computer = (arguments["computer"] as? String) ?? "KIM1"
            session.reset(computer: computer)
            return toolResult(["computer": computer])
        case "set_pc":
            guard let address = intParam(arguments["address"]) else {
                return toolError("set_pc requires an address.")
            }
            session.setPC(UInt16(address))
            return toolResult(["PC": address])
        case "run":
            let steps = intParam(arguments["steps"]) ?? 1000
            let startAddress = intParam(arguments["startAddress"]).map(UInt16.init)
            let result = session.run(steps: max(1, steps), startAddress: startAddress)
            return toolResult([
                "executed": result.executed,
                "break": result.last.Break,
                "PC": Int(result.last.address),
                "registers": session.registers()
            ])
        case "read_memory":
            guard let address = intParam(arguments["address"]),
                  let length = intParam(arguments["length"]) else {
                return toolError("read_memory requires address and length.")
            }
            let bytes = session.readMemory(address: UInt16(address), length: max(0, length))
            return toolResult([
                "address": address,
                "bytes": bytes.map(Int.init)
            ])
        case "write_memory":
            guard let address = intParam(arguments["address"]),
                  let bytes = byteArray(arguments["bytes"]) else {
                return toolError("write_memory requires address and bytes.")
            }
            let written = session.writeMemory(address: UInt16(address), bytes: bytes)
            return toolResult([
                "address": address,
                "written": written
            ])
        case "get_registers":
            return toolResult(session.registers())
        default:
            return toolError("Unknown tool: \(name)")
        }
    }

    private func toolDefinitions() -> [[String: Any]] {
        [
            [
                "name": "assemble",
                "description": "Assemble 6502 source into object code and a listing.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "source": ["type": "string", "description": "6502 assembly source."]
                    ],
                    "required": ["source"]
                ]
            ],
            [
                "name": "assemble_and_load",
                "description": "Assemble 6502 source, load it into memory, and set PC to origin.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "source": ["type": "string", "description": "6502 assembly source."]
                    ],
                    "required": ["source"]
                ]
            ],
            [
                "name": "load",
                "description": "Load raw bytes into memory at the provided origin.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "origin": ["type": "integer", "minimum": 0, "maximum": 65535],
                        "bytes": [
                            "type": "array",
                            "items": ["type": "integer", "minimum": 0, "maximum": 255]
                        ]
                    ],
                    "required": ["origin", "bytes"]
                ]
            ],
            [
                "name": "reset",
                "description": "Reset the emulator and reload the default memory map.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "computer": ["type": "string", "description": "KIM1 (default) or APL."]
                    ]
                ]
            ],
            [
                "name": "set_pc",
                "description": "Set the program counter.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "address": ["type": "integer", "minimum": 0, "maximum": 65535]
                    ],
                    "required": ["address"]
                ]
            ],
            [
                "name": "run",
                "description": "Run the CPU for a number of steps, optionally from a start address.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "steps": ["type": "integer", "minimum": 1],
                        "startAddress": ["type": "integer", "minimum": 0, "maximum": 65535]
                    ]
                ]
            ],
            [
                "name": "read_memory",
                "description": "Read a range of memory.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "address": ["type": "integer", "minimum": 0, "maximum": 65535],
                        "length": ["type": "integer", "minimum": 1, "maximum": 65536]
                    ],
                    "required": ["address", "length"]
                ]
            ],
            [
                "name": "write_memory",
                "description": "Write bytes into memory.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "address": ["type": "integer", "minimum": 0, "maximum": 65535],
                        "bytes": [
                            "type": "array",
                            "items": ["type": "integer", "minimum": 0, "maximum": 255]
                        ]
                    ],
                    "required": ["address", "bytes"]
                ]
            ],
            [
                "name": "get_registers",
                "description": "Get CPU register values.",
                "inputSchema": ["type": "object", "properties": [:]]
            ]
        ]
    }

    private func toolResult(_ payload: [String: Any]) -> [String: Any] {
        ["content": [["type": "text", "text": jsonString(payload)]]]
    }

    private func toolError(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": message]], "isError": true]
    }

    private func intParam(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    private func byteArray(_ value: Any?) -> [UInt8]? {
        guard let raw = value as? [Any] else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(raw.count)
        for item in raw {
            guard let intValue = intParam(item), intValue >= 0, intValue <= 255 else {
                return nil
            }
            bytes.append(UInt8(intValue))
        }
        return bytes
    }

    private func jsonString(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private func sendResult(id: Any?, result: Any) {
        let response: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "result": result
        ]
        send(response)
    }

    private func sendError(id: Any?, code: Int, message: String) {
        let response: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "error": [
                "code": code,
                "message": message
            ]
        ]
        send(response)
    }

    private func send(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return
        }
        let header = "Content-Length: \(data.count)\r\n\r\n"
        if let headerData = header.data(using: .utf8) {
            output.write(headerData)
        }
        output.write(data)
        output.synchronizeFile()
    }
}

let stdoutFd = dup(STDOUT_FILENO)
dup2(STDERR_FILENO, STDOUT_FILENO)
let output = FileHandle(fileDescriptor: stdoutFd, closeOnDealloc: true)
MCPServer(output: output).run()
