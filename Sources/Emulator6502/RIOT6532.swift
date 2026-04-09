//
//  RIOT6532.swift
//  VirtualKim
//
//  Enhanced MOS 6532 RIOT Chip Emulation
//  Provides accurate emulation of RAM, I/O Ports, and Timer functionality
//

import Foundation

class RIOT6532 {
    
    // 128 bytes of internal RAM
    private var riotRAM: [UInt8] = Array(repeating: 0, count: 128)
    
    // I/O Port Registers
    private var portAData: UInt8 = 0x00       // PRA - Port A Data Register
    private var portADirection: UInt8 = 0x00   // DDRA - Port A Data Direction Register
    private var portBData: UInt8 = 0x00       // PRB - Port B Data Register  
    private var portBDirection: UInt8 = 0x00   // DDRB - Port B Data Direction Register
    
    // External I/O state (what's actually connected to the ports)
    private var portAInput: UInt8 = 0xFF      // External input to Port A
    private var portBInput: UInt8 = 0xFF      // External input to Port B
    
    // Timer Registers
    private var timerCounter: UInt8 = 0xFF
    private var timerDivider: Int = 1
    private var timerTickCount: Int = 0
    private var timerInterruptEnable: Bool = false
    private var timerUnderflowFlag: Bool = false
    
    // PA7 Interrupt Control
    private var pa7InterruptEnable: Bool = false
    private var pa7EdgeDetect: Bool = false    // false = negative edge, true = positive edge
    private var pa7LastState: Bool = false
    private var pa7InterruptFlag: Bool = false
    
    // Base address for this RIOT chip (typically $1740 for KIM-1)
    private let baseAddress: UInt16
    
    // LED write callback for capturing multiplexed display writes
    var onLEDWrite: ((UInt8, UInt8) -> Void)?  // (segmentData, digitSelector)
    
    // Track whether game does direct LED writes (bypassing SCANDS ROM routine)
    // This helps determine whether to use hardware display path vs SCANDS interception
    private(set) var hasDirectLEDWrites: Bool = false
    
    init(baseAddress: UInt16 = 0x1740) {
        self.baseAddress = baseAddress
        reset()
    }

    private func normalizedAddress(_ address: UInt16) -> UInt16 {
        // KIM-1 mirrors RIOT registers at 0x1700-0x173F
        if address >= 0x1700 && address <= 0x173F {
            return address + 0x40
        }
        return address
    }
    
    func reset() {
        // Reset all registers to power-on state
        riotRAM = Array(repeating: 0, count: 128)
        portAData = 0x00
        portADirection = 0x00
        portBData = 0x00
        portBDirection = 0x00
        portAInput = 0xFF
        portBInput = 0xFF
        
        timerCounter = 0xFF
        timerDivider = 1
        timerTickCount = 0
        timerInterruptEnable = false
        timerUnderflowFlag = false
        
        pa7InterruptEnable = false
        pa7EdgeDetect = false
        pa7LastState = false
        pa7InterruptFlag = false
        
        hasDirectLEDWrites = false
    }
    
    // MARK: - Memory Access Methods
    
    func isRIOTAddress(_ address: UInt16) -> Bool {
        // KIM-1 has two 6530 RRIOTs:
        //   6530-002: I/O at $1740-$177F, RAM at $17C0-$17FF
        //   6530-003: I/O at $1700-$173F, RAM at $1780-$17BF
        //
        // We emulate I/O registers at $1740-$177F (with $1700-$173F mirrored).
        // $1780-$17BF and $17C0-$17FF are on-chip RAM on the real hardware;
        // they work fine as regular memory in the emulator, so we must NOT
        // intercept them here. Programs like KIM Venture store code there.
        
        let normalized = normalizedAddress(address)
        return normalized >= baseAddress && normalized <= (baseAddress + 0x3F)
    }
    
