//
//  VirtualKimTests.swift
//  VirtualKimTests
//
//  Created by John Kennedy on 1/8/21.
//

import XCTest
@testable import Emulator6502

class Emulator6502Tests: XCTestCase {
    
    let MOS6502 = CPU()

    override func setUpWithError() throws {
        MOS6502.Init(ProgramName: "", computer: "KIM1")
        MOS6502.RESET()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    
    func testBranching()
    {
     

     // Backward branching
//
//        .ORG    $200
//      LOOP:
//                  BNE     loop
//      LOOP2:
//                  BNE     loop
//                  BRK
//

        
     MOS6502.Write(address: 0x200, byte: 0xD0) // BNE FE
     MOS6502.Write(address: 0x201, byte: 0xfe) //
    
     MOS6502.Write(address: 0x202, byte: 0xD0) // BNE FC
     MOS6502.Write(address: 0x203, byte: 0xfc) //
       
     MOS6502.SetPC(ProgramCounter: 0x202)
     MOS6502.Execute()
     XCTAssertFalse((MOS6502.GetPC() != 0x200), "Bad Branch")
        
     MOS6502.Execute()
    XCTAssertFalse((MOS6502.GetPC() != 0x200), "Bad Branch")
        
       
        
     // Forward branching
   
        
    MOS6502.SetPC(ProgramCounter: 0x200)
        
    MOS6502.Write(address: 0x200, byte: 0xf0) // BEQ
     MOS6502.Write(address: 0x201, byte: 0xfe) // fe
     MOS6502.Execute()
     XCTAssertFalse((MOS6502.GetPC() != 0x202), "Bad Branch")

     MOS6502.Write(address: 0x202, byte: 0xf0) // BEQ
     MOS6502.Write(address: 0x203, byte: 0x00) // 00
     MOS6502.Execute()
     XCTAssertFalse((MOS6502.GetPC() != 0x204), "Bad Branch")
           
        
        
    }

    func testAddition()
    {
     
     MOS6502.SetPC(ProgramCounter: 0x200)
     
     // Load data
     MOS6502.Write(address: 0x10, byte: 0x10)
     MOS6502.Write(address: 0x11, byte: 0x20)
     MOS6502.Write(address: 0x12, byte: 0x30)
     
     // ADD_I
     MOS6502.Write(address: 0x200, byte: 0xA9) // LDA
     MOS6502.Write(address: 0x201, byte: 0x40) // 40
     MOS6502.Execute()
     XCTAssertFalse((MOS6502.getA() != 0x40), "Bad A")
     
    MOS6502.Write(address: 0x202, byte: 0xD8) // CLD
    MOS6502.Execute()
     
     MOS6502.Write(address: 0x203, byte: 0x18) // CLC
     MOS6502.Execute()
     
     MOS6502.Write(address: 0x204, byte: 0x69) // ADC
     MOS6502.Write(address: 0x205, byte: 0x10) // #$10 i.e. A = A + $10
     
     MOS6502.Execute()
     XCTAssertFalse((MOS6502.getA() != 0x50), "Bad A")
     
     // ADD_I - Decimal
     MOS6502.SetPC(ProgramCounter: 0x200)
     
     MOS6502.Write(address: 0x200, byte: 0xA9) // LDA
     MOS6502.Write(address: 0x201, byte: 0x40) // 40
     MOS6502.Execute()
     XCTAssertFalse((MOS6502.getA() != 0x40), "Bad A")
     
     MOS6502.Write(address: 0x202, byte: 0x18) // CLC
     MOS6502.Execute()
     
     MOS6502.Write(address: 0x203, byte: 0xf8) // SED
     MOS6502.Execute()
     
     MOS6502.Write(address: 0x204, byte: 0x69) // ADC
     MOS6502.Write(address: 0x205, byte: 0x10) // #$10 i.e. A = A + $10
     
     MOS6502.Execute()
       
     XCTAssertFalse((MOS6502.getA() != 0x50), "Bad A")
        
        
        // Add Absolute
        
        MOS6502.SetPC(ProgramCounter: 0x200)
        
        MOS6502.Write(address: 0x200, byte: 0xA9) // LDA
        MOS6502.Write(address: 0x201, byte: 0x40) // 40
        MOS6502.Execute()
        XCTAssertFalse((MOS6502.getA() != 0x40), "Bad A")
        
        MOS6502.Write(address: 0x202, byte: 0xD8) // CLD
        MOS6502.Execute()
         
         MOS6502.Write(address: 0x203, byte: 0x18) // CLC
         MOS6502.Execute()
        
        MOS6502.Write(address: 0x204, byte: 0x6d) // ADC
        MOS6502.Write(address: 0x205, byte: 0x10) // $12 A = A + value stored in $0010 which is $10
        MOS6502.Write(address: 0x206, byte: 0x00) // $12 A = A + value stored in $0010 which is $10
        MOS6502.Execute()
        
        print(MOS6502.getA())
        
        XCTAssertFalse((MOS6502.getA() != 0x50), "Bad A")
        
    
    }
     
        
        
        
   func testSubtraction()
   {
    
    // THESE FAIL BECAUSE ANSWERS WERE BASED ON A BUGGY ONLINE EMULATOR! *slaps head*
    
    MOS6502.SetPC(ProgramCounter: 0x200)
    
    // Load data
    MOS6502.Write(address: 0x10, byte: 0x10)
    MOS6502.Write(address: 0x11, byte: 0x20)
    MOS6502.Write(address: 0x12, byte: 0x30)
    
    // SUB_I
    MOS6502.Write(address: 0x200, byte: 0xA9) // LDA
    MOS6502.Write(address: 0x201, byte: 0x40) // 40
    MOS6502.Execute()
    XCTAssertFalse((MOS6502.getA() != 0x40), "Bad A")
    
    MOS6502.Write(address: 0x202, byte: 0x38) // SEC
    MOS6502.Execute()
    
    MOS6502.Write(address: 0x203, byte: 0xD8) // CLD
    MOS6502.Execute()
    
    MOS6502.Write(address: 0x204, byte: 0xe9) // SBC
    MOS6502.Write(address: 0x205, byte: 0x10) // #$10 i.e. A = A - $10
    
    MOS6502.Execute()
    XCTAssertFalse((MOS6502.getA() != 0x30), "Bad A")
    
    // SUB_I - Decimal
    MOS6502.SetPC(ProgramCounter: 0x200)
    
    MOS6502.Write(address: 0x200, byte: 0xA9) // LDA
    MOS6502.Write(address: 0x201, byte: 0x40) // 40
    MOS6502.Execute()
    XCTAssertFalse((MOS6502.getA() != 0x40), "Bad A")
    
    MOS6502.Write(address: 0x202, byte: 0x38) // SEC
    MOS6502.Execute()
    
    MOS6502.Write(address: 0x203, byte: 0xf8) // SED
    MOS6502.Execute()
    
    MOS6502.Write(address: 0x204, byte: 0xe9) // SBC
    MOS6502.Write(address: 0x205, byte: 0x10) // #$10 i.e. A = A - $10
    
    MOS6502.Execute()
    XCTAssertFalse((MOS6502.getA() != 0x30), "Bad A")
    
   
    
    
    
    // SUB_Z
    
    MOS6502.SetPC(ProgramCounter: 0x200)
    
    MOS6502.Write(address: 0x200, byte: 0xA9) // LDA
    MOS6502.Write(address: 0x201, byte: 0x40) // 40
    MOS6502.Execute()
    XCTAssertFalse((MOS6502.getA() != 0x40), "Bad A")
    
    MOS6502.Write(address: 0x202, byte: 0x38) // SEC
    MOS6502.Execute()
    
    MOS6502.Write(address: 0x203, byte: 0xD8) // CLD
    MOS6502.Execute()
    
    MOS6502.Write(address: 0x204, byte: 0xe5) // SBC
    MOS6502.Write(address: 0x205, byte: 0x11) // $11 A = A - value stored in $11 which is $20
    
    MOS6502.Execute()
    XCTAssertFalse((MOS6502.getA() != 0x20), "Bad A")
    
    
    
    // SUB_Absolute
    
    MOS6502.SetPC(ProgramCounter: 0x200)
    
    MOS6502.Write(address: 0x200, byte: 0xA9) // LDA
    MOS6502.Write(address: 0x201, byte: 0x40) // 40
    MOS6502.Execute()
    XCTAssertFalse((MOS6502.getA() != 0x40), "Bad A")
    
    MOS6502.Write(address: 0x202, byte: 0x38) // SEC
    MOS6502.Execute()
    
    MOS6502.Write(address: 0x203, byte: 0xD8) // CLD
    MOS6502.Execute()
    
    MOS6502.Write(address: 0x204, byte: 0xed) // SBC
    MOS6502.Write(address: 0x205, byte: 0x12) // $12 A = A - value stored in $0012 which is $30
    MOS6502.Write(address: 0x206, byte: 0x00) // $12 A = A - value stored in $0012 which is $30
    
    MOS6502.Execute()
    XCTAssertFalse((MOS6502.getA() != 0x10), "Bad A")
    
    
    
   }
    
    
    
    
    func testSTA() throws {
        
        MOS6502.SetPC(ProgramCounter: 0x200)
        
        // Load data
        MOS6502.Write(address: 0x10, byte: 0x00)
        MOS6502.Write(address: 0x11, byte: 0x00)
        MOS6502.Write(address: 0x12, byte: 0x00)
        
        // STA a
        
        MOS6502.Write(address: 0x200, byte: 0xA9) // LDA
        MOS6502.Write(address: 0x201, byte: 0x42) // 42
        MOS6502.Execute()
        XCTAssertFalse((MOS6502.getA() != 0x42), "Bad A")
        
        MOS6502.Write(address: 0x202, byte: 0x8D) // STA
        MOS6502.Write(address: 0x203, byte: 0x10) // 10
        MOS6502.Write(address: 0x204, byte: 0x00) // 00
        
        MOS6502.Execute()
        
        let a = MOS6502.Read(address: UInt16(0x10))
        XCTAssertTrue(a==0x42, "STA-A OK")
        
        // STA z
        
        MOS6502.SetPC(ProgramCounter: 0x200)
        
        MOS6502.Write(address: 0x200, byte: 0xA9) // LDA
        MOS6502.Write(address: 0x201, byte: 0x43) // 43
        MOS6502.Execute()
        XCTAssertFalse((MOS6502.getA() != 0x43), "Bad A")
        
        MOS6502.Write(address: 0x202, byte: 0x85) // STA
        MOS6502.Write(address: 0x203, byte: 0x10) // 10
        
        MOS6502.Execute()
        
        let az = MOS6502.Read(address: UInt16(0x10))
        XCTAssertTrue(az==0x43, "STA-z OK")
        
        // STA ax
        
        MOS6502.SetPC(ProgramCounter: 0x200)
        
        MOS6502.Write(address: 0x200, byte: 0xA9) // LDA
        MOS6502.Write(address: 0x201, byte: 0x44) // 44
        MOS6502.Execute()
        XCTAssertFalse((MOS6502.getA() != 0x44), "Bad A")
        
        MOS6502.Write(address: 0x202, byte: 0xA2) // ldx_i
        MOS6502.Write(address: 0x203, byte: 0x01) // 1
        MOS6502.Execute()
        XCTAssertFalse((MOS6502.getX() != 0x01), "Bad X")
       
        MOS6502.Write(address: 0x204, byte: 0x9D) // STA
        MOS6502.Write(address: 0x205, byte: 0x10) // 10
        MOS6502.Write(address: 0x206, byte: 0x00) // 00, X
        
        MOS6502.Execute()
        
        let stab = MOS6502.Read(address: UInt16(0x11))
        XCTAssertTrue(stab==0x44, "STA-AX OK")
        
    }
    
    func testDEXDEY() throws {
        
        MOS6502.SetPC(ProgramCounter: 0x200)
        
        MOS6502.Write(address: 0x200, byte: 0xA2) // ldx_i
        MOS6502.Write(address: 0x201, byte: 0xFF) // FF
        MOS6502.Execute()
        XCTAssertFalse((MOS6502.getX() != 0xFF), "Bad X")
        MOS6502.Write(address: 0x202, byte: 0xE8) // x = x + 1
        MOS6502.Execute()
        XCTAssertFalse((MOS6502.getX() != 0x00), "Bad X")
        MOS6502.Write(address: 0x203, byte: 0xCA) // x = x - 1
        MOS6502.Execute()
        XCTAssertFalse((MOS6502.getX() != 0xFF), "Bad X")
        
        MOS6502.SetPC(ProgramCounter: 0x200)
        
        MOS6502.Write(address: 0x200, byte: 0xA0) // ldy_i
        MOS6502.Write(address: 0x201, byte: 0x00) // 0
        MOS6502.Execute()
        XCTAssertFalse((MOS6502.getY() != 0x00), "Bad Y")
        MOS6502.Write(address: 0x202, byte: 0x88) // y = y - 1
        MOS6502.Execute()
        XCTAssertFalse((MOS6502.getY() != 0xFF), "Bad Y")
        MOS6502.Write(address: 0x203, byte: 0xC8) // y = y + 1
        MOS6502.Execute()
        XCTAssertFalse((MOS6502.getY() != 0x00), "Bad 0")
        
        
    }
    
    func testBIT() throws {
        
        // Load data
        MOS6502.Write(address: 0x10, byte: 0x55)
        
        // LDA Immediate
        MOS6502.Write(address: 0x200, byte: 0xA9)
        MOS6502.Write(address: 0x201, byte: 0x96)
        
        MOS6502.SetPC(ProgramCounter: 0x200)
        MOS6502.Execute()
        
        let a = MOS6502.getA()
        XCTAssertTrue(a==0x96, "LDA_I OK")
        
        MOS6502.Write(address: 0x202, byte: 0x2C)
        MOS6502.Write(address: 0x203, byte: 0x10)
        MOS6502.Write(address: 0x204, byte: 0x00)
        
        MOS6502.Execute()
        
        let aa = MOS6502.getA()
        XCTAssertTrue(aa==0x96, "LDA_I OK")
        
        let f = MOS6502.GetStatusRegister() // Should be $40
        print(f)
        XCTAssertTrue((f & 0xC2)==0x40, "BIT")
        
        
        
    }
    
    func testLDA() throws {
        
        // Load data
        MOS6502.Write(address: 0x10, byte: 0x42)
        MOS6502.Write(address: 0x11, byte: 0x43)
        
        // LDA Immediate
        
        MOS6502.Write(address: 0x200, byte: 0xA9)
        MOS6502.Write(address: 0x201, byte: 0x42)
        
        MOS6502.SetPC(ProgramCounter: 0x200)
        MOS6502.Execute()
        
        let a = MOS6502.getA()
        XCTAssertTrue(a==0x42, "LDA_I OK")
        
        // LDA Zero Page
        
        MOS6502.Write(address: 0x200, byte: 0xA5)
        MOS6502.Write(address: 0x201, byte: 0x10)
        
        MOS6502.SetPC(ProgramCounter: 0x200)
        MOS6502.Execute()
        
        let az = MOS6502.getA()
        XCTAssertTrue(az==0x42, "LDA_Z OK")
        
        // LDA Absolute
        
        MOS6502.Write(address: 0x200, byte: 0xAD)
        MOS6502.Write(address: 0x201, byte: 0x10)
        MOS6502.Write(address: 0x202, byte: 0x00)
        
        MOS6502.SetPC(ProgramCounter: 0x200)
        MOS6502.Execute()
        
        let ab = MOS6502.getA()
        
        XCTAssertTrue(ab==0x42, "LDA_A OK")
        
        // LDA Zero Page + X index

        MOS6502.Write(address: 0x200, byte: 0xA2) // ldx_i
        MOS6502.Write(address: 0x201, byte: 0x01) // 1
        MOS6502.Write(address: 0x202, byte: 0xB5) // lda
        MOS6502.Write(address: 0x203, byte: 0x10) // 10,x
       
        MOS6502.SetPC(ProgramCounter: 0x200)
        MOS6502.Execute()
        MOS6502.Execute()

        let azx = MOS6502.getA()
        let x = MOS6502.getX()
        XCTAssertTrue(azx==0x43 && x==1, "LDA_ZX OK")
        
    }
    
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testCMPDoesNotAffectOverflowFlag() throws {
        // CMP/CPX/CPY must NOT modify the overflow flag on a real 6502.
        // Set overflow flag, then do a CMP — it should remain set.
        MOS6502.SetPC(ProgramCounter: 0x200)
        
        // CLV then set overflow via ADC that overflows:
        // LDA #$50, CLC, ADC #$50 → 0xA0 (signed overflow from +80+80=-96)
        MOS6502.Write(address: 0x200, byte: 0xD8) // CLD
        MOS6502.Write(address: 0x201, byte: 0xA9) // LDA #$50
        MOS6502.Write(address: 0x202, byte: 0x50)
        MOS6502.Write(address: 0x203, byte: 0x18) // CLC
        MOS6502.Write(address: 0x204, byte: 0x69) // ADC #$50
        MOS6502.Write(address: 0x205, byte: 0x50)
        
        MOS6502.SetPC(ProgramCounter: 0x200)
        MOS6502.Execute() // CLD
        MOS6502.Execute() // LDA #$50
        MOS6502.Execute() // CLC
        MOS6502.Execute() // ADC #$50 → A=0xA0, V=1
        
        let srBefore = MOS6502.GetStatusRegister()
        XCTAssertTrue((srBefore & 0x40) != 0, "Overflow should be set after ADC overflow")
        
        // Now CMP #$00 — should NOT clear overflow
        MOS6502.Write(address: 0x206, byte: 0xC9) // CMP #$00
        MOS6502.Write(address: 0x207, byte: 0x00)
        MOS6502.Execute() // CMP
        
        let srAfter = MOS6502.GetStatusRegister()
        XCTAssertTrue((srAfter & 0x40) != 0, "CMP must not clear the overflow flag")
    }
    
    func testINC_A_DEC_A() throws {
        // Test 65C02 INC A (0x1A) and DEC A (0x3A)
        MOS6502.SetPC(ProgramCounter: 0x200)
        
        MOS6502.Write(address: 0x200, byte: 0xA9) // LDA #$05
        MOS6502.Write(address: 0x201, byte: 0x05)
        MOS6502.Write(address: 0x202, byte: 0x1A) // INC A
        MOS6502.Write(address: 0x203, byte: 0x3A) // DEC A
        MOS6502.Write(address: 0x204, byte: 0x3A) // DEC A
        
        MOS6502.SetPC(ProgramCounter: 0x200)
        MOS6502.Execute() // LDA #$05
        XCTAssertEqual(MOS6502.getA(), 0x05)
        
        MOS6502.Execute() // INC A → 6
        XCTAssertEqual(MOS6502.getA(), 0x06, "INC A should increment accumulator")
        
        MOS6502.Execute() // DEC A → 5
        XCTAssertEqual(MOS6502.getA(), 0x05, "DEC A should decrement accumulator")
        
        MOS6502.Execute() // DEC A → 4
        XCTAssertEqual(MOS6502.getA(), 0x04, "DEC A should decrement accumulator again")
    }
    
    func testAssemblerASL() throws {
        // Verify ASL assembles correctly and PC tracking is right
        let assembler = Assembler6502()
        let source = """
        ORG $0200
        LDA #$01
        ASL $10
        NOP
        """
        let result = assembler.assemble(source: source)
        XCTAssertEqual(result.origin, 0x0200)
        // Expected bytes: A9 01 (LDA #$01), 06 10 (ASL $10), EA (NOP) = 5 bytes
        let bytes = Array(result.objectCode.dropFirst(2)) // skip origin header
        XCTAssertEqual(bytes.count, 5, "ASL zero-page should produce correct byte count")
        XCTAssertEqual(bytes[0], 0xA9) // LDA
        XCTAssertEqual(bytes[1], 0x01) // #$01
        XCTAssertEqual(bytes[2], 0x06) // ASL zp
        XCTAssertEqual(bytes[3], 0x10) // $10
        XCTAssertEqual(bytes[4], 0xEA) // NOP
    }
    
    func testAssemblerINCA_DECA() throws {
        // Verify INCA/DECA assemble to correct 65C02 opcodes
        let assembler = Assembler6502()
        let source = """
        ORG $0200
        INCA
        DECA
        """
        let result = assembler.assemble(source: source)
        let bytes = Array(result.objectCode.dropFirst(2))
        XCTAssertEqual(bytes.count, 2)
        XCTAssertEqual(bytes[0], 0x1A, "INCA should assemble to 0x1A (65C02 INC A)")
        XCTAssertEqual(bytes[1], 0x3A, "DECA should assemble to 0x3A (65C02 DEC A)")
    }

}
