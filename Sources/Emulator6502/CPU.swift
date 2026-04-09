//
//  CPU.swift
//  VirtualKim
//
//  Created by John Kennedy on 1/8/21.
//
// 6502 implementation with as few KIM-1 or iOS specific features as possible
//
// prn() function gathers debug information for optional output.
//
// Note: This 6502 now uses a cycle lookup table to tick the RIOT timer accurately.
// Variable cycle timing for page boundary crosses and branch taken/not-taken is not
// yet implemented, but the base cycle counts are accurate for most instructions.
//


import Foundation
import Combine


// Registers and flags
private var PC : UInt16 = 0x1c22
private var SP : UInt8 = 0xfe // of fd?
private var A : UInt8 = 0
private var X : UInt8 = 0
private var Y : UInt8 = 0
private var CARRY_FLAG : Bool = false
private var ZERO_FLAG : Bool = false
private var OVERFLOW_FLAG : Bool = false
private var INTERRUPT_DISABLE : Bool = false
private var DECIMAL_MODE : Bool = false
private var NEGATIVE_FLAG : Bool = false
private var BREAK_FLAG : Bool = false
private var UNUSED_FLAG : Bool = true
private var RUNTIME_DEBUG_MESSAGES : Bool = false

private var DEFAULT_SP : UInt8 = 0xFE

private var kim_keyActive : Bool = false           // Used when providing KIM-1 keyboard support
private var kim_keyNumber : UInt8 = 0xff
private var useHardwareDisplay: Bool = false

private var memory = memory_64Kb()                  // Implemention of memory map, including RAM and ROM

private var dataToDisplay = false                   // Used by the SwiftUI wrapper
private var running = false                         // to know if we're running and if something needs displayed on the "LEDs"

private var statusmessage : String = "-"        // Debug information is built up per instruction in this string

var breakpoint = false

private var texttodisplay : String = ""

private var TYPING_ACTIVE = false               // Used when forcing a listing into memory

private var APPLE_ACTIVE = false                // Running in Apple 1 mode rather than KIM-1 mode (different ROM, different serial IO)

// Track cycles for the last executed instruction (for accurate timer emulation)
private var lastInstructionCycles: Int = 0

// 6502 Instruction Cycle Table - based on standard 6502 timing
// Note: Some instructions have +1 cycle for page boundary crossing (not tracked yet)
// Note: Branch instructions have +1 if taken, +2 if page crossed (not tracked yet)
private let instructionCycles: [UInt8: Int] = [
    0x00: 7, 0x01: 6, 0x02: 2, 0x03: 8, 0x04: 3, 0x05: 3, 0x06: 5, 0x07: 5,
    0x08: 3, 0x09: 2, 0x0A: 2, 0x0B: 2, 0x0C: 4, 0x0D: 4, 0x0E: 6, 0x0F: 6,
    0x10: 2, 0x11: 5, 0x12: 2, 0x13: 8, 0x14: 4, 0x15: 4, 0x16: 6, 0x17: 6,
    0x18: 2, 0x19: 4, 0x1A: 2, 0x1B: 7, 0x1C: 4, 0x1D: 4, 0x1E: 7, 0x1F: 7,
    0x20: 6, 0x21: 6, 0x22: 2, 0x23: 8, 0x24: 3, 0x25: 3, 0x26: 5, 0x27: 5,
    0x28: 4, 0x29: 2, 0x2A: 2, 0x2B: 2, 0x2C: 4, 0x2D: 4, 0x2E: 6, 0x2F: 6,
    0x30: 2, 0x31: 5, 0x32: 2, 0x33: 8, 0x34: 4, 0x35: 4, 0x36: 6, 0x37: 6,
    0x38: 2, 0x39: 4, 0x3A: 2, 0x3B: 7, 0x3C: 4, 0x3D: 4, 0x3E: 7, 0x3F: 7,
    0x40: 6, 0x41: 6, 0x42: 2, 0x43: 8, 0x44: 3, 0x45: 3, 0x46: 5, 0x47: 5,
    0x48: 3, 0x49: 2, 0x4A: 2, 0x4B: 2, 0x4C: 3, 0x4D: 4, 0x4E: 6, 0x4F: 6,
    0x50: 2, 0x51: 5, 0x52: 2, 0x53: 8, 0x54: 4, 0x55: 4, 0x56: 6, 0x57: 6,
    0x58: 2, 0x59: 4, 0x5A: 2, 0x5B: 7, 0x5C: 4, 0x5D: 4, 0x5E: 7, 0x5F: 7,
    0x60: 6, 0x61: 6, 0x62: 2, 0x63: 8, 0x64: 3, 0x65: 3, 0x66: 5, 0x67: 5,
    0x68: 4, 0x69: 2, 0x6A: 2, 0x6B: 2, 0x6C: 5, 0x6D: 4, 0x6E: 6, 0x6F: 6,
    0x70: 2, 0x71: 5, 0x72: 2, 0x73: 8, 0x74: 4, 0x75: 4, 0x76: 6, 0x77: 6,
    0x78: 2, 0x79: 4, 0x7A: 2, 0x7B: 7, 0x7C: 4, 0x7D: 4, 0x7E: 7, 0x7F: 7,
    0x80: 2, 0x81: 6, 0x82: 2, 0x83: 6, 0x84: 3, 0x85: 3, 0x86: 3, 0x87: 3,
    0x88: 2, 0x89: 2, 0x8A: 2, 0x8B: 2, 0x8C: 4, 0x8D: 4, 0x8E: 4, 0x8F: 4,
    0x90: 2, 0x91: 6, 0x92: 2, 0x93: 6, 0x94: 4, 0x95: 4, 0x96: 4, 0x97: 4,
    0x98: 2, 0x99: 5, 0x9A: 2, 0x9B: 5, 0x9C: 5, 0x9D: 5, 0x9E: 5, 0x9F: 5,
    0xA0: 2, 0xA1: 6, 0xA2: 2, 0xA3: 6, 0xA4: 3, 0xA5: 3, 0xA6: 3, 0xA7: 3,
    0xA8: 2, 0xA9: 2, 0xAA: 2, 0xAB: 2, 0xAC: 4, 0xAD: 4, 0xAE: 4, 0xAF: 4,
    0xB0: 2, 0xB1: 5, 0xB2: 2, 0xB3: 5, 0xB4: 4, 0xB5: 4, 0xB6: 4, 0xB7: 4,
    0xB8: 2, 0xB9: 4, 0xBA: 2, 0xBB: 4, 0xBC: 4, 0xBD: 4, 0xBE: 4, 0xBF: 4,
    0xC0: 2, 0xC1: 6, 0xC2: 2, 0xC3: 8, 0xC4: 3, 0xC5: 3, 0xC6: 5, 0xC7: 5,
    0xC8: 2, 0xC9: 2, 0xCA: 2, 0xCB: 2, 0xCC: 4, 0xCD: 4, 0xCE: 6, 0xCF: 6,
    0xD0: 2, 0xD1: 5, 0xD2: 2, 0xD3: 8, 0xD4: 4, 0xD5: 4, 0xD6: 6, 0xD7: 6,
    0xD8: 2, 0xD9: 4, 0xDA: 2, 0xDB: 7, 0xDC: 4, 0xDD: 4, 0xDE: 7, 0xDF: 7,
    0xE0: 2, 0xE1: 6, 0xE2: 2, 0xE3: 8, 0xE4: 3, 0xE5: 3, 0xE6: 5, 0xE7: 5,
    0xE8: 2, 0xE9: 2, 0xEA: 2, 0xEB: 2, 0xEC: 4, 0xED: 4, 0xEE: 6, 0xEF: 6,
    0xF0: 2, 0xF1: 5, 0xF2: 2, 0xF3: 8, 0xF4: 4, 0xF5: 4, 0xF6: 6, 0xF7: 6,
    0xF8: 2, 0xF9: 4, 0xFA: 2, 0xFB: 7, 0xFC: 4, 0xFD: 4, 0xFE: 7, 0xFF: 7
]

public final class CPU: ObservableObject {
    
    //    Addressing modes explained: http://www.emulator101.com/6502-addressing-modes.html
    
    //    Interrupt vectors on the KIM-1 are mapped slightly differently than the 6502
    //    by the memory addressing hardware, as there isn't anything at 0xFFXX as there
    //    might be in an idealistic 6502 system.
    //    Quote: In the KIM-1 system, three address bits (AB13, AB14, ABl5) are not
    //    decoded at all.  Therefore, when the 6502 array generates a fetch from
    //    FFFC and FFFD in response to a RST input, these addresses will be read
    //    as 1FFC and 1FFD and the reset vector will be fetched from these locations.
    //    You now see that all interrupt vectors will be fetched from the top 6
    //    locations of the lowest 8K block of memory which is the only memory block
    //    decoded for the unexpanded KIM-1 system.
    
    // To make SST work, needs to know not to SST the ROM Monitor somehow or that would
    // be recursive and the world might end.
    
    public init() {
        print("CPU init - should happen only once")
    }

   
    
    public func RESET()
    {
        // This is the 6502 Reset signal - RST
        // It's "turning it off and on again" but doesn't nuke RAM
        A = 0
        X = 0
        Y = 0
        SP = DEFAULT_SP
        let resetVector = getAddress(0x17FC)
        PC = resetVector
        INTERRUPT_DISABLE = false
        useHardwareDisplay = false
    }
    
    func IRQ()
    {
        print("IRQ")
        // This is the 6502 Interrupt signal - see https://en.wikipedia.org/wiki/Interrupts_in_65xx_processors
        // IRQ is trigged on the 6502 bus and not by anything the KIM-1 does with standard hardware
        
        let h = UInt8(PC >> 8); push(h)
        let l = UInt8(PC & 0x00FF); push(l)
        push(GetStatusRegister())
        INTERRUPT_DISABLE = true
        //PC = getAddress(0xFFEE) if there was complete memory decoding, which there isn't on the KIM-1
        PC = getAddress(0x17FE)
    }
    
    func NMI()
    {
        print("NMI")
        // This is the 6502 Non-maskable Interrupt signal - see https://en.wikipedia.org/wiki/Interrupts_in_65xx_processors
        // NMI is called when the user presses Stop and SST button
        
        let h = UInt8(PC >> 8); push(h)
        let l = UInt8(PC & 0x00FF); push(l)
        push(GetStatusRegister())
        INTERRUPT_DISABLE = true
        PC = getAddress(0x17FA)  //PC = getAddress(0xFFEA) if there was complete memory decoding
        
        // pc = (uint16_t)read6502(0xFFFA) | ((uint16_t)read6502(0xFFFB) << 8);
        MachineStatus()
        useHardwareDisplay = false
        
    }
    
