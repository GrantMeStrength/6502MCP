//
//  Memory.swift
//  VirtualKim
//
//  Created by John Kennedy on 1/8/21.
//
// Model the memory of the computers, including making memory read-only, loading some initial code,
// and wrapping addresses in a certain range (like the KIM-1 does)
// Also contains sample apps that are loaded into memory on demand.
// Note - currently only the location of the KIM ROM produces "write errors"
// but is ignored for Apple. In practice, blocking access to memory for a ROMs doesn't make any difference
// to how things work, but it was useful when debugging.

import Foundation

struct Memory_Cell {
    var cell : UInt8
    var ROM : Bool
}

var MEMORY : [Memory_Cell] = []
private var MEMORY_TOP : UInt16 = 0xFFFF // 0x5fff // 4kb + extra 16Kb at $2000
private let MEMORY_FULL : UInt16 = 0xffff // 4kb + extra 16Kb at $2000

private var clock_divide_ratio = 1
private var clock_counter : Int = 0
private var clock_interrupt_active = false
private var clock_tick_counter = 0
private var clock_went_under_zero = false
private var previous_clock_divide_ratio = 1

private var APPLE_MODE = false
private var apple_output_char_waiting = false
private var apple_output_char : UInt8 = 0
private var apple_key_ready = false
private var apple_key_value : UInt8 = 0

// Enhanced RIOT chip emulation
private var riot6532: RIOT6532? = nil
private var useEnhancedRIOT = true

class memory_64Kb
{
    
    init() {
        print("Memory init - should happen once only")
        // Initialize RIOT chip for KIM-1 mode
        riot6532 = RIOT6532(baseAddress: 0x1740)
    }
    
    func setMemoryLimit(limit: UInt16)
    {
        MEMORY_TOP = limit
    }
    
    func MaskMemory(_ address : UInt16) -> UInt16
    {
        let add = address & 0xffff
        return add
    }
    
    func AppleActive(state : Bool)
    {
        APPLE_MODE = state
    }
    
    func AppleReady() -> Bool
    {
        return apple_key_ready
    }
    
    func AppleKeyState(state : Bool, key : UInt8)
    {
        apple_key_ready = state
        apple_key_value = key
    }
    
    func getAppleOutputState() -> (Bool, UInt8)
    {
        let a = apple_output_char_waiting
        apple_output_char_waiting = false
        return (a, apple_output_char)
    }
    
    func ReadAddress (address : UInt16) -> UInt8
    {
        // Enhanced RIOT emulation for KIM-1
        if !APPLE_MODE && useEnhancedRIOT {
            if let riot = riot6532, riot.isRIOTAddress(address) {
                return riot.readRegister(address: address)
            }
        }
        
        // APPLE-1 keyboard and display I/O
        if APPLE_MODE {
            switch address {
            case 0xD010:
                // Convert lowercase to uppercase
                if apple_key_value >= 0x61 && apple_key_value <= 0x7A {
                    apple_key_value = apple_key_value & 0x5F
                }
                // Convert line feed to carriage return
                if apple_key_value == 10 {
                    apple_key_value = 13
                }
                apple_key_ready = false
                return apple_key_value | 0x80

            case 0xD011:
                return apple_key_ready ? 0x80 : 0x00

            case 0xD012, 0xD0F2:
                return 0x00 // Keyboard status: 0 means ready

            default:
                break
            }
        }

        // KIM-1: Return 0xFF for addresses beyond memory limit
        if address > MEMORY_TOP && !APPLE_MODE {
            return 0xFF
        }
        
        let hAddr = address >> 8
        let lAddr = address & 0x00ff
        
        // KIM-1 Status for break key at 0x1740
        // MS BASIC source expects to check this, but the loaded binary doesn't
        if address == 0x1740 {
            return MEMORY[Int(MaskMemory(address))].cell
        }
        
        // Timer counter reads (without side effects)
        if address == 0x1706 || address == 0x170E {
            return UInt8(clock_counter)
        }

        // Timer status register - reading clears the underflow flag
        if address == 0x1707 {
            let status: UInt8 = clock_went_under_zero ? 0x80 : 0x00
            clock_went_under_zero = false
            MEMORY[Int(MaskMemory(0x1707))].cell = 0x00
            return status
        }

        // Random number generator for certain RIOT addresses (excluding timer block)
        if (hAddr == 0x17) &&
           !(lAddr >= 0x04 && lAddr <= 0x0F) &&
           (lAddr & 1 == 0) && (lAddr & 4 == 4) && (lAddr & 0x80 == 0) {
            return UInt8.random(in: 0...255)
        }
        
        
        return MEMORY[Int(MaskMemory(address))].cell
    }
    
