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
    
    // MARK: - KIM Venture debugging

    /// Parse papertape format and load into memory via Write()
    private func loadPapertape(_ ptp: String) {
        for line in ptp.components(separatedBy: ";") {
            let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if l.isEmpty || l.count < 6 { continue }
            guard let nBytes = UInt8(String(l.prefix(2)), radix: 16) else { continue }
            if nBytes == 0 { continue }
            let addrStr = String(l[l.index(l.startIndex, offsetBy: 2)..<l.index(l.startIndex, offsetBy: 6)])
            guard let addr = UInt16(addrStr, radix: 16) else { continue }
            for i in 0..<Int(nBytes) {
                let start = l.index(l.startIndex, offsetBy: 6 + i * 2)
                let end = l.index(start, offsetBy: 2)
                if end > l.endIndex { break }
                guard let byte = UInt8(String(l[start..<end]), radix: 16) else { continue }
                MOS6502.Write(address: addr &+ UInt16(i), byte: byte)
            }
        }
    }

    func testKIMVentureTrace() throws {
        // Load KIM Venture papertape data
        let zeroPagePTP = """
        ;18000084EFA000A97F8D4117A20984FCB9F000204E1FC8C00690F30BAA
        ;180018203D1F206A1FA4EF6077395E79760638545C506D781C004007C4
        ;1800307C713D1E37733E6E53085B0000000000FFEC0000000BFF000691
        ;18004800000003000204081020408034002BBEDC43E425221C468C05B6
        ;18006089B5E7D7AE06091118D33C4F387BABDB705293EF6A28739B0BD5
        ;180078EB565D82F3883F4E434C4D52500094114A450395054B4596092D
        ;180090024B8F104406805049050204810A4A43825247520783704106C2
        ;1800A8488461464F852155548600870C4E42892E574B56408A0C540853
        ;1800C041018B0F495755568C3052538D2A5150468E0D434D4797090810
        ;1700D8494B90204C91354D534C4692204893334D5152449F009F08A9
        ;00000A000A
        """
        let gamePTP = """
        ;180100D8A5458545A27BE8E8B50010FB8642291FC545D0F209A0950C6C
        ;18011800B4012901AA843BB45F20B302A645B46520B302A645CAD009BF
        ;18013012AD0617290FAA8546BDE71F853CA08F20B302A90B4C0002085C
        ;180148A641E64CD002F601A0FC20B302C906B0034CA517C90B90E80B8A
        ;180160F09EC90F90DFD0E8A953853CA09E20B302A0E1C546D0D1A90EAC
        ;18017803A645F02AA900E005B03BCAF0DAE63DEAD01CA642B501A00CDD
        ;180190FFC84A9005E8C4F7F009C005D0F3A0F74C2202B501291F4C0CC4
        ;1801A80301A449A54588F01188F021A20788F024A20588F01FA0850B66
        ;1801C0D0DEC908D0F8A540F0F4C88440A0BD20B3024C7F02C906D00E13
        ;1801D8E5A90D10CAE445D0DDB54FD565F0D795658A10BBA63FB5010E2B
        ;1801F09500E8E0EFD0F760000000000000000038E90DAA4A2901A80970
        ;18020849018543E886552080178448F00FA655D00EA547C904D00809E3
        ;180220A0FA20B3024C4801B46220B302C64830F4A444843FB600860A42
        ;18023849B45720B302A4553004C915D004C644D0E3883005F0294C0A39
        ;180250AA01A0F7A649CAD008A53E2928C920D0BF8A30BEE647A53E0C71
        ;180268154D853E209017C64120EC01A04CD0AAE641209017E63FC60AC1
        ;18028047A649A53E38F54C853E20EC01A54010E3A649CAD0DEA5450C25
        ;180298C908D0D8A985853F8640A9058DBD03A0BD20B302F0C1188A0C63
        ;1802B0654AA8844AA200A00086FE86FD18B14A486A4A4A4AF032C90BC6
        ;1802C801F034AAB51FA6FD95F068E886FD290FC901F026AAB51FA60DBC
        ;1802E0FD95F0C8E8E00690D2A0C020000020000088D0F7A6FED0B60E8D
        ;1802F8606885FEC810BC6810DAC838B0B835882B0516EB1685AB230C02
        ;1803108503FB54FFBAA15F07CDA95F1652B8CD516CF32135F127850C27
        ;180328F36ED50511B741350823BACC0CFA1659F13E881804CD558F0A66
        ;18034013B2D5FBA165F13A84F32135F4A95F2F6A8507FD7136DE990D2A
        ;18035858FC6212DF051B10793604FC87DF0979FD650DA18CD5BF080B19
        ;180370CDB52151AF167DF101154F04BA1828F6288F2F13859AF14A0A5E
        ;18038818EFBF2DEFBF79082FC71391AF167D07FC218CF2DD7305150BAD
        ;1803A021373F0511EDDA9FF7CF1DF6AEC5FEC5F107628D547FC5510DAD
        ;1803B8061118FD650E4B213A9F04C32B5409AEDF111804F52DCF0D08BE
        ;1803D087DD850FF118E5F4BA161004F117B4FBAA15F459FFBA4F320DA6
        ;1803E8BB1810C1AF167D13BADDAF12AB5CDF3299AD6A17F19FFF1C0CDE
        ;0000200020
        """
        let extraPTP = """
        ;181780B641A0FFE88644B5010A30F8C890F560A443208017A2EEB50D6F
        ;181798009501CAE444D0F7A549950160A884F7A645B565D54FF0080D3E
        ;1817B0E005F024E007F022E00CD004A547D018E003D004A53E30110B40
        ;1817C8E008D015A540F01188F00EA0B14C22028888C003D0034C200B03
        ;0417E0024C8B0101D5
        ;0000050005
        """

        loadPapertape(zeroPagePTP)
        loadPapertape(gamePTP)
        loadPapertape(extraPTP)

        // Verify data at $1780 actually loaded (RIOT fix check)
        let byte1780 = MOS6502.Read(address: 0x1780)
        XCTAssertEqual(byte1780, 0xB6, "$1780 should contain $B6 (LDX zp,Y) — RIOT must not intercept")

        // Dump ROM bytes at $1F4E-$1F60 (where loop occurs)
        print("ROM bytes at $1F4E-$1F65:")
        for addr: UInt16 in stride(from: 0x1F4E, through: 0x1F65, by: 1) {
            let b = MOS6502.Read(address: addr)
            print(String(format: "  $%04X: $%02X", addr, b), terminator: "")
        }
        print()

        // Start execution at $0100
        MOS6502.SetPC(ProgramCounter: 0x0100)

        // Full trace log of last 50 steps before loop
        var fullTrace: [(pc: UInt16, a: UInt8, x: UInt8, y: UInt8, sp: UInt8)] = []
        var outputText = ""
        var hitGETCH = false
        var steps = 0
        let maxSteps = 2000000
        var loopDetected = false

        // Better infinite loop detection: track how many times each PC is visited
        var pcVisits: [UInt16: Int] = [:]
        let loopThreshold = 50000 // truly infinite = same PC many thousands of times

        while steps < maxSteps {
            let pc = MOS6502.GetPC()

            // Detect OUTCH — capture output
            if pc == 0x1EA0 {
                let a = MOS6502.getA()
                if a >= 13 { outputText.append(String(format: "%c", a)) }
            }
            if pc == 0x1E65 { hitGETCH = true; break }

            fullTrace.append((pc, MOS6502.getA(), MOS6502.getX(), MOS6502.getY(), MOS6502.getSP()))
            if fullTrace.count > 100 { fullTrace.removeFirst() }

            // Count visits per PC
            pcVisits[pc, default: 0] += 1
            if pcVisits[pc]! >= loopThreshold {
                loopDetected = true
                print("INFINITE LOOP: PC $\(String(format: "%04X", pc)) hit \(loopThreshold) times at step \(steps)")
                break
            }

            let result = MOS6502.Step()
            if result.address == 0xFFFF { print("CRASH at step \(steps)"); break }
            steps += 1
        }

        print("\n--- KIM Venture trace ---")
        print("Steps: \(steps), Final PC: \(String(format: "$%04X", MOS6502.GetPC()))")
        print("GETCH reached: \(hitGETCH), Loop: \(loopDetected)")
        print("Output: [\(outputText)]")
        print("\nLast 50 steps:")
        for entry in fullTrace.suffix(50) {
            let opcode = MOS6502.Read(address: entry.pc)
            let op1 = MOS6502.Read(address: entry.pc &+ 1)
            let op2 = MOS6502.Read(address: entry.pc &+ 2)
            print(String(format: "  $%04X: %02X %02X %02X  A=%02X X=%02X Y=%02X SP=%02X", entry.pc, opcode, op1, op2, entry.a, entry.x, entry.y, entry.sp))
        }
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