    func BRK()
    {
        // This is the 6502 BRK signal - see https://en.wikipedia.org/wiki/Interrupts_in_65xx_processors
        
        // The 6502 pushes PC+2 and status with B flag set on stack.
        // The internal BREAK_FLAG is not set in CPU status register (only on push).
        
        // Push return address: BRK is 2 bytes (opcode + padding).
        // Execute() already incremented PC once, so PC &+ 1 = original_PC + 2.
        let returnPC = PC &+ 1
        push(UInt8(returnPC >> 8))
        push(UInt8(returnPC & 0x00FF))
        
        // Push status with B flag bit set (bit 4) and U bit set (bit 5).
        var sr = GetStatusRegister()
        sr |= 0x30 // Set bits 4 (B) and 5 (U)
        push(sr)
        
        INTERRUPT_DISABLE = true
        //PC = getAddress(0x17FA)  // IRQ vector for BRK/IRQ
        PC = getAddress(0x17FE)  // IRQ/BRK vector - Fix suggested by OpenAI. Is it correct?
        
        breakpoint = true
        // Do NOT set BREAK_FLAG internally; only in pushed status byte.
    }
    
    func SetTTYMode(TTY : Bool)
    {
        // These memory addresses will have different values depending on the KIM working in LED mode or Serial terminal mode.
        // They're effectively hardware settings made by a switch on the board.
        // Port A bit 7 is connected to the TTY/LED mode switch
       
        if TTY // Console mode
        {
            // Set external input to 0x00 for TTY mode
            memory.setRIOTPortAInput(0x00)
        }
        else // HEX keypad and LEDs
        {
            // Set external input to 0xFF for LED mode  
            memory.setRIOTPortAInput(0xFF)
        }
    }
    
    // When saving and loading, it's important to save the Registers and PC state.
    func GetStatus() -> [UInt8]
    {
        let pch = UInt8(GetPC() >> 8)
        let pcl = UInt8(GetPC() & 0x00ff)
        return [A, X, Y, SP, GetStatusRegister(), pcl, pch]
    }
    func SetStatus(flags : [UInt8])
    {
        A = flags[0]
        X = flags[1]
        Y = flags[2]
        SP = flags[3]
        SetStatusRegister(reg: flags[4])
        SetPC(ProgramCounter: UInt16(flags[6]) << 8 + UInt16(flags[5]))
    }
    
    func LoadFromDocuments() -> Bool // This load routine also loads in register state (so it's > 64Kb by 7 bytes)
    {
        let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = URL(fileURLWithPath: "TicTacToe", relativeTo: directoryURL).appendingPathExtension("kim")
        
        do {
         // Get the saved data - 64Kb of RAM, 7 bytes of registers
         let savedData = try Data(contentsOf: fileURL)
            let status = savedData.endIndex - 7
            let array = [UInt8](savedData)
            memory.SetMemory(dump: array.dropLast(7))
            SetStatus(flags: [UInt8](array[status...status+6]))
      
        } catch {
         // Catch any errors
         print("Unable to read the file")
            return false
        }
        
        return true
    }
    
    func LoadFromBundle() -> Bool
    {
       // let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filepath = Bundle.main.path(forResource: "TicTacToe", ofType: "kim")
       // let fileURL = URL(fileURLWithPath: "TicTacToe", relativeTo: directoryURL).appendingPathExtension("kim")
        let fileURL = URL(fileURLWithPath: filepath!)
        
        do {
         // Get the saved data - 64Kb of RAM, 7 bytes of registers
         let savedData = try Data(contentsOf: fileURL)
            let status = savedData.endIndex - 7
            let array = [UInt8](savedData)
            memory.SetMemory(dump: array.dropLast(7))
            SetStatus(flags: [UInt8](array[status...status+6]))
      
        } catch {
         // Catch any errors
         print("Unable to read the file")
            return false
        }
        
        return true
    }
    
    func SaveToPapertape(startAddress : Int, length : Int) -> String
    {
        return memory.SaveToPapertape(start: startAddress, length: length)
    }
    
    
    func SaveToDocuments()
    {
        print("Saving memory to Documents - po NSHomeDirectory().")
        let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = URL(fileURLWithPath: "CHECKERS", relativeTo: directoryURL).appendingPathExtension("APPLE")
        
        var array : [UInt8] = memory.GetMemory()
        array = array + GetStatus()
      
        let data : Data = Data(bytes: array, count: array.endIndex)
        
        // Save the data - 64Kb of RAM, 7 bytes of registers
        do {
            try data.write(to: fileURL)

        } catch {
            // Catch any errors
            print(error.localizedDescription)
        }
    }
    
    
    func AppleActive( state : Bool)
    {
        APPLE_ACTIVE = state
        memory.AppleActive(state: APPLE_ACTIVE)
    }
    
    func AppleReady() -> Bool
    {
        return memory.AppleReady()
    }
    
    func AppleKeyboard(s : Bool, k : UInt8)
    {
        memory.AppleKeyState(state: s, key: k)
    }
    
    func AppleOutput() ->(Bool, UInt8)
    {
        return memory.getAppleOutputState()
    }

    func getRIOTDisplayLatchOutput() -> (segments: UInt8, digit: UInt8, portADirection: UInt8, portBDirection: UInt8) {
        return memory.getRIOTDisplayLatchOutput()
    }

    func isEnhancedRIOTEnabled() -> Bool {
        return memory.isEnhancedRIOTEnabled()
    }

    func isHardwareDisplayActive() -> Bool {
        return useHardwareDisplay
    }
    
    // Mark that a direct LED write occurred (game bypasses SCANDS)
    func markDirectLEDWrite() {
        memory.markDirectLEDWrite()
    }
    
    // Check if game has done direct LED writes (bypassing SCANDS)
    func hasDirectLEDWrites() -> Bool {
        return memory.hasDirectLEDWrites()
    }
    
    
    func APPLE_ROM_Code (address: UInt16)
    {
        // The APPLE 1 is very simple, and code simply redirects the output to the "terminal"
        // when the rom routine is called.
        
        if address == 0xFFEF || address == 0xe3d5
        {
           texttodisplay.append(String(format: "%c", (A & 0x7F)))
        }
        
        if address == 0xE003
        {
            return 
        }
        
    }
    
    func KIM_ROM_Code (address: UInt16)
    {
        // This is the KIM specfic part.
        
        // Detect when these routines are being called or jmp'd to and then
        // perform the action and skip to their exit point.
        
        switch (PC) {
                 
        case 0x1F1F :
            // Only skip SCANDS interception if game has done direct LED writes
            // This allows Lunar Lander (uses SCANDS) to work cleanly while
            // Asteroid (direct writes) uses the persistence buffer approach
            if memory.isEnhancedRIOTEnabled() && memory.hasDirectLEDWrites() {
                break
            }
            prn("SCANDS"); // Also sets Z to 0 if a key is being pressed
           
            dataToDisplay = true
            
            if (kim_keyActive)
            {
                ZERO_FLAG = false
            }
            else
            {
                ZERO_FLAG = true
            }
            
            PC = 0x1F45
            
        case 0x1C2A : // Test the input speed for the hardware for timing. We can fake it.
            self.prn("DETCPS")
            memory.WriteAddress(address: 0x17F3, value: 1)
            memory.WriteAddress(address: 0x17F2, value: 1)
            PC = 0x1C4F
            
        case 0x1EFE : // The AK call is a "is someone pressing my keyboard?"
            self.prn("AK")
            
            if kim_keyActive
            {
                A = 0x1
            }
            else
            {
                A = 0xff // No key pressed . It gets OR'd with 80, XOR'd with FF -> 0 Z is set
            }

            
            PC = 0x1F14;
            
       
            
        case 0x1F6A :  // intercept GETKEY (get key from hex keyboard)
            self.prn("GETKEY \(kim_keyNumber)")
          
            if kim_keyActive
            {
                A = kim_keyNumber
                SetFlags(value: A)
            }
            else
            {
                A = 0x1F // Should this is 0xff or 0x1f?
                SetFlags(value: A)
            }
            
            kim_keyNumber = 0
            kim_keyActive = false
    
            
            PC = 0x1F90
            
        case 0x1EA0 : // intercept OUTCH (send char to serial) and display on "console"
            self.prn("OUTCH")
            
            if A >= 13
            {
                texttodisplay.append(String(format: "%c", A))
            }
            Y = 0xFF
            A = 0xFF
            PC = 0x1ED3
            
            
        case 0x1E65 : //   //intercept GETCH (get char from serial). used to be 0x1E5A, but intercept *within* routine just before get1 test
            self.prn("GETCH")
            
            A = GetAKey()
            
            if (A==0) {
                PC=0x1E60;    // cycle through GET1 loop for character start, let the 6502 runs through this loop in a fake way
                break
            }
            
            X = memory.ReadAddress(address: 0xFD) // x is saved in TMPX by getch routine, we need to get it back in x;
            Y = 0xFF
            PC = 0x1E87
    
        default : break
            
        }
    }
    
    
    public func Init(ProgramName : String, computer : String)
    {
        if computer == "APL" { APPLE_ACTIVE = true } else { APPLE_ACTIVE = false}
        
        if !APPLE_ACTIVE
        {
            PC = 0x1c22 // PC default - can be changed in UI code for debugging purposes
        }
        else
        {
            PC = 0xFF00 // Apple prefers PC counter set up here
        }
        SP = DEFAULT_SP // Stack Pointer initial value
        A = 0
        X = 0
        Y = 0
        DECIMAL_MODE = false
        CARRY_FLAG = false
        useHardwareDisplay = false
        ZERO_FLAG = false
        
     
        AppleActive(state: APPLE_ACTIVE)
        
        let registry_data = memory.InitMemory(SoftwareToLoad: ProgramName)    // Optionally set registers for any apps that have been loaded, that's what the next few lines do.
      
        if registry_data != [0,0,0,0,0,0,0,0]
        {
            SetStatus(flags: registry_data)
        }
    }
    
    
   
    
    // Execute one instruction - called by both single-stepping AND by running from the UI code.
    
    public func Step() -> (address : UInt16, Break : Bool, opcode : String, display : Bool)
    {
        
        dataToDisplay = false
        
        // Intercept some KIM-1 Specific things (only when not in Apple mode)
        if !APPLE_ACTIVE {
            KIM_ROM_Code(address: PC)
        }
        
        // Execute the instruction at PC
        if !Execute()
        {
            PC = 0xffff
        }
        
        // Tick RIOT timer by the actual instruction cycle count
        // This provides accurate timing for games like ASTEROID that depend on timer delays
        memory.RIOT_Timer_Click(cycles: lastInstructionCycles)
        
        useHardwareDisplay = !APPLE_ACTIVE && PC < 0x1C00
       RUNTIME_DEBUG_MESSAGES = true
        
         // Optional - display debug information using RUNTIME_DEBUG_MESSAGES to trigger debug information display

        if  PC == 0x17fc
        {
                DisplayDebugInformation()
         }
        
        // Special case = if a garbage instructinon PC will be 0xffff
        return (PC, breakpoint, statusmessage, dataToDisplay)
    }
    
    // Serial terminal version
    func StepSerial() -> (address : UInt16, Break : Bool, terminalOutput : String)
    {
        if !APPLE_ACTIVE
        {
            // Intercept some KIM-1 Specific things
            KIM_ROM_Code(address: PC)
        }
        
        // Execute the instruction at PC
        _ = Execute()
        
        // Tick RIOT timer by actual instruction cycle count
        if !APPLE_ACTIVE {
            memory.RIOT_Timer_Click(cycles: lastInstructionCycles)
        }
        
        if APPLE_ACTIVE
        {
            APPLE_ROM_Code(address: PC)
            

        }
        
        let returnString = texttodisplay
        texttodisplay = ""
        
        RUNTIME_DEBUG_MESSAGES = false// <- if you want debugging
           
        if RUNTIME_DEBUG_MESSAGES
        {
           if PC < 0x1c00 || PC > 0x2000
           {
                DisplayDebugInformation()
           }
        }
        
        return (PC, breakpoint, returnString)
    }
    
    
    
    
    func GetAKey() -> UInt8
    {
        // if no key pressed, return 0xFF
        // else return ASCII code (upper case) and switch off key
        
        if !kim_keyActive
        {
            return 0 //0xff
        }
        
        kim_keyActive = false
        return kim_keyNumber
        
    }
    
    
    public func Read(address : UInt16) -> UInt8
    {
        return memory.ReadAddress(address: address)
    }
    