    func WriteAddress  (address : UInt16, value : UInt8)
    {
        // Enhanced RIOT emulation for KIM-1
        if !APPLE_MODE && useEnhancedRIOT {
            if let riot = riot6532, riot.isRIOTAddress(address) {
                riot.writeRegister(address: address, value: value)
                return
            }
        }
        
        // KIM-1: Ignore writes beyond memory limit
        if address > MEMORY_TOP && !APPLE_MODE {
            return
        }

        // APPLE-1 keyboard and display I/O
        if APPLE_MODE {
            switch address {
            case 0xD011:
                apple_key_ready = false
                return
            case 0xD012:
                apple_output_char_waiting = true
                apple_output_char = value & 0x7F
            default:
                break
            }
        }
        
        // KIM-1 Legacy Timer Configuration
        if address >= 0x1704 && address <= 0x170F {
            let dividers = [1, 8, 64, 1024]
            let offset = Int(address & 0x03)
            let interruptEnable = (address & 0x08) != 0

            clock_counter = Int(value)
            clock_divide_ratio = dividers[offset]
            previous_clock_divide_ratio = dividers[offset]
            clock_interrupt_active = interruptEnable
            clock_went_under_zero = false
            return
        }

        // Regular memory write (respects ROM protection)
        if !MEMORY[Int(MaskMemory(address))].ROM {
            MEMORY[Int(MaskMemory(address))].cell = value
        }
    }
    
    func RIOT_Timer_Click(cycles: Int = 1) {
        // Use enhanced RIOT timer if available
        if !APPLE_MODE && useEnhancedRIOT {
            riot6532?.timerTick(cycles: cycles)
            return
        }

        // Legacy timer implementation
        clock_tick_counter += cycles
        while clock_tick_counter >= clock_divide_ratio {
            clock_tick_counter -= clock_divide_ratio
            clock_counter -= 1

            if clock_counter < 0 {
                clock_went_under_zero = true
                clock_divide_ratio = 1
                MEMORY[Int(MaskMemory(0x1707))].cell = 0x80
                clock_counter = 0xFF
            }
        }
    }
    
    func SaveToPapertape(start : Int, length : Int) -> String
    {
        return SaveFile(startAddress: start, userdataLength: length)
    }
    
    func InitMemory(SoftwareToLoad : String) -> [UInt8]
    {
        // Create RAM and Load any ROMS
        // For now, set all memory to be RAM reset to 0
        // Currently assumes software has a unique name i.e. no APPLE and KIM apps have the same name
        // Software is a mish-mash of binary files in the app bundle and built-in arrays of bytes
        // Some files will return current register settings so they can launch at run.
        
        print("Memory: Initializing memory and preparing to load \(SoftwareToLoad)..", terminator:"")
        
        MEMORY.removeAll()
        MEMORY.reserveCapacity(Int(MEMORY_FULL) + 1)
        if MEMORY.isEmpty {
            MEMORY = [Memory_Cell](repeatElement(Memory_Cell(cell: 0, ROM: false), count: Int(MEMORY_FULL) + 1))
        }
        
        // Initialize break flag to 0x80 (no break) for MS BASIC
        MEMORY[0x1740].cell = 0x80
        
        if !APPLE_MODE
        {
            injectROM() // The Monitor ROM for KIM
            let r = LoadSoftware(name : SoftwareToLoad) // Any extra apps
            
            // Set the reset interrupt vectors to help the user
            
            
            // NMI - so SST/ST works
            // Shouldn't this also include 0xFFxx addresses as this is a > minimal RAM system?
            
            MEMORY[0x17FA].cell = 0x00
            MEMORY[0x17FB].cell = 0x1C
            
            MEMORY[0xFFFA].cell = 0x00
            MEMORY[0xFFFB].cell = 0x1C
            
            // RST
            MEMORY[0x17FC].cell = 0x22
            MEMORY[0x17FD].cell = 0x1C
            
            MEMORY[0xFFFC].cell = 0x22
            MEMORY[0xFFFD].cell = 0x1C
            
            // IRQ - so BRK works
            MEMORY[0x17FE].cell = 0x00
            MEMORY[0x17FF].cell = 0x1C
            
            MEMORY[0xFFFE].cell = 0x00
            MEMORY[0xFFFF].cell = 0x1C
            
            return r
        }
        else
        {
            // Load WozMon, BASIC and Krusader into FF00, F000 and E000
            LoadAppInBinaryForm(filename: "Apple1Rom", type: "BIN", address: 0xe000)
    
            // Load in the app
            return LoadSoftware(name : SoftwareToLoad) // Any extra apps
        }
    }
    
