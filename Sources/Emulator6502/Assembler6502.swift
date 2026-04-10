import Foundation

public struct AssemblyResult {
    public let origin: UInt16?
    public let objectCode: [UInt8]
    public let listing: String
    public let symbolTable: [String: UInt16]
}

public final class Assembler6502 {
    private var objectCode: [UInt8] = []
    private var objectCodeText: String = ""

    public init() {}

    public func assemble(source: String) -> AssemblyResult {
        objectCode.removeAll()
        objectCodeText = ""

        let singleByteInstructions: [String: UInt] = [
            "BRK": 0x00, "PHP": 0x08, "CLC": 0x18, "INCA": 0x1A, "PLP": 0x28, "SEC": 0x38,
            "DECA": 0x3A, "RTI": 0x40, "PHA": 0x48, "CLI": 0x58, "PHY": 0x5A, "RTS": 0x60,
            "PLA": 0x68, "SEI": 0x78, "PLY": 0x7A, "DEY": 0x88, "TXA": 0x8A, "TYA": 0x98,
            "TXS": 0x9A, "TAY": 0xA8, "TAX": 0xAA, "CLV": 0xB8, "TSX": 0xBA, "INY": 0xC8,
            "DEX": 0xCA, "CLD": 0xD8, "PHX": 0xDA, "INX": 0xE8, "NOP": 0xEA, "SED": 0xF8,
            "PLX": 0xFA
        ]

        let branchInstructions: [String: UInt] = [
            "BCC": 0x90, "BCS": 0xB0, "BEQ": 0xF0, "BMI": 0x30, "BPL": 0x10,
            "BNE": 0xD0, "BRA": 0x80, "BVC": 0x50, "BVS": 0x70
        ]

        var PC: UInt16 = 0
        var symbolTable: [String: UInt16] = [:]

        // Zero pass - remove comments
        var newSourceCode = ""
        let sourceCodeLines = source.components(separatedBy: "\n")
        for line in sourceCodeLines where line != "" {
            if line.contains(";") {
                let s = line.components(separatedBy: ";")
                newSourceCode += s[0] + "\n"
            } else {
                newSourceCode += line + "\n"
            }
        }

        // Upcase and replace smart quotes
        newSourceCode = newSourceCode.uppercased()
        newSourceCode = newSourceCode.replacingOccurrences(of: "“", with: "\"")
        newSourceCode = newSourceCode.replacingOccurrences(of: "”", with: "\"")

        // Tokenize
        var tokens = newSourceCode.uppercased().condensed.components(separatedBy: CharacterSet.whitespacesAndNewlines)

        var pass = 1
        while pass < 3 {
            PC = 0
            objectCode.removeAll()
            objectCodeText = "--- Assembly output ---\n\n"

            var numberOfBytes: UInt16 = 0
            var index = 0
            while index < tokens.count {
                let word = tokens[index]
                index += 1

                if pass == 2 {
                    displayObjectCode(text: String(format: "%04X", PC) + "\t")
                }

                numberOfBytes = 0

                if word.hasSuffix(":") {
                    numberOfBytes = 1
                    symbolTable.updateValue(PC, forKey: word.replacingOccurrences(of: ":", with: ""))
                } else if word == "ORG" {
                    numberOfBytes = 0
                    PC = ORG(address: tokens[index])
                    objectCode.append(UInt8(PC & 0x00FF))
                    objectCode.append(UInt8(PC >> 8))
                    index += 1
                } else if word == "EQU" && pass == 1 {
                    numberOfBytes = 0
                    symbolTable.updateValue(EQU(address: tokens[index]), forKey: tokens[index - 2])
                    index += 1
                } else if word == "DB" {
                    numberOfBytes = 0
                    let quotes = tokens[index].filter { $0 == "\"" }.count
                    var foundEndQuote = false
                    if quotes == 1 {
                        var textblock = tokens[index]
                        while !foundEndQuote || index >= tokens.count {
                            index += 1
                            textblock += " " + tokens[index]
                            if tokens[index].contains("\"") {
                                foundEndQuote = true
                            }
                        }
                        PC += DB(data: textblock)
                    } else {
                        PC += DB(data: tokens[index])
                    }
                    index += 1
                } else if let ins = singleByteInstructions[word] {
                    numberOfBytes = 1
                    addInstruction(UInt8(ins))
                    PC += 1
                } else if let ins = branchInstructions[word] {
                    addInstruction(UInt8(ins))
                    if pass == 1 {
                        _ = Branch(param: tokens[index], currentPC: PC)
                    } else {
                        tokens[index] = "$" + String(format: "%02X", Branch(param: tokens[index], currentPC: PC))
                    }
                    index += 1
                    PC += 2
                    numberOfBytes = 2
                } else if word == "ORA" {
                    numberOfBytes = InstructionSet(offset: 0x00, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "AND" {
                    numberOfBytes = InstructionSet(offset: 0x20, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "EOR" {
                    numberOfBytes = InstructionSet(offset: 0x40, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "ADC" {
                    numberOfBytes = InstructionSet(offset: 0x60, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "STA" {
                    numberOfBytes = InstructionSet(offset: 0x80, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "LDA" {
                    numberOfBytes = InstructionSet(offset: 0xA0, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "LDX" {
                    numberOfBytes = InstructionSetXY(offset: 0xA2, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "STX" {
                    numberOfBytes = InstructionSetXY2(offset: 0x86, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "LDY" {
                    numberOfBytes = InstructionSetXY(offset: 0xA0, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "STY" {
                    numberOfBytes = InstructionSetXY2(offset: 0x84, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "CMP" {
                    numberOfBytes = InstructionSet(offset: 0xC0, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "SBC" {
                    numberOfBytes = InstructionSet(offset: 0xE0, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "ASL" {
                    numberOfBytes = SHIFTandROTATES(offset: 0x00, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "ROL" {
                    numberOfBytes = SHIFTandROTATES(offset: 0x20, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "ROR" {
                    numberOfBytes = SHIFTandROTATES(offset: 0x60, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "LSR" {
                    numberOfBytes = SHIFTandROTATES(offset: 0x40, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "BIT" {
                    numberOfBytes = BIT(param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "CPY" {
                    numberOfBytes = CPXCPY(offset: 0xC0, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "CPX" {
                    numberOfBytes = CPXCPY(offset: 0xE0, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "DEC" {
                    numberOfBytes = INCDEC(offset: 0xC0, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "INC" {
                    numberOfBytes = INCDEC(offset: 0xE0, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "JSR" {
                    numberOfBytes = JumpSubroutine(param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "JMP" {
                    numberOfBytes = Jump(param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "TRB" {
                    numberOfBytes = TESTBITS(offset: 0x10, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                } else if word == "TSB" {
                    numberOfBytes = TESTBITS(offset: 0x00, param: tokens[index])
                    PC += numberOfBytes
                    index += 1
                }

                if pass == 2 {
                    switch numberOfBytes {
                    case 1:
                        displayObjectCode(text: "\t\t\t" + word + "\n")
                    case 2:
                        displayObjectCode(text: "\t\t" + word + "  " + tokens[index - 1] + "\n")
                    case 3:
                        displayObjectCode(text: "\t" + word + "  " + tokens[index - 1] + "\n")
                    case 0:
                        if objectCodeText.count >= 5 {
                            objectCodeText.removeLast()
                            objectCodeText.removeLast()
                            objectCodeText.removeLast()
                            objectCodeText.removeLast()
                            objectCodeText.removeLast()
                        }
                    default:
                        displayObjectCode(text: "\n")
                    }
                }
            }

            if pass == 1 {
                for (index, token) in tokens.enumerated() {
                    for label in symbolTable {
                        if token.starts(with: "#") {
                            if token == "#" + label.key {
                                tokens[index] = "#$" + String(format: "%04X", label.value)
                            }
                        } else if token == label.key {
                            tokens[index] = "$" + String(format: "%04X", label.value)
                        }
                    }
                }
            }

            if pass == 2 {
                displayObjectCode(text: "\n\n --- Symbol table --- \n\n")
                for label in symbolTable {
                    displayObjectCode(text: String(format: "%04X", label.value) + " = " + label.key + "\n")
                }
            }

            pass += 1
        }

        displayObjectCode(text: "\n\nAssembly complete.\n")

        let origin: UInt16? = objectCode.count >= 2
            ? UInt16(objectCode[0]) + (UInt16(objectCode[1]) << 8)
            : nil

        return AssemblyResult(origin: origin, objectCode: objectCode, listing: objectCodeText, symbolTable: symbolTable)
    }

    private func displayObjectCode(text: String) {
        objectCodeText += text
    }

    private func getNumber(input: String) -> UInt8? {
        var base = 10
        var n = input
        if input.starts(with: "$") {
            base = 16
            n = input.replacingOccurrences(of: "$", with: "")
        }
        if input.starts(with: "%") {
            base = 2
            n = input.replacingOccurrences(of: "%", with: "")
        }
        return UInt8(n, radix: base)
    }

    private func getAddress(input: String) -> UInt16? {
        var base = 10
        var n = input
        if input.starts(with: "$") {
            base = 16
            n = input.replacingOccurrences(of: "$", with: "")
        }
        if input.starts(with: "%") {
            base = 2
            n = input.replacingOccurrences(of: "%", with: "")
        }
        return UInt16(n, radix: base)
    }

    private enum AddressingModes {
        case Immediate
        case ZeroPage
        case ZeroPageX
        case ZeroPageY
        case Absolute
        case AbsoluteX
        case AbsoluteY
        case IndirectX
        case IndirectY
        case Indirect
        case Error
    }

    private func perror(error: String) {
        displayObjectCode(text: "\nError: " + error + "\n")
    }

    private func addInstruction(_ thecode: UInt8) {
        displayObjectCode(text: String(format: "%02X", thecode))
        objectCode.append(thecode)
    }

    private func addByte(_ thebyte: UInt8) {
        displayObjectCode(text: String(format: " %02X", thebyte))
        objectCode.append(thebyte)
    }

    private func addWord(_ theword: UInt16) {
        let lsb = UInt8(theword & 0x00FF)
        let msb = UInt8(theword >> 8)
        addByte(lsb)
        addByte(msb)
    }

    private func Branch(param: String, currentPC: UInt16) -> UInt8 {
        let rel = getAddress(input: param)
        if param.count == 5 && rel != nil {
            var r = Int16(rel!) - Int16(currentPC) - 2
            if r < 0 { r = r + 256 }
            r = r & 255
            addByte(UInt8(r))
            return UInt8(r)
        }
        if let rel {
            if rel < 256 {
                let r = UInt8(rel)
                addByte(r)
                return r
            }
            perror(error: "Relative branches must be within a single byte range.")
            return 0
        }
        addByte(0)
        return 0
    }

    private func Jump(param: String) -> UInt16 {
        let r = GetAddresingMode(token: param)
        if r.mode == .Error {
            addInstruction(0x00)
            addByte(0)
            addByte(0)
        }
        let lsb = UInt8(r.address & 0x00FF)
        let msb = UInt8(r.address >> 8)
        switch r.mode {
        case .Indirect:
            addInstruction(0x6C)
            addByte(lsb)
            addByte(msb)
        case .Absolute:
            addInstruction(0x4C)
            addByte(lsb)
            addByte(msb)
        case .Error:
            perror(error: param)
        default:
            perror(error: param)
        }
        return 3
    }

    private func JumpSubroutine(param: String) -> UInt16 {
        let rel = getAddress(input: param)
        if let rel {
            addInstruction(0x20)
            addWord(rel)
        } else {
            addInstruction(0x00)
            addWord(0)
        }
        return 3
    }

    private func InstructionSet(offset: UInt8, param: String) -> UInt16 {
        let r = GetAddresingMode(token: param)
        let lsb = UInt8(r.address & 0x00FF)
        let msb = UInt8(r.address >> 8)
        switch r.mode {
        case .Immediate:
            addInstruction(offset + 9)
            addByte(lsb)
            return 2
        case .ZeroPage:
            addInstruction(offset + 5)
            addByte(lsb)
            return 2
        case .ZeroPageX:
            addInstruction(offset + 0x15)
            addByte(lsb)
            return 2
        case .ZeroPageY:
            perror(error: "Unable to determine address mode or value " + param)
            return 2
        case .IndirectX:
            addInstruction(offset + 1)
            addByte(lsb)
            return 2
        case .IndirectY:
            addInstruction(offset + 0x11)
            addByte(lsb)
            return 2
        case .Indirect:
            addInstruction(offset + 0x12)
            addByte(lsb)
            return 2
        case .Absolute:
            addInstruction(offset + 0x0D)
            addByte(lsb)
            addByte(msb)
            return 3
        case .AbsoluteX:
            addInstruction(offset + 0x1D)
            addByte(lsb)
            addByte(msb)
            return 3
        case .AbsoluteY:
            addInstruction(offset + 0x19)
            addByte(lsb)
            addByte(msb)
            return 3
        case .Error:
            perror(error: "Unable to determine address mode or value " + param)
            return 2
        }
    }

    private func InstructionSetXY(offset: UInt8, param: String) -> UInt16 {
        let r = GetAddresingMode(token: param)
        let lsb = UInt8(r.address & 0x00FF)
        let msb = UInt8(r.address >> 8)
        switch r.mode {
        case .Immediate:
            addInstruction(offset + 0)
            addByte(lsb)
            return 2
        case .ZeroPage:
            addInstruction(offset + 4)
            addByte(lsb)
            return 2
        case .ZeroPageX:
            addInstruction(offset + 0x14)
            addByte(lsb)
            return 2
        case .ZeroPageY:
            addInstruction(offset + 0x14)
            addByte(lsb)
            return 2
        case .Absolute:
            addInstruction(offset + 0x0C)
            addByte(lsb)
            addByte(msb)
            return 3
        case .AbsoluteX:
            addInstruction(offset + 0x1C)
            addByte(lsb)
            addByte(msb)
            return 3
        case .AbsoluteY:
            addInstruction(offset + 0x1C)
            addByte(lsb)
            addByte(msb)
            return 3
        case .Error:
            perror(error: "Unable to determine address mode or value " + param)
            return 3
        default:
            perror(error: "Unable to determine address mode or value " + param)
            return 1
        }
    }

    private func InstructionSetXY2(offset: UInt8, param: String) -> UInt16 {
        let r = GetAddresingMode(token: param)
        let lsb = UInt8(r.address & 0x00FF)
        let msb = UInt8(r.address >> 8)
        switch r.mode {
        case .ZeroPage:
            addInstruction(offset + 0)
            addByte(lsb)
            return 2
        case .ZeroPageX:
            addInstruction(offset + 0x10)
            addByte(lsb)
            return 2
        case .AbsoluteY:
            addInstruction(offset + 0x10)
            addByte(lsb)
            return 2
        case .Absolute:
            addInstruction(offset + 0x08)
            addByte(lsb)
            addByte(msb)
            return 3
        case .Error:
            perror(error: "Unable to determine address mode or value " + param)
            return 3
        default:
            perror(error: "Unable to determine address mode or value " + param)
            return 1
        }
    }

    private func SHIFTandROTATES(offset: UInt8, param: String) -> UInt16 {
        if param == "A" {
            addInstruction(offset + 0x0A)
            return 1
        }
        let r = GetAddresingMode(token: param)
        let lsb = UInt8(r.address & 0x00FF)
        let msb = UInt8(r.address >> 8)
        switch r.mode {
        case .ZeroPage:
            addInstruction(offset + 0x06)
            addByte(lsb)
            return 2
        case .ZeroPageX:
            addInstruction(offset + 0x16)
            addByte(lsb)
            return 2
        case .Absolute:
            addInstruction(offset + 0x0E)
            addByte(lsb)
            addByte(msb)
            return 3
        case .AbsoluteX:
            addInstruction(offset + 0x1E)
            addByte(lsb)
            addByte(msb)
            return 3
        case .Error:
            perror(error: param)
            return 0
        default:
            perror(error: param)
            return 0
        }
    }

    private func BIT(param: String) -> UInt16 {
        let r = GetAddresingMode(token: param)
        let lsb = UInt8(r.address & 0x00FF)
        let msb = UInt8(r.address >> 8)
        switch r.mode {
        case .ZeroPage:
            addInstruction(0x24)
            addByte(lsb)
            return 2
        case .Absolute:
            addInstruction(0x2C)
            addByte(lsb)
            addByte(msb)
            return 3
        case .Immediate:
            addInstruction(0x89)
            addByte(lsb)
            return 2
        case .ZeroPageX:
            addInstruction(0x34)
            addByte(lsb)
            return 2
        case .AbsoluteX:
            addInstruction(0x3C)
            addByte(lsb)
            addByte(msb)
            return 3
        case .Error:
            perror(error: param)
            return 0
        default:
            perror(error: param)
            return 0
        }
    }

    private func TESTBITS(offset: UInt8, param: String) -> UInt16 {
        let r = GetAddresingMode(token: param)
        let lsb = UInt8(r.address & 0x00FF)
        let msb = UInt8(r.address >> 8)
        switch r.mode {
        case .ZeroPage:
            addInstruction(0x04)
            addByte(lsb)
            return 2
        case .Absolute:
            addInstruction(0x0C)
            addByte(lsb)
            addByte(msb)
            return 3
        case .Error:
            perror(error: param)
            return 0
        default:
            perror(error: param)
            return 0
        }
    }

    private func CPXCPY(offset: UInt8, param: String) -> UInt16 {
        let r = GetAddresingMode(token: param)
        let lsb = UInt8(r.address & 0x00FF)
        let msb = UInt8(r.address >> 8)
        switch r.mode {
        case .ZeroPage:
            addInstruction(offset + 0x04)
            addByte(lsb)
            return 2
        case .Absolute:
            addInstruction(offset + 0x0C)
            addByte(lsb)
            addByte(msb)
            return 3
        case .Immediate:
            addInstruction(offset)
            addByte(lsb)
            return 2
        case .Error:
            perror(error: param)
            return 0
        default:
            perror(error: param)
            return 0
        }
    }

    private func INCDEC(offset: UInt8, param: String) -> UInt16 {
        if param == "A" && offset == 0xC0 {
            addInstruction(0x3A) // 65C02: DEC A
            return 1
        }
        if param == "A" && offset == 0xE0 {
            addInstruction(0x1A) // 65C02: INC A
            return 1
        }
        let r = GetAddresingMode(token: param)
        let lsb = UInt8(r.address & 0x00FF)
        let msb = UInt8(r.address >> 8)
        switch r.mode {
        case .ZeroPage:
            addInstruction(offset + 0x06)
            addByte(lsb)
            return 2
        case .ZeroPageX:
            addInstruction(offset + 0x16)
            addByte(lsb)
            return 2
        case .Absolute:
            addInstruction(offset + 0x0E)
            addByte(lsb)
            addByte(msb)
            return 3
        case .AbsoluteX:
            addInstruction(offset + 0x1E)
            addByte(lsb)
            addByte(msb)
            return 3
        case .Error:
            perror(error: param)
            return 0
        default:
            perror(error: param)
            return 0
        }
    }

    private func GetAddresingMode(token: String) -> (address: UInt16, mode: AddressingModes) {
        if token.starts(with: "#") {
            let n = getNumber(input: token.replacingOccurrences(of: "#", with: ""))
            if let n {
                return (UInt16(n), .Immediate)
            }
            perror(error: token)
            return (0, .Error)
        }

        if token.contains("(") && !token.contains("X") && !token.contains("Y") {
            var newToken = token.replacingOccurrences(of: "(", with: "")
            newToken = newToken.replacingOccurrences(of: ")", with: "")
            newToken = newToken.replacingOccurrences(of: "X", with: "")
            newToken = newToken.replacingOccurrences(of: "Y", with: "")
            if let n = getAddress(input: newToken) {
                return (n, .Indirect)
            }
            perror(error: token)
            return (0, .Error)
        }

        if token.contains("(") && token.contains("X") {
            var newToken = token.replacingOccurrences(of: "(", with: "")
            newToken = newToken.replacingOccurrences(of: ")", with: "")
            newToken = newToken.replacingOccurrences(of: "X", with: "")
            newToken = newToken.replacingOccurrences(of: ",", with: "")
            if let n = getAddress(input: newToken) {
                return (n, .IndirectX)
            }
            perror(error: token)
            return (0, .Error)
        }

        if token.contains("(") && token.contains("Y") {
            var newToken = token.replacingOccurrences(of: "(", with: "")
            newToken = newToken.replacingOccurrences(of: ")", with: "")
            newToken = newToken.replacingOccurrences(of: "Y", with: "")
            newToken = newToken.replacingOccurrences(of: ",", with: "")
            if let n = getAddress(input: newToken) {
                return (n, .IndirectY)
            }
            perror(error: token)
            return (0, .Error)
        }

        if token.contains(",Y") {
            if let n = getAddress(input: token.replacingOccurrences(of: ",Y", with: "")) {
                return (n, .AbsoluteY)
            }
            perror(error: token)
            return (0, .Error)
        }

        if !token.contains(",X") {
            if let n = getAddress(input: token) {
                if n < 256 {
                    return (n, .ZeroPage)
                }
                return (n, .Absolute)
            }
            perror(error: token)
            return (0, .Error)
        }

        if token.contains(",X") {
            if let n = getAddress(input: token.replacingOccurrences(of: ",X", with: "")) {
                if n < 256 {
                    return (n, .ZeroPageX)
                }
                return (n, .AbsoluteX)
            }
            perror(error: token)
            return (0, .Error)
        }

        return (0, .Error)
    }

    private func ORG(address: String) -> UInt16 {
        guard let num = getAddress(input: address) else {
            perror(error: "Unable to parse address value: " + address)
            return 0
        }
        return num
    }

    private func EQU(address: String) -> UInt16 {
        guard let num = getAddress(input: address) else {
            perror(error: "Unable to assign value to label " + address)
            return 0
        }
        return num
    }

    private func DB(data: String) -> UInt16 {
        var counter: UInt16 = 0
        if data.contains("\"") {
            let newdata = data.replacingOccurrences(of: "\"", with: "")
            for eachChar in newdata {
                let c = (eachChar as Character).asciiValue!
                addByte(c)
                counter += 1
            }
            return counter
        }
        let bytes = data.components(separatedBy: ",")
        for byte in bytes {
            guard let num = getNumber(input: byte) else {
                perror(error: "Number parse error or extra spaces between values: " + data)
                return 0
            }
            addByte(num)
            counter += 1
        }
        return counter
    }
}