    public func Write(address : UInt16, byte : UInt8)
    {
        memory.WriteAddress(address: address, value: byte)
    }

    func setLEDWriteCallback(_ callback: ((UInt8, UInt8) -> Void)?) {
        memory.setLEDWriteCallback(callback)
    }
    
    
    func printStatusToDebugWindow(_ regs: String, _ flags: String) {
        print(statusmessage, terminator:"")
        print("  " + regs, terminator:"")
        print("  " + flags)
    }
    
    public func getA() -> UInt8
    {
        return A
    }
    
    public func getX() -> UInt8
    {
        return X
    }
    
    public func getY() -> UInt8
    {
        return Y
    }
    
    public func getSP() -> UInt8
    {
        return SP
    }
    
    func NotInROM() -> Bool
    {
        // Used by the SST to skip over ROM code
        
        if PC<0x1C00
        {
            return true
        }
        else
        {
            return false
        }
        
    }
    
    func Dump(opcode : UInt8)
    {
        
        let regs =  String("OP:\(String(format: "%02X",opcode)) PC:\(String(format: "%04X", PC)) A:\(String(format: "%02X",A)) X:\(String(format: "%02X",X)) Y:\(String(format: "%02X",Y)) SP:\(String(format: "%02X",SP))")
        
        var flags = ""
        if NEGATIVE_FLAG { flags="N" } else {flags="n"}
        if OVERFLOW_FLAG { flags = flags + "V" } else { flags = flags + "v" }
        flags = flags + "_"
        if BREAK_FLAG { flags = flags + "B" } else { flags = flags + "b" }
        if DECIMAL_MODE { flags = flags + "D" } else { flags = flags + "d" }
        if INTERRUPT_DISABLE { flags = flags + "I" } else {flags = flags + "i"}
        if ZERO_FLAG { flags = flags + "Z"} else {flags = flags + "z"}
        if CARRY_FLAG { flags = flags + "C"} else {flags = flags + "c"}
        
        print(regs, flags)
        
    }
    
    func DisplayDebugInformation()
    {
        
        var flags = ""
        if NEGATIVE_FLAG { flags="N" } else {flags="n"}
        if OVERFLOW_FLAG { flags = flags + "V" } else { flags = flags + "v" }
        flags = flags + "_"
        if BREAK_FLAG { flags = flags + "B" } else { flags = flags + "b" }
        if DECIMAL_MODE { flags = flags + "D" } else { flags = flags + "d" }
        if INTERRUPT_DISABLE { flags = flags + "I" } else {flags = flags + "i"}
        if ZERO_FLAG { flags = flags + "Z"} else {flags = flags + "z"}
        if CARRY_FLAG { flags = flags + "C"} else {flags = flags + "c"}
        
        let regs =  String("\(String(format: "%04X",Read(address: PC)))  PC:\(String(format: "%04X", PC)) A:\(String(format: "%02X",A)) X:\(String(format: "%02X",X)) Y:\(String(format: "%02X",Y)) SP:\(String(format: "%02X",SP))  AC:\(String(format: "%02X",memory.ReadAddress(address: 0x200)))  AC:\(String(format: "%02X",memory.ReadAddress(address: 0x1A)))  AC:\(String(format: "%02X",memory.ReadAddress(address: 0x19)))")
        
        printStatusToDebugWindow(regs, flags)
    
    }
    
    func SetRAMTop(RAMlimit: UInt16)
    {
        memory.setMemoryLimit(limit: RAMlimit)

    }
    
    func MachineStatus()
    {
        // a unique kim feature that copies the registers into memory
        // to be examined later by the user if they so wish.
        
        
        memory.WriteAddress(address: 0xEF, value: UInt8(PC & 255))
        memory.WriteAddress(address: 0xF0, value: UInt8(PC >> 8))
        memory.WriteAddress(address: 0xF1, value: GetStatusRegister())
        memory.WriteAddress(address: 0xF2, value: SP)
        memory.WriteAddress(address: 0xF3, value: A)
        memory.WriteAddress(address: 0xF4, value: Y)
        memory.WriteAddress(address: 0xF5, value: X)
    }
    
    func SetStatusRegister(reg : UInt8)
    {
        CARRY_FLAG = (reg & 1) == 1
        ZERO_FLAG = (reg & 2) == 2
        INTERRUPT_DISABLE = (reg & 4) == 4
        DECIMAL_MODE = (reg & 8) == 8
        // BREAK_FLAG is not stored internally by the CPU, only in the pushed status byte
        // So do NOT set BREAK_FLAG here from pulled status; it's only set on stack push
        // BREAK_FLAG = (reg & 16) == 16
        BREAK_FLAG = false // Always false internally
        UNUSED_FLAG = true // bit 5 always set internally
        OVERFLOW_FLAG = (reg & 64) == 64
        NEGATIVE_FLAG = (reg & 128) == 128
    }
    
    public func GetStatusRegister() -> UInt8
    {
        var sr : UInt8 = 0
        
        if CARRY_FLAG { sr |= 1}
        if ZERO_FLAG { sr |= 2}
        if INTERRUPT_DISABLE { sr |= 4}
        if DECIMAL_MODE { sr |= 8}
        // BREAK_FLAG not internal, but set on push when PHP or BRK
        if BREAK_FLAG { sr |= 16}
        sr |= 0x20 // Unused bit always set as per 6502 behavior
        if OVERFLOW_FLAG { sr |= 64}
        if NEGATIVE_FLAG { sr |= 128}
        
        return sr
    }
    
    
    public func SetPC(ProgramCounter: UInt16)
    {
        PC = ProgramCounter
    }
    
    public func GetPC() -> UInt16
    {
        return PC
    }
    
    func Execute() -> Bool
    {
        // Use the PC to read the instruction (and other data if required) and
        // execute the instruction.
        
        let ins = memory.ReadAddress(address: PC)
        
        // Look up cycle count for this instruction (for accurate RIOT timer emulation)
        lastInstructionCycles = instructionCycles[ins] ?? 2  // Default to 2 if unknown
        
        if PC >= 0xffff
        {
            PC = PC &- 0xffff
        }
        else
        {
            incPC()
        }
        
       // Dump(opcode: ins) // Debugging information.
        
       return ProcessInstruction(instruction: ins)
    }
    
    func ProcessInstruction(instruction : UInt8) -> Bool
    {
        
        switch instruction {
        
        case 0: BRK()
        case 1: OR_indexed_indirect_x()
            
        case 5: OR_z()
        case 06: ASL_z()
            
        case 8: PHP()
        case 9: OR_i()
        case 0x0A : ASL_i()
            
        case 0x0D : OR_a()
        case 0x0E : ASL_a()
            
        case 0x10 : BPL()
        case 0x11 : OR_indirect_indexed_y()
            
        case 0x15 : OR_zx()
        case 0x16 : ASL_zx()
        case 0x18 : CLC()
        case 0x19 : OR_indexed_y()
        case 0x1A : INC_A()  // 65C02: INC A
            
        case 0x1D : OR_indexed_x()
        case 0x1E : ASL_indexed_x()
            
        case 0x20 : JSR()
        case 0x21 : AND_indexed_indirect_x()
            
        case 0x24 : BIT_z()
        case 0x25 : AND_z()
        case 0x26 : ROL_z()
            
            
        case 0x28 : PLP()
        case 0x29 : AND_i()
        case 0x2A : ROL_i()
            
        case 0x2C : BIT_a()
        case 0x2D : AND_a()
        case 0x2E : ROL_a()
            
        case 0x30 : BMI()
        case 0x31: AND_indirect_indexed_y()
            
        case 0x35: AND_zx()
        case 0x36 : ROL_zx()
            
        case 0x38 : SEC()
        case 0x39 : AND_indexed_y()
        case 0x3A : DEC_A()  // 65C02: DEC A
            
        case 0x3D : AND_indexed_x()
        case 0x3E : ROL_indexed_x()
            
        case 0x40 : RTI()
        case 0x41 : EOR_indexed_indirect_x()
            
        case 0x45 : EOR_z()
        case 0x46 : LSR_z()
            
        case 0x48 : PHA()
        case 0x49 : EOR_i()
        case 0x4A : LSR_i()
            
            
        case 0x4C : JMP_ABS()
        case 0x4D : EOR_a()
        case 0x4E : LSR_a()
            
        case 0x50 : BVC()
        case 0x51 : EOR_indirect_indexed_y()
            
        case 0x55 : EOR_zx()
        case 0x56 : LSR_zx()
            
        case 0x58 : CLI()
        case 0x59 : EOR_indexed_y()
            
        case 0x5A : PHY()
            
        case 0x5D : EOR_indexed_x()
        case 0x5E : LSR_indexed_x()
            
        case 0x60 : RTS()
        case 0x61 : ADC_indexed_indirect_x()
            
        case 0x65 : ADC_z()
        case 0x66 : ROR_z()
            
        case 0x68 : PLA()
        case 0x69 : ADC_i()
        case 0x6A : ROR_i()
            
        case 0x6D : ADC_a()
        case 0x6E : ROR_a()
            
        case 0x70 : BVS()
        case 0x71 : ADC_indirect_indexed_y()
        case 0x72:  ADC_zeropage_indirect() // 65C02: ADC (zp)
            
        case 0x75 : ADC_zx()
        case 0x76 : ROR_zx()
            
        case 0x78 : SEI()
        case 0x79 : ADC_indexed_y()
        case 0x7A : PLY()
            
        case 0x7D : ADC_indexed_x()
        case 0x7E : ROR_indexed_x()
            
        case 0x6C: JMP_INDIRECT()
            
       
            
        case 0x80 : BRA() // 65C02
        case 0x81 : STA_indexed_indirect_x()
            
        case 0x84 : STY_z()
        case 0x85 : STA_z()
        case 0x86 : STX_z()
            
        case 0x88: DEY()
            
       // case 0x89: BIT() 6502c only
       
        case 0x8A : TXA()
            
        case 0x8C : STY_a()
        case 0x8D : STA_a()
        case 0x8E : STX_a()
            
        case 0x90: BCC()
        case 0x91 : STA_indirect_indexed_y()
            
        case 0x94 : STY_xa()
        case 0x95 : STA_zx()
        case 0x96 : STX_ya()
            
        case 0x98 : TYA()
        case 0x99 : STA_indexed_y()
        case 0x9A : TXS()
            
        case 0x9D : STA_indexed_x()
            
        case 0xA0 : LDY_i()
        case 0xA1 : LDA_indexed_indirect_x()
        case 0xA2 : LDX_i()
            
        case 0xA4 : LDY_z()
        case 0xA5 : LDA_z()
        case 0xA6 : LDX_z()
            
        case 0xA8 : TAY()
        case 0xA9 : LDA_i()
            
        case 0xAA : TAX()
            
        case 0xAC : LDY_a()
        case 0xAD : LDA_a()
        case 0xAE : LDX_a()
            
        case 0xB0 : BCS()
        case 0xB1 : LDA_indirect_indexed_y()
            
        case 0xB4 : LDY_zx()
        case 0xB5 : LDA_zx()
        case 0xB6 : LDX_zy()
            
        case 0xB8 : CLV()
        case 0xB9 : LDA_indexed_y()
        case 0xBA : TSX()
            
        case 0xBC : LDY_indexed_x()
        case 0xBD : LDA_indexed_x()
        case 0xBE : LDX_indexed_y()
            
            
        case 0xC0 : CPY_i()
        case 0xC1 : CMP_indexed_indirect_x()
            
        case 0xC4 : CPY_z()
        case 0xC5 : CMP_z()
        case 0xC6 : DEC_z()
            
        case 0xC8 : INY()       // Incorrect in Assembly Lines book (gasp)
        case 0xC9 : CMP_i()
        case 0xCA : DEX()
            
        case 0xCC : CPY_A()
        case 0xCD : CMP_a()
        case 0xCE : DEC_a()
            
        case 0xD0 : BNE()
        case 0xD1 : CMP_indirect_indexed_y()
            
        case 0xD5 : CMP_zx()
        case 0xD6 : DEC_zx()
            
        case 0xD8 : CLD()
        case 0xD9 : CMP_indexed_y()
        case 0xDA : PHX()
            
        case 0xDD : CMP_indexed_x()
        case 0xDE : DEC_ax()
            
        case 0xE0 : CPX_i()
        case 0xE1 : SBC_indexed_indirect_x()
            
        case 0xE4 : CPX_z()
        case 0xE5 : SBC_z()
        case 0xE6 : INC_z()
            
        case 0xE8 : INX()
        case 0xE9 : SBC_i()
        case 0xEA : NOP()
            
        case 0xEC : CPX_A()
        case 0xED : SBC_a()
        case 0xEE : INC_a()
            
        case 0xF0 : BEQ()
        case 0xF1 : SBC_indirect_indexed_y()
            
        case 0xF5 : SBC_zx()
        case 0xF6 : INC_zx()
            
        case 0xF8 : SED()
        case 0xF9 : SBC_indexed_y()
        case 0xFA : PLX()
            
        case 0xFD : SBC_indexed_x()
        case 0xFE : INC_ax()
            
        default : /*print("**********************      Unknown instruction (or garbage): " + String(  format: "%02X", instruction) + " at " + String(  format: "%04X", PC) + "   **********************");*/  return false
            
        }
        
        return true
    }
    
    
    
    
    // Implement the 6502 instruction set
    //
    // Addressing modes - http://www.obelisk.me.uk/6502/addressing.html
    //
    
    
    func KIL() {
       // halted = true            // or set a trap/throw
        prn("KIL/JAM opcode encountered")
    }
    