    func readRegister(address: UInt16) -> UInt8 {
        guard isRIOTAddress(address) else { return 0xFF }
        
        let offset = normalizedAddress(address) - baseAddress
        
        switch offset {
        case 0x00: // PRA - Port A Data Register
            return readPortA()
            
        case 0x01: // DDRA - Port A Data Direction Register  
            return portADirection
            
        case 0x02: // PRB - Port B Data Register
            return readPortB()
            
        case 0x03: // DDRB - Port B Data Direction Register
            return portBDirection
            
        case 0x04...0x07: // Timer read with different modes
            return readTimer(offset: offset)
            
        case 0x0C...0x0F: // Timer read with interrupt enable
            return readTimer(offset: offset)
            
        case 0x80...0xFF: // RAM area
            let ramIndex = Int(offset - 0x80)
            return riotRAM[ramIndex]
            
        default:
            return 0xFF
        }
    }
    
    func writeRegister(address: UInt16, value: UInt8) {
        guard isRIOTAddress(address) else { return }
        
        let offset = normalizedAddress(address) - baseAddress
        
        switch offset {
        case 0x00: // PRA - Port A Data Register
            writePortA(value)
            
        case 0x01: // DDRA - Port A Data Direction Register
            portADirection = value
            
        case 0x02: // PRB - Port B Data Register  
            writePortB(value)
            
        case 0x03: // DDRB - Port B Data Direction Register
            portBDirection = value
            
        case 0x04...0x07: // Timer write with different dividers, interrupt disabled
            writeTimer(offset: offset, value: value, interruptEnable: false)
            
        case 0x0C...0x0F: // Timer write with different dividers, interrupt enabled
            writeTimer(offset: offset, value: value, interruptEnable: true)
            
        case 0x80...0xFF: // RAM area
            let ramIndex = Int(offset - 0x80)
            riotRAM[ramIndex] = value
            
        default:
            break
        }
    }
    
    // MARK: - Port A Operations
    
    // Latched display state for LED polling
    private var displaySegmentLatch: UInt8 = 0x00
    private var displayDigitLatch: UInt8 = 0x00

    private var pressedKeyRow: Int? = nil
    private var pressedKeyCol: Int? = nil
    
    private func readPortA() -> UInt8 {
        // Output bits return data register, input bits return external input
        let outputBits = portAData & portADirection
        var inputBits = portAInput & ~portADirection
        if let row = pressedKeyRow, let col = pressedKeyCol {
            let colMask = UInt8(1 << col)
            let rowMask = UInt8(1 << (row + 4))
            if (portADirection & colMask) != 0 {
                let columnLow = (portAData & colMask) == 0
                if columnLow {
                    inputBits &= ~rowMask
                }
            }
        }
        let result = outputBits | inputBits

        // Check PA7 for interrupt edge detection
        let pa7State = (result & 0x80) != 0
        if pa7InterruptEnable {
            let risingEdge = !pa7LastState && pa7State
            let fallingEdge = pa7LastState && !pa7State
            if (pa7EdgeDetect && risingEdge) || (!pa7EdgeDetect && fallingEdge) {
                pa7InterruptFlag = true
            }
        }
        pa7LastState = pa7State

        return result
    }
    
    private func writePortA(_ value: UInt8) {
        portAData = value
        displaySegmentLatch = value

        // Fire LED callback when non-blank segments are written,
        // paired with the current Port B (digit selector) value.
        let segments = value & 0x7F
        if segments != 0x00, let callback = onLEDWrite {
            callback(value, portBData)
        }
    }
    
    // Mark that direct LED writes have occurred (game bypasses SCANDS)
    func markDirectWrite() {
        hasDirectLEDWrites = true
    }
    
    // MARK: - Port B Operations
    
    private func readPortB() -> UInt8 {
        // Output bits return data register, input bits return external input
        let outputBits = portBData & portBDirection
        let inputBits = portBInput & ~portBDirection
        return outputBits | inputBits
    }
    
    private func writePortB(_ value: UInt8) {
        portBData = value
        displayDigitLatch = value
    }
    
    // MARK: - Timer Operations
    