    // MARK: - Enhanced RIOT Interface Methods
    
    func setRIOTPortAInput(_ value: UInt8) {
        if !APPLE_MODE && useEnhancedRIOT {
            riot6532?.setPortAInput(value)
        }
    }

    // LED write callback for persistence buffer
    func setLEDWriteCallback(_ callback: ((UInt8, UInt8) -> Void)?) {
        riot6532?.onLEDWrite = callback
    }
    
    func setRIOTKeypadInput(_ keycode: UInt8) {
        if !APPLE_MODE && useEnhancedRIOT {
            riot6532?.setKeypadInput(keycode)
        }
    }

    func setRIOTKeypadPressed(row: Int, col: Int, pressed: Bool) {
        if !APPLE_MODE && useEnhancedRIOT {
            riot6532?.setKeypadPressed(row: row, col: col, pressed: pressed)
        }
    }
    
    func getRIOTDisplayOutput() -> (segments: UInt8, digit: UInt8) {
        if !APPLE_MODE && useEnhancedRIOT {
            return riot6532?.getDisplayOutput() ?? (0x00, 0x00)
        }
        return (0x00, 0x00)
    }

    func getRIOTDisplayLatchOutput() -> (segments: UInt8, digit: UInt8, portADirection: UInt8, portBDirection: UInt8) {
        if !APPLE_MODE && useEnhancedRIOT {
            return riot6532?.getDisplayLatchOutput() ?? (0x00, 0x00, 0x00, 0x00)
        }
        return (0x00, 0x00, 0x00, 0x00)
    }
    
    func hasRIOTInterrupt() -> Bool {
        if !APPLE_MODE && useEnhancedRIOT {
            return riot6532?.hasInterrupt() ?? false
        }
        return false
    }
    
    func clearRIOTInterrupts() {
        if !APPLE_MODE && useEnhancedRIOT {
            riot6532?.clearInterrupts()
        }
    }
    
    func getRIOTRegisterDump() -> [String: Any] {
        if !APPLE_MODE && useEnhancedRIOT {
            return riot6532?.getRegisterDump() ?? [:]
        }
        return [:]
    }
    
    func setEnhancedRIOTMode(_ enabled: Bool) {
        useEnhancedRIOT = enabled
        if enabled && riot6532 == nil {
            riot6532 = RIOT6532(baseAddress: 0x1740)
        }
    }
    
    func resetRIOT() {
        riot6532?.reset()
    }

    func isEnhancedRIOTEnabled() -> Bool {
        return !APPLE_MODE && useEnhancedRIOT
    }
    
    // Check if game has done direct LED writes (bypassing SCANDS)
    func hasDirectLEDWrites() -> Bool {
        return riot6532?.hasDirectLEDWrites ?? false
    }
    
    // Mark that direct LED writes have occurred (called from writePortA in user code context)
    func markDirectLEDWrite() {
        riot6532?.markDirectWrite()
    }
}