    func RTI()
    {
        // Used in the KIM-1 to launch user app
        
        // 6502 pulls status first, then PC low, then PC high
        
        let p = pop()
        SetStatusRegister(reg: p)
        
        let l = UInt16(pop())
        let h = UInt16(pop())
        PC = (h<<8) + l
        prn("RTI")
    }
    
    func NOP() // EA
    {
        prn("NOP")
    }
    
    // Accumulator BIT test - needs proper testing
    
    
    func  BIT_z() // 24
    {
        let ad = memory.ReadAddress(address: PC) ;  incPC()
        let v = memory.ReadAddress(address: UInt16(ad))
        let t = (A & v)
        ZERO_FLAG = (t == 0) ? true : false
        NEGATIVE_FLAG = (v & 128) == 128
        OVERFLOW_FLAG = (v & 64) == 64
        
        prn("BIT $"+String(format: "%02X",ad))
    }
    
    
    func  BIT_a() // 2C
    {
        let ad = getAbsoluteAddress()
        let v = memory.ReadAddress(address: UInt16(ad))
        let t = (A & v)
        ZERO_FLAG = (t == 0) ? true : false
        NEGATIVE_FLAG = (v & 128) == 128
        OVERFLOW_FLAG = (v & 64) == 64
        
        prn("BIT $"+String(format: "%04X",ad))
    }
    
    // Accumulator Addition
    
    func  ADC_i() // 69
    {
        let v = memory.ReadAddress(address: PC) ; incPC()
        addC(v)
        prn("ADC #$"+String(format: "%02X",v))
    }
    
    func  ADC_indexed_indirect_x() // 61
    {
        let za = memory.ReadAddress(address: PC);
        let v = get_indexed_indirect_zp_x()
        addC(v)
        prn("ADC ($"+String(format: "%02X",za)+",X)")
    }
    
    func  ADC_z() // 65
    {
        let ad = memory.ReadAddress(address: PC) ; incPC()
        let v = memory.ReadAddress(address: UInt16(ad))
        addC(v)
        prn("ADC $"+String(format: "%04X",v))
    }
    
    func  ADC_zx() // 75
    {
        let zp = getZeroPageX()
        let v = memory.ReadAddress(address: zp)
        addC(v)
        prn("ADC $"+String(format: "%02X",zp &- UInt16(X))+",X")
    }
    
    func  ADC_a() // 6D
    {
        let ad = getAbsoluteAddress()
        let v = memory.ReadAddress(address: UInt16(ad))
        addC(v)
        prn("ADC $"+String(format: "%04X",ad))
    }
    
    func  ADC_indexed_x() // 7d
    {
        let ad = getAbsoluteX()
        let v = memory.ReadAddress(address: ad)
        addC(v)
        prn("ADC $"+String(format: "%04X",ad &- UInt16(X)))
    }
    
    func  ADC_indexed_y() // 79
    {
        let ad = getAbsoluteY()
        let v = memory.ReadAddress(address: ad)
        addC(v)
        prn("ADC $"+String(format: "%04X",ad &- UInt16(Y)))
    }
    
    
    func  ADC_indirect_indexed_y() // 71
    {
        let adr = getIndirectY()
        let v = memory.ReadAddress(address: adr)
        addC(v)
        prn("ADC ($"+String(format: "%02X",adr - UInt16(Y))+"),Y")
    }
    
    // 65C02: ADC (zp) indirect (opcode 0x72)
    func ADC_zeropage_indirect() // 72 (65C02)
    {
        let zp = UInt16(memory.ReadAddress(address: PC)); incPC()
        // (zp) -> fetch 16-bit address from zero page with wrap
        let lo = UInt16(memory.ReadAddress(address: zp & 0x00FF))
        let hi = UInt16(memory.ReadAddress(address: (zp &+ 1) & 0x00FF))
        let adr = (hi << 8) | lo
        let v = memory.ReadAddress(address: adr)
        addC(v)
        prn("ADC ($"+String(format: "%02X",zp)+")")
    }
    
    
    // Accumulator Subtraction
    
    func  SBC_i() // E9
    {
        let v = memory.ReadAddress(address: PC) ; incPC()
        subC(v)
        prn("SBC #$"+String(format: "%02X",v))
    }
    
    func SBC_z() // E5
    {
        let zero_page_address = memory.ReadAddress(address: PC) ; incPC()
        let v = memory.ReadAddress(address: UInt16(zero_page_address))
        subC(v)
        prn("SBC $"+String(String(format: "%02X",zero_page_address)))
    }
    
    func  SBC_zx() // F5
    {
        let ad = getZeroPageX()
        let v = memory.ReadAddress(address: ad)
        subC(v)
        prn("SBC $"+String(format: "%02X",ad &- UInt16(X))+",X")
    }
    
    func  SBC_a() // ed
    {
        let ad = getAbsoluteAddress()
        let v = memory.ReadAddress(address: UInt16(ad))
        subC(v)
        prn("SBC $"+String(format: "%04X",ad))
    }
    
    func  SBC_indexed_x() // fd
    {
        let ad = getAbsoluteX()
        let v = memory.ReadAddress(address: ad)
        subC(v)
        prn("SBC $"+String(format: "%04X",ad - UInt16(X))+",X")
    }
    
    func  SBC_indexed_y() // F9
    {
        let ad = getAbsoluteY()
        let v = memory.ReadAddress(address: ad)
        subC(v)
        prn("SBC $"+String(format: "%04X",ad - UInt16(Y))+",Y")
    }
    
    func  SBC_indirect_indexed_y() // F1
    {
        let adr = getIndirectY()
        let v = memory.ReadAddress(address: adr)
        subC(v)
        prn("SBC ($" + String(format: "%04X",adr) + "),Y")
    }
    
    func SBC_indexed_indirect_x() // E1
    {
        let za = memory.ReadAddress(address: PC );
        let v = get_indexed_indirect_zp_x()
        subC(v)
        prn("SBC ($"+String(format: "%04X",za)+",X)")
    }
    
    // General comparision
    
    func compare(_ n : UInt8, _ v: UInt8)
    {
        let result = Int16(n) - Int16(v)
        if n >= v { CARRY_FLAG = true } else { CARRY_FLAG = false }
        if n == v { ZERO_FLAG = true } else { ZERO_FLAG = false }
        // Negative flag set from bit 7 of result (signed)
        NEGATIVE_FLAG = (result & 0x80) == 0x80
        // Overflow flag is NOT affected by CMP/CPX/CPY on the real 6502
    }
    
    // X Comparisons
    
    func CPX_i() // E0
    {
        let v = memory.ReadAddress(address: PC) ; incPC()
        compare(X, v)
        prn("CPX #$"+String(format: "%02X",v))
    }
    
    func CPX_z() // E4
    {
        let ad = memory.ReadAddress(address: PC) ;  incPC()
        let v = memory.ReadAddress(address: UInt16(ad))
        compare(X, v)
        prn("CPX $"+String(format: "%02X",ad))
    }
    
    func CPX_A() // EC
    {
        let ad = getAbsoluteAddress()
        let v = memory.ReadAddress(address: UInt16(ad))
        compare(X, v)
        prn("CPX $"+String(format: "%04X",ad))
        
    }
    
    // Y Comparisons
    
    func CPY_i() // C0
    {
        let v = memory.ReadAddress(address: PC) ; incPC()
        compare(Y, v)
        prn("CPY #$"+String(format: "%02X",v))
    }
    
    func CPY_z() // C4
    {
        let ad = memory.ReadAddress(address: PC) ;  incPC()
        let v = memory.ReadAddress(address: UInt16(ad))
        compare(Y, v)
        prn("CPY $"+String(format: "%02X",ad))
    }
    
    func CPY_A()
    {
        let ad = getAbsoluteAddress()
        let v = memory.ReadAddress(address: UInt16(ad))
        compare(Y, v)
        prn("CPY $"+String(format: "%04X",ad))
        
    }
    
    // Accumulator Comparison
    
    func CMP_i() // C9
    {
        let v = memory.ReadAddress(address: PC) ; incPC()
        compare(A, v)
        prn("CMP #$"+String(format: "%02X",v))
    }
    