    private func readTimer(offset: UInt16) -> UInt8 {
        // Reading timer status/value
        if offset == 0x07 || offset == 0x0F {
            // Status register - bit 7 indicates timer underflow
            let status: UInt8 = timerUnderflowFlag ? 0x80 : 0x00
            timerUnderflowFlag = false // Clear flag on read
            return status
        } else {
            // Return current timer value
            return timerCounter
        }
    }
    
    private func writeTimer(offset: UInt16, value: UInt8, interruptEnable: Bool) {
        timerCounter = value
        timerTickCount = 0
        timerUnderflowFlag = false
        timerInterruptEnable = interruptEnable
        
        // Set clock divider based on address
        switch offset & 0x03 {
        case 0x00: timerDivider = 1     // Clock ÷ 1
        case 0x01: timerDivider = 8     // Clock ÷ 8  
        case 0x02: timerDivider = 64    // Clock ÷ 64
        case 0x03: timerDivider = 1024  // Clock ÷ 1024
        default: break
        }
    }
    
    func timerTick(cycles: Int = 1) {
        timerTickCount += cycles
        
        while timerTickCount >= timerDivider {
            timerTickCount -= timerDivider
            
            if timerCounter > 0 {
                timerCounter -= 1
            } else {
                // Timer underflow
                timerUnderflowFlag = true
                timerCounter = 0xFF // Wrap to 255
            }
        }
    }
    
    // MARK: - Interrupt Status
    
    func hasInterrupt() -> Bool {
        return (timerInterruptEnable && timerUnderflowFlag) || 
               (pa7InterruptEnable && pa7InterruptFlag)
    }
    
    func clearInterrupts() {
        timerUnderflowFlag = false
        pa7InterruptFlag = false
    }
    
    // MARK: - External I/O Interface
    
    func setPortAInput(_ value: UInt8) {
        portAInput = value
    }
    
    func setPortBInput(_ value: UInt8) {
        portBInput = value
    }
    
    func getPortAOutput() -> UInt8 {
        return portAData & portADirection
    }
    
    func getPortBOutput() -> UInt8 {
        return portBData & portBDirection
    }
    
    // MARK: - KIM-1 Specific Helper Methods
    
    func setKeypadInput(_ keycode: UInt8) {
        // KIM-1 keypad is connected to Port A
        // Bits 0-3 are keypad columns, bits 4-6 are keypad rows
        setPortAInput(keycode)
    }

    func setKeypadPressed(row: Int, col: Int, pressed: Bool) {
        if pressed {
            pressedKeyRow = row
            pressedKeyCol = col
        } else {
            pressedKeyRow = nil
            pressedKeyCol = nil
        }
    }
    
    func getDisplayOutput() -> (segments: UInt8, digit: UInt8) {
        // KIM-1 7-segment display control
        // Port A controls segments, Port B controls digit selection
        let segments = getPortAOutput()
        let digits = getPortBOutput()
        return (segments, digits)
    }

    func getDisplayLatchOutput() -> (segments: UInt8, digit: UInt8, portADirection: UInt8, portBDirection: UInt8) {
        return (displaySegmentLatch, displayDigitLatch, portADirection, portBDirection)
    }
    
    // MARK: - Debug and Testing Methods
    
    func getRegisterDump() -> [String: Any] {
        return [
            "portAData": String(format: "$%02X", portAData),
            "portADirection": String(format: "$%02X", portADirection),
            "portBData": String(format: "$%02X", portBData),
            "portBDirection": String(format: "$%02X", portBDirection),
            "timerCounter": String(format: "$%02X", timerCounter),
            "timerDivider": timerDivider,
            "timerInterruptEnable": timerInterruptEnable,
            "timerUnderflowFlag": timerUnderflowFlag,
            "pa7InterruptEnable": pa7InterruptEnable,
            "pa7InterruptFlag": pa7InterruptFlag
        ]
    }
    
    func getRam() -> [UInt8] {
        return riotRAM
    }
    
    func setRam(data: [UInt8]) {
        let copyLength = min(data.count, riotRAM.count)
        riotRAM.replaceSubrange(0..<copyLength, with: data.prefix(copyLength))
    }
}