    func CMP_z() // C5
    {
        let ad = memory.ReadAddress(address: PC) ;  incPC()
        let v = memory.ReadAddress(address: UInt16(ad))
        compare(A, v)
        prn("CMP $"+String(format: "%02X",ad))
    }
    
    func  CMP_zx() // D5
    {
        let ad = getZeroPageX()
        let v = memory.ReadAddress(address: ad)
        compare(A, v)
        prn("CMP $"+String(format: "%02X",ad - UInt16(X))+",X")
    }
    
    func CMP_a() // cd
    {
        let ad = getAbsoluteAddress()
        let v = memory.ReadAddress(address: UInt16(ad))
        compare(A, v)
        prn("CMP $"+String(format: "%04X",ad))
    }
    
    func  CMP_indexed_x() // dd
    {
        let ad = getAbsoluteX()
        let v = memory.ReadAddress(address: ad)
        compare(A, v)
        prn("CMP $"+String(format: "%04X",ad &- UInt16(X))+",X")
    }
    
    func  CMP_indexed_y() // d9
    {
        let ad = getAbsoluteY()
        let v = memory.ReadAddress(address:ad)
        compare(A, v)
        prn("CMP $"+String(format: "%04X",ad - UInt16(Y))+",Y")
    }
    
    func CMP_indirect_indexed_y() // D1
    {
        let adr = getIndirectY()
        let v =  memory.ReadAddress(address: adr)
        
        //let zp = UInt16(memory.ReadAddress(address: PC));
        //let v = memory.ReadAddress(address: getIndirectIndexedBase())
        compare(A, v)
        prn("CMP ($"+String(format: "%02X",adr - UInt16(Y))+"),Y")
    }
    
    func CMP_indexed_indirect_x() // c1
    {
        let za = memory.ReadAddress(address: PC);
        let v = get_indexed_indirect_zp_x()
        compare(A, v)
        prn("CMP ($"+String(format: "%02X",za)+"),X")
    }
    
    
    // Accumulator Loading
    
    func  LDA_i() // A9
    {
        A = getImmediate()
        SetFlags(value: A)
        prn("LDA #$"+String(format: "%02X",A))
    }
    
    func  LDA_z() // A5
    {
        let zero_page_ad = memory.ReadAddress(address: PC) ; incPC()
        A = memory.ReadAddress(address: UInt16(zero_page_ad))
        SetFlags(value: A)
        prn("LDA $"+String(format: "%02X",zero_page_ad))
    }
    
    func  LDA_zx() // B5
    {
        let ad = getZeroPageX()
        A = memory.ReadAddress(address: ad)
        SetFlags(value: A)
        prn("LDA $"+String(format: "%02X",ad &- UInt16(X))+",X")
    }
    
    func LDA_a() // ad
    {
        let ad = getAbsoluteAddress()
        A = memory.ReadAddress(address: ad)
        SetFlags(value: A)
        prn("LDA $"+String(format: "%04X",ad))
    }
    
    func LDA_indexed_x() // bd
    {
        let ad = getAbsoluteX()
        A = memory.ReadAddress(address: ad)
        SetFlags(value: A)
        prn("LDA $"+String(format: "%04X",ad &- UInt16(X))+",X")
    }
    
    func  LDA_indexed_y() // B9
    {
        let ad = getAbsoluteY()
        A = memory.ReadAddress(address: ad)
        SetFlags(value: A)
        prn("LDA $"+String(format: "%04X",ad &- UInt16(Y))+",Y")
    }
    
    func  LDA_indexed_indirect_x() // A1
    {
        let za = memory.ReadAddress(address: PC);
        A = get_indexed_indirect_zp_x()
        SetFlags(value: A)
        prn("LDA ($"+String(format: "%02X",za)+",X)")
    }
    
    func  LDA_indirect_indexed_y() // B1
    {
        let adr = getIndirectY()
        A = memory.ReadAddress(address: adr)
        SetFlags(value: A)
        prn("LDA ($"+String(format: "%02X",adr - UInt16(Y))+"),Y")
        
    }
    
    
    
    // Accumulator Storing
    
    func  STA_z() // 85
    {
        let zero_page_add = memory.ReadAddress(address: PC) ; incPC()
        memory.WriteAddress(address: UInt16(zero_page_add), value: A)
        prn("STA $"+String(format: "%02X",zero_page_add))
    }
    
    func  STA_zx() // 95
    {
        let z = memory.ReadAddress(address: PC)
        let ad = getZeroPageX()
        memory.WriteAddress(address: ad, value: A)
        prn("STA $"+String(format: "%02X",z)+",X")
    }
    
    func STA_a() // 8D
    {
        let v = getAbsoluteAddress()
        memory.WriteAddress(address: v, value: A)
        prn("STA #$" + String(format: "%04X",v))
    }
    
    
    func  STA_indexed_x() // 9d
    {
        let ad = getAbsoluteX()
        memory.WriteAddress(address: ad , value: A)
        prn("STA #$" + String(format: "%04X",ad &- UInt16(X))+",X")
    }
    
    
    
    
    func STA_indexed_y() // Absolute indexed // 99
    {
        let ad = getAbsoluteY()
        memory.WriteAddress(address: ad, value: A)
        prn("STA #$" + String(format: "%04X",ad &- UInt16(Y))+",Y")
    }
    
    func  STA_indirect_indexed_y() // 91
    {
        let adr = getIndirectY()
        memory.WriteAddress(address: adr, value: A)
        
        
        // let za = memory.ReadAddress(address: PC)
        //  memory.WriteAddress(address: getIndirectIndexedBase(), value: A)
        prn("STA ($"+String(format: "%02X",adr - UInt16(Y))+"),Y")
    }
    
    func  STA_indexed_indirect_x() // 81
    {
        let za = memory.ReadAddress(address: PC);
        let adr = get_indexed_indirect_zp_x_address()
        memory.WriteAddress(address: UInt16(adr), value: A)
        prn("STA ($"+String(format: "%02X",za)+"),X")

    }
    
    
    // Register X Loading
    
    func  LDX_i() // A2
    {
        X = getImmediate()
        SetFlags(value: X)
        prn("LDX #$"+String(format: "%02X",X))
    }
    
    func  LDX_z() // A6
    {
        let zero_page_address = memory.ReadAddress(address: PC) ; incPC()
        X = memory.ReadAddress(address: UInt16(zero_page_address))
        SetFlags(value: X)
        prn("LDX $"+String(format: "%02X",zero_page_address))
    }
    
    func  LDX_zy() // B6
    {
        let ad = getZeroPageY()
        X = memory.ReadAddress(address: ad)
        SetFlags(value: X)
        prn("LDX $"+String(format: "%02X",ad &- UInt16(Y))+",Y")
    }
    
    func LDX_a() // ae
    {
        let ad = getAbsoluteAddress()
        X = memory.ReadAddress(address: ad)
        SetFlags(value: X)
        prn("LDX $"+String(format: "%04X",ad))
    }
    
    func  LDX_indexed_y() // BE
    {
        let ad = getAbsoluteY()
        X = memory.ReadAddress(address: ad)
        SetFlags(value: X)
        prn("LDX $"+String(format: "%04X",ad - UInt16(Y) )+",Y")
    }
    
    // Register Y Loading
    
    func  LDY_i() // A0
    {
        Y = getImmediate()
        SetFlags(value: Y)
        prn("LDY #$"+String(format: "%02X",Y))
    }
    
    func  LDY_z() // A4
    {
        let ad = memory.ReadAddress(address: PC) ; incPC()
        Y = memory.ReadAddress(address: UInt16(ad))
        SetFlags(value: Y)
        prn("LDY $"+String(format: "%02X",Y))
    }
    
    func  LDY_zx() // B4
    {
        let ad = getZeroPageX()
        Y = memory.ReadAddress(address: ad)
        SetFlags(value: Y)
        prn("LDY $"+String(format: "%02X",ad &- UInt16(X))+",X")
    }
    
    func LDY_a() // AC
    {
        let ad = getAbsoluteAddress()
        Y = memory.ReadAddress(address: UInt16(ad))
        SetFlags(value: Y)
        prn("LDY $"+String(format: "%04X",ad))
    }
    
    func  LDY_indexed_x() // BC
    {
        let ad = getAbsoluteX()
        Y = memory.ReadAddress(address:  ad)
        SetFlags(value: Y)
        prn("LDY $"+String(format: "%04X",ad &- UInt16(X))+",X")
    }
    
    
    
    // Accumulator AND
    
    func  AND_i() // 29
    {
        let v = getImmediate()
        A = A & v
        SetFlags(value: A)
        prn("AND #$"+String(format: "%02X",v))
    }
    
    func  AND_z() // 25
    {
        let ad = memory.ReadAddress(address: PC) ; incPC()
        let v = memory.ReadAddress(address: UInt16(ad))
        A = A & v
        SetFlags(value: A)
        prn("AND $"+String(format: "%02X",ad))
    }
    
    func  AND_zx() // 35
    {
        let z = memory.ReadAddress(address: PC)
        let ad = getZeroPageX()
        let v = memory.ReadAddress(address: ad)
        A = A & v
        SetFlags(value: A)
        prn("AND $"+String(format: "%02X",z))
    }
    
    func  AND_a() // 2d
    {
        let ad = getAbsoluteAddress()
        let v = memory.ReadAddress(address: UInt16(ad))
        A = A & v
        SetFlags(value: A)
        prn("AND $"+String(format: "%04X",ad))
    }
    
    func  AND_indexed_x() // 3d
    {
        let ad = getAbsoluteX()
        let v = memory.ReadAddress(address: ad)
        A = A & v
        SetFlags(value: A)
        prn("AND $"+String(format: "%04X",ad &- UInt16(X))+",X")
    }
    
    func  AND_indexed_y() // 39
    {
        let ad = getAbsoluteY()
        let v = memory.ReadAddress(address: ad)
        A = A & v
        SetFlags(value: A)
        prn("AND $"+String(format: "%04X",ad - UInt16(Y))+",Y")
    }
    
    func AND_indexed_indirect_x() // 21
    {
        let za = memory.ReadAddress(address: PC);
        let v = get_indexed_indirect_zp_x()
        A = A & v
        SetFlags(value: A)
        prn("AND ($"+String(format: "%02X",za)+",X)")
    }
    
    func AND_indirect_indexed_y() // 31
    {
        //   let za = memory.ReadAddress(address: PC)
        //  let v = memory.ReadAddress(address: getIndirectIndexedBase())
        
        let adr = getIndirectY()
        let v = memory.ReadAddress(address: adr)
        
        A = A & v
        SetFlags(value: A)
        prn("AND ($"+String(format: "%02X",adr - UInt16(Y))+",X)")
        
        
        //   A = A & v
        //   SetFlags(value: A)
        //   prn("AND ($"+String(format: "%02X",za)+"),Y")
    }
    
    // LSR
    
    func  LSR_i() // 4A
    {
        CARRY_FLAG = (A & 1) == 1
        A = A >> 1
        SetFlags(value: A)
        prn("LSR")
    }
    
    func  LSR_z() // 46
    {
        let ad = memory.ReadAddress(address: PC)
        var v = memory.ReadAddress(address: UInt16(ad))
        CARRY_FLAG = ((v & 1) == 1)
        v = v >> 1
        memory.WriteAddress(address: UInt16(ad), value: v)
        incPC()
        SetFlags(value: v)
        prn("LSR $"+String(format: "%02X",ad))
    }
    
    func  LSR_zx() // 56
    {
        
        let z = memory.ReadAddress(address: PC)
        let ad = getZeroPageX()
        var v = memory.ReadAddress(address: ad)
        
        CARRY_FLAG = (v & 1) == 1
        v = v >> 1
        memory.WriteAddress(address: ad, value: v)
        SetFlags(value: v)
        prn("LSR $"+String(format: "%02X",z)+",X")
    }
    
    func  LSR_a() // 4E
    {
        let ad = getAbsoluteAddress()
        var v = memory.ReadAddress(address: UInt16(ad))
        CARRY_FLAG = (v & 1) == 1
        v = v >> 1
        memory.WriteAddress(address: ad, value: v)
        SetFlags(value: v)
        prn("LSR $"+String(format: "%04X",ad))
    }
    
    func  LSR_indexed_x() // 5E
    {
        let ad = getAbsoluteX()
        var v = memory.ReadAddress(address: ad)
        CARRY_FLAG = (v & 1) == 1
        v = v >> 1
        memory.WriteAddress(address:  ad , value: v)
        SetFlags(value: v)
        prn("LSR $"+String(format: "%04X",ad &- UInt16(X))+",X")
    }
    
    
    // Accumulator OR
    
    func  OR_i() // 09
    {
        let v = getImmediate()
        A = A | v
        SetFlags(value: A)
        prn("OR #$"+String(format: "%02X",v))
    }
    
    func  OR_z() // 5
    {
        let ad = memory.ReadAddress(address: PC) ; incPC()
        let v = memory.ReadAddress(address: UInt16(ad))
        A = A | v
        SetFlags(value: A)
        prn("OR $"+String(format: "%02X",ad))
    }
    
    func  OR_zx() // 15
    {
        let z = memory.ReadAddress(address: PC)
        let ad = getZeroPageX()
        let v = memory.ReadAddress(address: ad)
        A = A | v
        SetFlags(value: A)
        prn("OR $"+String(format: "%02X",z)+",X")
    }
    
    func  OR_a() // 0d
    {
        let ad = getAbsoluteAddress()
        let v = memory.ReadAddress(address: UInt16(ad))
        A = A | v
        SetFlags(value: A)
        prn("OR $"+String(format: "%04X",ad))
    }
    
    func  OR_indexed_x() // 1d
    {
        let ad = getAbsoluteX()
        let v = memory.ReadAddress(address: ( ad))
        A = A | v
        SetFlags(value: A)
        prn("OR $"+String(format: "%04X",ad - UInt16(X))+",X")
    }
    
    func  OR_indexed_y() // 19
    {
        let ad = getAbsoluteY()
        let v = memory.ReadAddress(address: ad)
        A = A | v
        SetFlags(value: A)
        prn("OR $"+String(format: "%04X",ad - UInt16(Y))+",Y")
    }
    
    func  OR_indexed_indirect_x() // 01
    {
        let za = memory.ReadAddress(address: PC);
        let v = get_indexed_indirect_zp_x()
        A = A | v
        SetFlags(value: A)
        prn("OR ($"+String(format: "%02X",za)+",X)")
    }
    
    func  OR_indirect_indexed_y() // 11
    {
        
        let adr = getIndirectY()
        let v = memory.ReadAddress(address: adr)
        A = A | v
        SetFlags(value: A)
        prn("OR ($"+String(format: "%02X",adr - UInt16(Y))+"),Y")
    }
    
    // Accumulator EOR
    
    func  EOR_i() // 49
    {
        let v = getImmediate()
        A = A ^ v
        SetFlags(value: A)
        prn("EOR #$"+String(format: "%02X",v))
    }
    
    func  EOR_z() // 45
    {
        let ad = memory.ReadAddress(address: PC) ; incPC()
        let v = memory.ReadAddress(address: UInt16(ad))
        A = A ^ v
        SetFlags(value: A)
        prn("EOR $"+String(format: "%02X",ad))
    }
    
    func  EOR_zx() // 55
    {
        let z = memory.ReadAddress(address: PC)
        let ad = getZeroPageX()
        let v = memory.ReadAddress(address: ad)
        A = A ^ v
        SetFlags(value: A)
        prn("EOR $"+String(format: "%02X",z)+",X")
    }
    
    func  EOR_a() // 4D
    {
        let ad = getAbsoluteAddress()
        let v = memory.ReadAddress(address: UInt16(ad))
        A = A ^ v
        SetFlags(value: A)
        prn("EOR $"+String(format: "%04X",ad))
    }
    
    func  EOR_indexed_x() // 5d
    {
        let ad = getAbsoluteX()
        let v = memory.ReadAddress(address: ad)
        A = A ^ v
        SetFlags(value: A)
        prn("EOR $"+String(format: "%04X",ad &- UInt16(X))+",X")
    }
    
    func  EOR_indexed_y() // 59
    {
        let ad = getAbsoluteY()
        let v = memory.ReadAddress(address:  ad)
        A = A ^ v
        SetFlags(value: A)
        prn("EOR $"+String(format: "%04X",ad - UInt16(Y))+",Y")
    }
    
    func  EOR_indexed_indirect_x() // 41
    {
        let za = memory.ReadAddress(address: PC );
        let v = get_indexed_indirect_zp_x()
        A = A ^ v
        SetFlags(value: A)
        prn("EOR ($"+String(format: "%02X",za)+",X)")
    }
    
    func  EOR_indirect_indexed_y() // 51
    {
        let adr = getIndirectY()
        let v = memory.ReadAddress(address: adr)
        A = A ^ v
        SetFlags(value: A)
        prn("EOR ($"+String(format: "%02X",adr - UInt16(Y))+"),Y")
        
    }
    
    
    
    // ASL
    
    func  ASL_i() // 0A
    {
        CARRY_FLAG = ((A & 128) == 128)
        A = A << 1
        SetFlags(value: A)
        prn("ASL")
    }
    
    func  ASL_z() // 06
    {
        let za = memory.ReadAddress(address: PC)
        var v = memory.ReadAddress(address: UInt16(za))
        CARRY_FLAG = ((v & 128) == 128)
        v = v << 1
        memory.WriteAddress(address: UInt16(za), value: v)
        incPC()
        SetFlags(value: v)
        prn("ASL $"+String(format: "%02X",za))
    }
    
    func  ASL_zx() // 16
    {
        let z = memory.ReadAddress(address: PC)
        let ad = getZeroPageX()
        var v = memory.ReadAddress(address: ad)
        CARRY_FLAG = ((v & 128) == 128)
        v = v << 1
        memory.WriteAddress(address:ad, value: v)
        SetFlags(value: v)
        prn("ASL $"+String(format: "%02X",z)+",X")
    }
    
    func  ASL_a() // 0E
    {
        let ad = getAbsoluteAddress()
        var v = memory.ReadAddress(address: UInt16(ad))
        CARRY_FLAG = ((v & 128) == 128)
        v = v << 1
        memory.WriteAddress(address: ad, value: v)
        SetFlags(value: v)
        prn("ASL $"+String(format: "%04X",ad))
    }
    
    func  ASL_indexed_x() // 1E
    {
        let ad = getAbsoluteX()
        var v = memory.ReadAddress(address:  ad)
        CARRY_FLAG = ((v & 128) == 128)
        v = v << 1
        memory.WriteAddress(address: ad, value: v)
        SetFlags(value: v)
        prn("ASL $"+String(format: "%04X",ad &- UInt16(X))+",X")
    }
    
    
    
    // ROL
    
    func  ROL_i() // 2a
    {
        let msb = ((A & 128) == 128)
        A = A << 1
        A = A | (CARRY_FLAG ? 1 : 0)
        SetFlags(value: A)
        CARRY_FLAG = msb
        prn("ROL A")
    }
    
    func  ROL_z() // 26
    {
        let ad = memory.ReadAddress(address: PC); incPC()
        var v = memory.ReadAddress(address: UInt16(ad))
        let msb = ((v & 128) == 128)
        v = v << 1
        v = v | (CARRY_FLAG ? 1 : 0)
        memory.WriteAddress(address: UInt16(ad), value: v)
        SetFlags(value: v)
        CARRY_FLAG = msb
        prn("ROL $"+String(format: "%02X",ad))
    }
    
    func  ROL_zx() // 36
    {
        let z = memory.ReadAddress(address: PC)
        let ad = getZeroPageX()
        var v = memory.ReadAddress(address: ad)
        
        let msb = ((v & 128) == 128)
        v = v << 1
        v = v | (CARRY_FLAG ? 1 : 0)
        memory.WriteAddress(address: ad, value: v)
        SetFlags(value: v)
        CARRY_FLAG = msb
        prn("ROL $"+String(format: "%02X",z)+",X")
    }
    
    func  ROL_a() // 2E
    {
        let ad = getAbsoluteAddress()
        var v = memory.ReadAddress(address: UInt16(ad))
        let msb = ((v & 128) == 128)
        v = v << 1
        v = v | (CARRY_FLAG ? 1 : 0)
        memory.WriteAddress(address: ad, value: v)
        SetFlags(value: v)
        CARRY_FLAG = msb
        prn("ROL $"+String(format: "%04X",ad))
    }
    
    func  ROL_indexed_x() // 3E
    {
        let ad = getAbsoluteX()
        var v = memory.ReadAddress(address: ad)
        let msb = ((v & 128) == 128)
        v = v << 1
        v = v | (CARRY_FLAG ? 1 : 0)
        memory.WriteAddress(address: ad, value: v)
        SetFlags(value: v)
        CARRY_FLAG = msb
        prn("ROL $"+String(format: "%04X",ad &- UInt16(X))+",X")
    }
    
    // ROR
    
    func  ROR_i() // 6A
    {
        let lsb = ((A & 1) == 1)
        A = A >> 1
        A = A | (CARRY_FLAG ? 128 : 0)
        SetFlags(value: A)
        CARRY_FLAG = lsb
        prn("ROR A")
    }
    
    func  ROR_z() // 66
    {
        let ad = memory.ReadAddress(address: PC); incPC()
        var v = memory.ReadAddress(address: UInt16(ad))
        let lsb = ((v & 1) == 1)
        v = v >> 1
        v = v | (CARRY_FLAG ? 128 : 0)
        memory.WriteAddress(address: UInt16(ad), value: v)
        SetFlags(value: v)
        CARRY_FLAG = lsb
        prn("ROR $"+String(format: "%02X",ad))
    }
    
    func  ROR_zx() // 76
    {
        let z = memory.ReadAddress(address: PC)
        let ad = getZeroPageX()
        var v = memory.ReadAddress(address: ad)
        
        let lsb = ((v & 1) == 1)
        v = v >> 1
        v = v | (CARRY_FLAG ? 128 : 0)
        memory.WriteAddress(address: ad, value: v)
        SetFlags(value: v)
        CARRY_FLAG = lsb
        prn("ROR $"+String(format: "%02X",z)+",X")
    }
    
    func  ROR_a() // 6E
    {
        let ad = getAbsoluteAddress()
        var v = memory.ReadAddress(address: UInt16(ad))
        let lsb = ((v & 1) == 1)
        v = v >> 1
        v = v | (CARRY_FLAG ? 128 : 0)
        memory.WriteAddress(address: ad, value: v)
        SetFlags(value: v)
        CARRY_FLAG = lsb
        prn("ROR $"+String(format: "%04X",ad))
    }
    
    func  ROR_indexed_x() // 7E
    {
        let ad = getAbsoluteX()
        var v = memory.ReadAddress(address: ad)
        let lsb = ((v & 1) == 1)
        v = v >> 1
        v = v | (CARRY_FLAG ? 128 : 0)
        memory.WriteAddress(address: ad, value: v)
        SetFlags(value: v)
        CARRY_FLAG = lsb
        prn("ROR $"+String(format: "%04X",ad &- UInt16(X))+",X")
    }
    
    
    // Store registers in memory
    
    func STX_z() // 86
    {
        let zero_page_address = memory.ReadAddress(address: PC) ; incPC()
        memory.WriteAddress(address: UInt16(zero_page_address), value: X)
        prn("STX $" + String(format: "%02X",zero_page_address))
    }
    
    func STX_a() // 8e
    {
        let ad = getAbsoluteAddress()
        memory.WriteAddress(address: UInt16(ad), value: X)
        prn("STX $" + String(format: "%04X",ad))
    }
    
    func STX_ya() // 96
    {
        let adr = getZeroPageY()
        memory.WriteAddress(address: adr, value: X)
        prn("STX $#" + String(format: "%02X",adr &- UInt16(Y)) + ",Y")
    }
    
    
    func STY_z() // 84
    {
        let zero_page_address = memory.ReadAddress(address: PC) ; incPC()
        memory.WriteAddress(address: UInt16(zero_page_address), value: Y)
        prn("STY $" + String(format: "%02X",zero_page_address))
    }
    
    func STY_a() // 8c
    {
        let ad = getAbsoluteAddress()
        memory.WriteAddress(address: UInt16(ad), value: Y)
        prn("STY $" + String(format: "%04X",ad))
    }
    
    func STY_xa() // 94
    {
        let z = memory.ReadAddress(address: PC)
        let ad = getZeroPageX()
        memory.WriteAddress(address: ad, value: Y)
        prn("STY $#" + String(format: "%02X",z) + ",X")
    }
    
    
    
    // Swapping between registers
    
    func TAX() // AA
    {
        X = A
        SetFlags(value: X)
        prn("TAX")
    }
    
    func TAY() // A8
    {
        Y = A
        SetFlags(value: Y)
        prn("TAY")
    }
    
    func TSX() //BA
    {
        X = SP
        SetFlags(value: X)
        prn("TSX")
    }
    
    func TXA() // 8A
    {
        A = X
        SetFlags(value: A)
        prn("TXA")
    }
    
    func TXS() //9A
    {
        SP = X
        prn("TXS")
    }
    
    func TYA() // 98
    {
        A = Y
        SetFlags(value: A)
        prn("TYA")
    }
    
    
    
    
    // Stack
    
    //  ....pushes
    
    func PHA() // 48
    {
        push(A)
        prn("PHA")
    }
    
    func PHP() // 08
    {
        // Always push status with B bit set (bit 4) and U bit (bit 5) set on stack as CPU 6502 does
        let sr = GetStatusRegister() | 0x30
        push(sr)
        prn("PHP")
    }
    
    // 65c02 only
    func PHX() // DA
    {
        push(X)
        prn("PHX")
    }
    
    // 65c02 only
    func PHY() // 5A
    {
        push(Y)
        prn("PHY")
    }
    
    
    // .....pulls
    
    func PLA() // 68
    {
        A = pop()
        SetFlags(value: A)
        
        prn("PLA")
    }
    
    
    
    
    func PLP() // 28
    {
        let p = pop()
        // Always set bit 5 (unused) when loading status register
       
        SetStatusRegister(reg: p | 0x20)
        // Do not update BREAK_FLAG from pulled value; BREAK_FLAG is not stored internally
        BREAK_FLAG = false
        prn("PLP")
    }
    
    // 65c02 only
    func PLX() // FA
    {
        X = pop()
        SetFlags(value: X)
        prn("PLX")
    }
    
    // 65c02 only
    func PLY() // 7A
    {
        Y = pop()
        SetFlags(value: Y)
        prn("PLY")
    }
    
    
    // Flags
    
    func CLI() // 58
    {
        INTERRUPT_DISABLE = false
        prn("CLI")
    }
    
    func SEC() // 38
    {
        CARRY_FLAG = true
        prn("SEC")
    }
    
    func SED() // F8
    {
        DECIMAL_MODE = true
        prn("SED")
    }
    
    func SEI() //78
    {
        INTERRUPT_DISABLE = true
        prn("SEI")
    }
    
    func CLC()
    {
        CARRY_FLAG = false
        prn("CLC")
    }
    
    func CLV() // B8
    {
        OVERFLOW_FLAG = false
        prn("CLV")
    }
    
    func CLD() // d8
    {
        DECIMAL_MODE = false
        prn("CLD")
    }
    
    // Increment & Decrement - they don't care about Decimal Mode
    
    func INY() // CB
    {
        Y = Y &+ 1
        

        SetFlags(value: Y)
        prn("INY")
    }
    
    func INX() // E8
    {
        X = X &+ 1
        
        SetFlags(value: X)
        prn("INX")
    }
    
    func INC_A() // 1A (65C02)
    {
        A = A &+ 1
        SetFlags(value: A)
        prn("INC A")
    }
    
    func DEC_A() // 3A (65C02)
    {
        A = A &- 1
        SetFlags(value: A)
        prn("DEC A")
    }
    
    func DEX() // CA
    {
        X = X &- 1
        

        SetFlags(value: X)
        prn("DEX")
    }
    
    func DEY() // 88
    {
        Y = Y &- 1
        

        SetFlags(value: Y)
        prn("DEY")
    }
    
    
    // Memory dec and inc
    
    func  DEC_z() // C6
    {
        let v = memory.ReadAddress(address: PC) ; incPC()
        var t = memory.ReadAddress(address: UInt16(v))
        t = t &- 1
        memory.WriteAddress(address: UInt16(v), value: t)
        SetFlags(value: t)
        prn("DEC $"+String(format: "%02X",v))
    }
    
    func  DEC_zx() // D6
    {
        let ad = getZeroPageX()
        var t = memory.ReadAddress(address: ad)
        t = t &- 1
        memory.WriteAddress(address: ad, value: t)
        SetFlags(value: t)
        prn("DEC $"+String(format: "%02X",ad - UInt16(X))+",X")
    }
    
    func DEC_a() // CE
    {
        let v = getAbsoluteAddress()
        var t = memory.ReadAddress(address: v)
        t = t &- 1
        memory.WriteAddress(address: v, value: t)
        SetFlags(value: t)
        prn("DEC $"+String(format: "%02X",v))
    }
    
    func DEC_ax() // DE
    {
        let v = getAbsoluteAddress()
        var t = memory.ReadAddress(address: v + UInt16(X))
        t = t &- 1
        memory.WriteAddress(address: v + UInt16(X), value: t)
        SetFlags(value: t)
        prn("DEC $"+String(format: "%04X",v)+",X")
    }
    
    
    func  INC_z() // E6
    {
        let v = memory.ReadAddress(address: PC) ; incPC()
        var t = memory.ReadAddress(address: UInt16(v))
        t = t &+ 1
        memory.WriteAddress(address: UInt16(v), value: t)
        SetFlags(value: t)
        prn("INC $"+String(format: "%02X",v))
    }
    
    func  INC_zx() // F6
    {
        let ad = getZeroPageX()
        var t = memory.ReadAddress(address: ad)
        t = t &+ 1
        memory.WriteAddress(address: ad, value: t)
        SetFlags(value: t)
        prn("INC $"+String(format: "%02X",ad - UInt16(X))+",X")
    }
    
    func INC_a() // EE
    {
        let v = getAbsoluteAddress()
        var t = memory.ReadAddress(address: v)
        t = t &+ 1
        memory.WriteAddress(address: v, value: t)
        SetFlags(value: t)
        prn("INC $"+String(format: "%04X",v))
    }
    
    func INC_ax() // FE
    {
        let v = getAbsoluteAddress()
        var t = memory.ReadAddress(address: v + UInt16(X))
        t = t &+ 1
        memory.WriteAddress(address: v + UInt16(X), value: t)
        SetFlags(value: t)
        prn("INC $"+String(format: "%04X",v)+",X")
    }
    
    
    // Branching
    
    func PerformRelativeAddress( jump : UInt8)
    {
        // Signed 8-bit offset with wrapping addition
        let offset = Int32(Int8(bitPattern: jump))
        let newPC = (Int32(PC) &+ offset) & 0xFFFF
        PC = UInt16(truncatingIfNeeded: newPC)
    }
    
    
    func BRA() // 80
    {
        let t = memory.ReadAddress(address: PC); incPC()
        PerformRelativeAddress(jump: t)
        prn("BRA $" + String(format: "%02X", t))
    }
    
    func BPL() // 10
    {
        let t = memory.ReadAddress(address: PC) ; incPC()
        
        if NEGATIVE_FLAG == false
        {
            PerformRelativeAddress(jump: t)
        }
        prn("BPL $" + String(format: "%02X",t) + ":" + String(format: "%04X",PC))
    }
    
    func BMI() // 30
    {
        let t = memory.ReadAddress(address: PC) ; incPC()
        if NEGATIVE_FLAG == true
        {
            PerformRelativeAddress(jump: t)
        }
        prn("BMI $" + String(format: "%02X",t) + ":" + String(format: "%04X",PC))
    }
    
    func BVC() // 50
    {
        let t = (memory.ReadAddress(address: PC)) ; incPC()
        if !OVERFLOW_FLAG
        {
            PerformRelativeAddress(jump: t)
        }
        prn("BVC $" + String(format: "%02X", t))
    }
    
    func BVS() // 70
    {
        let t = (memory.ReadAddress(address: PC)) ; incPC()
        if OVERFLOW_FLAG
        {
            PerformRelativeAddress(jump: t)
        }
        prn("BVS $" + String(format: "%02X", t))
    }
    
    func BCC() // 90
    {
        let t = (memory.ReadAddress(address: PC)) ; incPC()
        if !CARRY_FLAG
        {
            PerformRelativeAddress(jump: t)
        }
        prn("BCC $" + String(format: "%02X",t))
    }
    
    func BCS() // B0
    {
        let t = (memory.ReadAddress(address: PC)) ; incPC()
        if CARRY_FLAG
        {
            PerformRelativeAddress(jump: t)
        }
        prn("BCS $" + String(format: "%02X",t))
    }
    
    func BEQ() // F0
    {
        let t = (memory.ReadAddress(address: PC)) ; incPC()
        if ZERO_FLAG
        {
            PerformRelativeAddress(jump: t)
        }
        prn("BEQ $" + String(format: "%02X",t))
    }
    
    func BNE() // D0
    {
        let t = (memory.ReadAddress(address: PC)) ; incPC()
        if !ZERO_FLAG
        {
            PerformRelativeAddress(jump: t)
        }
        prn("BNE $" + String(format: "%02X",t))
    }
    
    
    // Jumping
    
    func JMP_ABS() // 4c
    {
        let ad = getAbsoluteAddress()
        PC = ad
        prn("JMP $" + String(format: "%04X",ad))
    }
    
    // 6502 JMP indirect jump bug emulation:
    // If low byte of indirect address is 0xFF, high byte is fetched from address & 0xFF00
    func JMP_INDIRECT() // 6c
    {
        let ad = getAbsoluteAddress()
        // Emulate 6502 indirect JMP bug:
        let l = UInt16(memory.ReadAddress(address: ad))
        let haddr: UInt16
        if (ad & 0x00FF) == 0x00FF {
            // If low byte is 0xFF, fetch high byte from address & 0xFF00 (wrap around page)
            haddr = ad & 0xFF00
        } else {
            haddr = ad &+ 1
        }
        let h = UInt16(memory.ReadAddress(address: haddr))
        let target = (h << 8) | l
        PC = target
    
        prn("JMP $" + String(format: "%04X", PC))
    }
    
    
    func JSR() // 20
    {
        // updated to push the H byte first, as per actual 6502!
        
        let h = (PC+1) >> 8
        let l = (PC+1) & 0xff
        
        let target = getAbsoluteAddress()
        
        push(UInt8(h))
        push(UInt8(l))
        
        PC = target
        
        prn("JSR $" + String(format: "%04X",target))
    }
    
    func RTS() // 60
    {
        let l = UInt16(pop())
        let h = UInt16(pop())
        PC = 1 + (h<<8) &+ l
        prn("RTS")
    }
    
    // Utilities called by various opcodes
    
    // Addressing modes
    
    func getAbsoluteX() -> UInt16
    {
        let ad = getAbsoluteAddress() &+ UInt16(X)
        return ad
    }
    
    func getAbsoluteY() -> UInt16
    {
        let ad = getAbsoluteAddress() &+ UInt16(Y)
        return ad
    }
    
    func getImmediate() -> UInt8
    {
        let v = memory.ReadAddress(address: PC)
        incPC()
        return v
    }
    
    func getZeroPageX() -> UInt16
    {
        let adr = UInt16(memory.ReadAddress(address: PC)) + UInt16(X)
        incPC()
        return (adr & 0xff)
    }
    
    func getZeroPageY() -> UInt16
    {
        let adr = UInt16(memory.ReadAddress(address: PC)) + UInt16(Y)
        incPC()
        return (adr & 0xff)
    }
    
    
    func getIndirectY() -> UInt16  // (indirect),Y // Indexed_Indirect_Y
    {
        
        let ial = UInt16(memory.ReadAddress(address: PC)) ;  incPC()
        let bal = UInt16(memory.ReadAddress(address:(UInt16(0xFF & ial))))
        let bah = UInt16(memory.ReadAddress(address:(UInt16(0xFF & ( ial &+ 1)))))
           
        let  ea = bah << 8 &+ bal &+ UInt16(Y)
        
        return ea
        
    }
    
    func get_indexed_indirect_zp_x_address() -> UInt16
    { /// 01, 21, 41, 61, 81, a1, c1, e1,
        let fi = memory.ReadAddress(address: PC); incPC()
        let bal : UInt16 = UInt16(fi) + UInt16(X)
        let adl = UInt16(memory.ReadAddress(address: 0xFF & bal))
        let adh = UInt16(memory.ReadAddress(address: 0xFF & (bal+1)))
        let adr = (adh << 8) + adl
        return adr
        
    }
    
    func get_indexed_indirect_zp_x() -> UInt8
    { /// 01, 21, 41, 61, 81, a1, c1, e1,
        return memory.ReadAddress(address: get_indexed_indirect_zp_x_address())
    }
    
    
    func push(_ v : UInt8)
    {
        memory.WriteAddress(address: UInt16(0x100 + UInt16(SP)), value: v)
        SP = SP &- 1
    }
    
    func pop() -> UInt8
    {
        SP = SP &+ 1
        let v = memory.ReadAddress(address: UInt16(0x100 + UInt16(SP)))
        return v
    }
    
    
    
    // Updated 6502 ADC decimal mode emulation (BCD)
    //
    // This implementation emulates the 6502's binary-coded decimal addition.
    // It performs binary addition first, then applies decimal correction if decimal mode is set.
    // The carry, zero, negative, and overflow flags are updated accordingly.
    //
    // Reference: 6502 decimal mode operation as per official documentation.
    //
    func addC( _ n2: UInt8)
    {
        let carryIn = CARRY_FLAG ? 1 : 0
        let operandA = A
        let operandB = n2
        
        if DECIMAL_MODE {
            // Perform binary addition including carry
            let binarySum = UInt16(operandA) + UInt16(operandB) + UInt16(carryIn)
            var result = UInt8(binarySum & 0xFF)
            
            // Calculate decimal correction
            var correction: UInt16 = 0
            
            // Lower nibble correction
            if ((operandA & 0x0F) + (operandB & 0x0F) + UInt8(carryIn)) > 9 {
                correction += 0x06
            }
            // Upper nibble correction
            if binarySum > 0x99 {
                correction += 0x60
            }
            
            // Apply correction to binary sum
            let correctedSum = binarySum + correction
            
            // Set carry flag if decimal carry out occurred
            CARRY_FLAG = correctedSum > 0xFF
            
            result = UInt8(correctedSum & 0xFF)
            
            // Set zero flag
            ZERO_FLAG = (result == 0)
            
            // Set negative flag
            NEGATIVE_FLAG = (result & 0x80) != 0
            
            // Overflow flag is set if sign bit overflow in binary addition (before decimal correction)
            let overflowCalc = (~(operandA ^ operandB) & (operandA ^ UInt8(truncatingIfNeeded: binarySum))) & 0x80
            OVERFLOW_FLAG = overflowCalc != 0
            
            A = result
            
            return
        }
        else {
            // Binary mode addition (unchanged)
            let total = UInt16(operandA) + UInt16(operandB) + UInt16(carryIn)
            
            CARRY_FLAG = total > 0xFF
            
            let result = UInt8(total & 0xFF)
            
            // Set zero flag
            ZERO_FLAG = (result == 0)
            
            // Set negative flag
            NEGATIVE_FLAG = (result & 0x80) != 0
            
            // Overflow flag: set if sign bit overflow in addition
            let overflowCalc = (~(operandA ^ operandB) & (operandA ^ result)) & 0x80
            OVERFLOW_FLAG = overflowCalc != 0
            
            A = result
            
            return
        }
    }
    
    // Updated 6502 SBC decimal mode emulation (BCD)
    //
    // This implementation emulates the 6502's binary-coded decimal subtraction.
    // It performs binary subtraction first, then applies decimal correction if decimal mode is set.
    // The carry, zero, negative, and overflow flags are updated accordingly.
    //
    // Reference: 6502 decimal mode operation as per official documentation.
    //
    func subC( _ n2: UInt8)
    {
        let carryIn = CARRY_FLAG ? 0 : 1  // Inverted carry for borrow in subtraction
        let operandA = A
        let operandB = n2
        
        if DECIMAL_MODE {
            // Perform binary subtraction with borrow
            var binaryDiff = Int16(operandA) - Int16(operandB) - Int16(carryIn)
            
            // Save pre-corrected result for flag calculations
            //let preCorrectedResult = UInt8(binaryDiff & 0xFF)
            
            // Calculate decimal correction
            var correction: Int16 = 0
            
            // Lower nibble
            let lowNibbleA = Int16(operandA & 0x0F)
            let lowNibbleB = Int16(operandB & 0x0F) + Int16(carryIn)
            if lowNibbleA < lowNibbleB {
                correction -= 6
            }
            
            // Upper nibble
            let highNibbleA = Int16((operandA >> 4) & 0x0F)
            let highNibbleB = Int16((operandB >> 4) & 0x0F)
            let borrowFromLow = (lowNibbleA < lowNibbleB) ? 1 : 0
            
            if highNibbleA < (highNibbleB + Int16(borrowFromLow)) {
                correction -= 0x60
            }
            
            binaryDiff += correction
            
            // Carry flag set if no borrow (i.e., if subtraction did NOT go below zero)
            CARRY_FLAG = binaryDiff >= 0
            
            let result = UInt8(binaryDiff & 0xFF)
            
            // Set zero flag
            ZERO_FLAG = (result == 0)
            
            // Set negative flag
            NEGATIVE_FLAG = (result & 0x80) != 0
            
            // Overflow flag is set if signed overflow in subtraction (before decimal correction)
            let overflowCalc = ((operandA ^ operandB) & (operandA ^ result)) & 0x80
            OVERFLOW_FLAG = overflowCalc != 0
            
            A = result
            
            return
        }
        else {
            // Binary mode subtraction (unchanged)
            let total = UInt16(operandA) &- UInt16(operandB) &- UInt16(carryIn)
            let result = UInt8(total & 0xFF)
            
            // Carry flag set if no borrow (total >= 0)
            CARRY_FLAG = total <= 0xFF
            
            // Set zero flag
            ZERO_FLAG = (result == 0)
            
            // Set negative flag
            NEGATIVE_FLAG = (result & 0x80) != 0
            
            // Overflow flag is set if signed overflow in subtraction
            let overflowCalc = ((operandA ^ operandB) & (operandA ^ result)) & 0x80
            OVERFLOW_FLAG = overflowCalc != 0
            
            A = result
            
            return
        }
    }
    
    
    // Helped because there was no checking that PC didn't wrap. Oops.
    func incPC()
    {
        PC &+= 1
    }
    
    
    func getAbsoluteAddress() -> UInt16
    {
        // Get 16 bit address from current PC
        let l = UInt16(memory.ReadAddress(address: PC))
        incPC()
        let h = UInt16(memory.ReadAddress(address: PC))
        incPC()
        return  UInt16(h<<8 | l)
    }
    
    func getAddress(_ addr : UInt16) -> UInt16
    {
        // Get 16 bit address stored at the supplied address
        let l = UInt16(memory.ReadAddress(address: addr))
        let h = UInt16(memory.ReadAddress(address: UInt16((Int(addr) + 1) & 0xffff)))
        let ad = Int(h<<8 | l)
        return  UInt16(ad & 0xffff)
    }
    
    func SetFlags(value : UInt8)
    {
        if value == 0
        {
            ZERO_FLAG = true
        }
        else
        {
            ZERO_FLAG = false
        }
        
        if (value & 0x80) == 0x80
        {
            NEGATIVE_FLAG = true
        }
        else
        {
            NEGATIVE_FLAG = false
        }
        
    }
    
    
    // Called by the UI to pass on keyboard status
    // so that the CPU could query it.
    
    func SetKeypress(keyPress : Bool, keyNum : UInt8)
    {
        kim_keyActive = keyPress
        kim_keyNumber = keyNum
        if keyNum <= 0x0F {
            let row = Int(keyNum / 4)
            let col = Int(keyNum % 4)
            memory.setRIOTKeypadPressed(row: row, col: col, pressed: keyPress)
        } else if !keyPress {
            memory.setRIOTKeypadPressed(row: 0, col: 0, pressed: false)
        }
    }
    

   
    
    // Debug message utility
    func prn(_ message : String)
    {
        let ins = String(message).padding(toLength: 12, withPad: " ", startingAt: 0)
        statusmessage = ins
    }
}
