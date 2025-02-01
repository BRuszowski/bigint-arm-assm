# Filename: libBigInt.s
# Date: 4/14/2024
# Purpose: BigInteger Functions
#     Addition
#     Logical Shift Left
#     Multiplication
#     Modulo
#     Printing in decimal format
#     Parsing a decimal format string
# Notes:
#     BigInt array uses little-endian format where zero index has the least significant bits
# 


.global bigIntAdd
.global bigIntShiftLeft
.global bigIntMult
.global bigIntMod
.global bigIntPrintElements
.global bigIntPrintDecimal
.global bigIntParseDecimalStr

.data
    # Size of BigIntegers; must be less than 2^30
    wordsPerBigInt: .word 128
    newlineStr: .asciz "\n"


#Purpose: adds two BigIntegers
#Notes: Mutates the addend in r0
#Inputs: r0 - addend1 address, r1 - addend2 address
# Output: r0 - sum of r0 and r1
.text
bigIntAdd:
    # push stack
    SUB sp, sp, #20
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    STR r5, [sp, #8]
    STR r6, [sp, #12]
    STR r7, [sp, #16]
	
	MOV r4, r0
	MOV r5, r1
	
	MOV r6, #0 // Zero loop counter
	MOV r7, #0 // Zero carry bit
	
	StartLoopAdd:
		# Check if loop end condition met
        LDR r3, =wordsPerBigInt
        LDR r3, [r3, #0]
        CMP r6, r3
	    BGE EndLoopAdd
		
		# Loop body
		# Load 32-bit parts of addends
		LSL r3, r6, #2 // multiply current position by 4 bytes per word to get offset
		LDR r0, [r4, r3]
		LDR r1, [r5, r3]
		
		CMP r7, #0
        BEQ NoCarry
            ADDS r0, r0, #1 // add1 if prior carry
        NoCarry:
		MOVCC r7, #0 // reset carry if no overflow
		ADDS r0, r0, r1
		MOVCS r7, #1 // set carry if overflow
		
		STR r0, [r4, r3] // update value in memory
		
        # Adjust counter and start next iteration
        ADD r6, r6, #1
        B StartLoopAdd
    EndLoopAdd:

    # pop stack
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
	LDR r5, [sp, #8]
	LDR r6, [sp, #12]
    LDR r7, [sp, #16]
    ADD sp, sp, #20
    MOV pc, lr
# END bigIntAdd


#Purpose: shifts a BigInteger left
#Notes: Mutates r0
#Inputs: r0 - address of BigInteger to shift, r1 - shift amount, r2 - 1 if double-size otherwise 0
.text
bigIntShiftLeft:
    # push stack
    SUB sp, sp, #24
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    STR r5, [sp, #8]
    STR r6, [sp, #12]
    STR r7, [sp, #16]
    STR r8, [sp, #20]	

    # Save address and shift amount
    MOV r4, r0
    MOV r5, r1
    
    # Determine word offset
    LSR r6, r5, #5 // Divide shift amount by 32    

    # Determine per word shift amount
    LSL r7, r5, #27
    LSR r7, r7, #27
    
    # Set array index to last index
    LDR r0, =wordsPerBigInt
    LDR r0, [r0, #0]
    CMP r2, #0
    LSLNE r0, r0, #1
    SUB r8, r0, #1

    StartLoopShift:
        # End condition check
        CMP r8, #0
        BLT EndLoopShift

        # Loop Body
        # Find new value
        SUB r0, r8, r6
        
        # SourceIndexCheck
        CMP r0, #0
        
        BLT NegativeSourceIndex
            # Set upper bits
            LSL r0, r0, #2 // multiply by 4 bytes per index
            LDR r1, [r4, r0]
            LSL r1, r1, r7
            
            # Set lower bits
            CMP r0, #0
            BLE EndSourceIndexCheck // No lower bits
                MOV r2, #32
                SUB r3, r2, r7 // carried over bits are the inverse of the shift amount
                SUB r0, r0, #4 // four bytes prior
                LDR r2, [r4, r0]
                LSR r2, r2, r3
                ADD r1, r1, r2 // combine the bits
                B EndSourceIndexCheck
        NegativeSourceIndex:
            MOV r1, #0        
        EndSourceIndexCheck:

        LSL r0, r8, #2 // multiply by 4 bytes per index
        STR r1, [r4, r0]

        # Increment and start next iteration
        SUB r8, r8, #1
        B StartLoopShift
    EndLoopShift:

    # pop stack
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
	LDR r5, [sp, #8]
	LDR r6, [sp, #12]
    LDR r7, [sp, #16]
    LDR r8, [sp, #20]
    ADD sp, sp, #24
    MOV pc, lr
# END bigIntShiftLeft


#Purpose: Zeroes a BigInt
#Notes: Mutates r0
#Inputs: r0 - address of BigInt, r1 - 1 if double-size 0 otherwise
.text
bigIntZero:
    # push stack
    SUB sp, sp, #4
    STR lr, [sp, #0]
    
    LDR r2, =wordsPerBigInt
    LDR r2, [r2]
    LSL r2, r2, #2
    CMP r1, #0
    LSLNE r2, r2, #1
    MOV r3, #0
    MOV r1, #0
    StartLoopZero:
        # Check end condition
        CMP r1, r2
        BGE EndLoopZero
        
        # Loop body
        STR r3, [r0, r1]
        
        # Increment and start next iteration
        ADD r1, #4
        B StartLoopZero
    EndLoopZero:
    
    # pop stack
    LDR lr, [sp, #0]
    ADD sp, sp, #4
    MOV pc, lr
# End bigIntZero


#Purpose: Multiplies two BigIntegers
#Notes: Mutates r0
#Inputs: r0 - address of factor1, r1 - address of factor2
.text
bigIntMult:
    # push stack
    SUB sp, sp, #20
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    STR r5, [sp, #8]
    STR r6, [sp, #12]
    STR r7, [sp, #16]


    # Save arguments
    MOV r4, r0
    MOV r5, r1

    # Store original addend1 value
    LDR r0, =multAddend1OrginalBigInt
    MOV r1, #0
    BL bigIntZero
    LDR r0, =multAddend1OrginalBigInt
    MOV r1, r4
    BL bigIntAdd

    
    # Zero addend1
    MOV r0, r4
    MOV r1, #0
    BL bigIntZero

    # Set addend equal to factor2
    LDR r0, =multAddend2Adjusted
    MOV r1, #0
    BL bigIntZero
    LDR r0, =multAddend2Adjusted
    MOV r1, r5
    BL bigIntAdd
    
    
    MOV r6, #0 // word index
    MOV r7, #0 // bit index
    
    StartLoopMultWord:
        # Check end condition
        LDR r0, =wordsPerBigInt
        LDR r0, [r0]
        CMP r6, r0
        BGE EndLoopMultWord
        
        # Loop body
        StartLoopMultBit:
            # Check end condition
            CMP r7, #32
            BGE EndLoopMultBit
            
            # Loop body
            LDR r0, =multAddend1OrginalBigInt
            LDR r0, [r0, r6] // load word from addend1
            # Create mask
            MOV r1, #1
            LSL r1, r1, r7
            AND r0, r0, r1
            
            # LSBSetCheck
            CMP r0, #0
            BEQ EndMultLSBSetCheck
                MOV r0, r4
                LDR r1, =multAddend2Adjusted
                BL bigIntAdd
            EndMultLSBSetCheck:
            
            LDR r0, =multAddend2Adjusted
            MOV r1, #1
            MOV r2, #0
            BL bigIntShiftLeft
        
            # Increment and start next iteration
            ADD r7, #1
            B StartLoopMultBit
        EndLoopMultBit:
    
        # Increment and start next iteration
        MOV r7, #0
        ADD r6, #1
        B StartLoopMultWord
    EndLoopMultWord:    

    # pop stack
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
    LDR r5, [sp, #8]
    LDR r6, [sp, #12]
    LDR r7, [sp, #16]
    ADD sp, sp, #20
    MOV pc, lr
.data
    multAddend1OrginalBigInt: .space 4 * 128 // BigIntSizeLimit
    multAddend2Adjusted: .space 4 * 128 // BigIntSizeLimit
# END bigIntMult


#Purpose: Compares two BigInts
#Inputs: r0 - address of BigInt1, r1 - address of BigInt2
#Output: r0 - 1 if BigInt1 > BigInt2, 0 if equal, -1 if BigInt1 < BigInt2
.text
bigIntCompare:
    # push stack
    SUB sp, sp, #16
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    STR r5, [sp, #8]
    STR r6, [sp, #12]
    
    MOV r4, r0
    MOV r5, r1
    MOV r6, #0 // compare result
    
    LDR r0, =wordsPerBigInt
    LDR r0, [r0]
    SUB r0, r0, #1
    LSL r0, r0, #2
    StartLoopCompare:
        # Check end condition
        CMP r0, #0
        BLT EndLoopCompare
        
        # Loop body
        # Load values
        LDR r1, [r4, r0]
        LDR r2, [r5, r0]
        CMP r1, r2
        BHS CompareCheckLesser
            MOV r6, #-1
            B EndLoopCompare
        CompareCheckLesser:
        BEQ EndCompareCheck
            MOV r6, #1
            B EndLoopCompare
        EndCompareCheck:
        
        # Increment and start next iteration
        SUB r0, r0, #1
        B StartLoopCompare
    EndLoopCompare:
    
    MOV r0, r6
    
    # pop stack
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
    LDR r5, [sp, #8]
    LDR r6, [sp, #12]
    ADD sp, sp, #16
    MOV pc, lr
# END bigIntCompare


#Purpose: Finds most significant bit of a BigInt
#Inputs: r0 - address of BigInt1
#Output: r0 - position of most significant bit
.text
bigIntMSB:
    # push stack
    SUB sp, sp, #8
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    
    MOV r4, r0
    
    LDR r0, =wordsPerBigInt
    LDR r0, [r0]
    SUB r0, r0, #1
    LSL r3, r0, #2
    StartLoopMSB:
        # Check end condition
        CMP r3, #0
        BLT EndLoopCompare
        
        # Loop body
        LDR r1, [r4, r3]
        CMP r1, #0
        BEQ ContinueLoopMSB
            MOV r2, #31
            StartLoopMSBWord:
                # Check end condition
                CMP r2, #0
                BLT EndLoopMSB
            
                # Loop body
                MOV r0, #1
                LSL r0, r0, r2 // mask
                AND r0, r1, r0
                CMP r0, #0
                BEQ ContinueLoopMSBWord
                    MOV r0, r2
                    LSL r1, r3, #3 // Add preceding places
                    ADD r0, r1
                    B EndLoopMSB // MSB found; break out of loops
                ContinueLoopMSBWord:
                # Increment and start next iteration
                SUB r2, r2, #1
                B StartLoopMSBWord
            EndLoopMSBWord:
            
            B EndLoopMSB
        ContinueLoopMSB:
    
        # Increment and start next iteration
        SUB r3, r3, #4
        B StartLoopMSB
    EndLoopMSB:
    
    # pop stack
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
    ADD sp, sp, #8
    MOV pc, lr
# END bigIntMSB


#Purpose: Finds two's complement of a BigInt
#Notes: Mutates input
#Inputs: r0 - address of BigInt
.text
bigIntTwosComplement:
    # push stack
    SUB sp, sp, #20
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    STR r5, [sp, #8]
    STR r6, [sp, #12]
    STR r7, [sp, #16]

    MOV r4, r0

    LDR r0, =wordsPerBigInt
    LDR r0, [r0]
    SUB r0, r0, #1
    LSL r0, r0, #2
    StartLoopTwosComplement:
        # Check end condition
        CMP r0, #0
        BLT EndLoopTwosComplement
        LDR r1, [r4, r0]
        
        # Loop body
        MOV r2, #0
        SUB r2, r2, #1
        EOR r1, r1, r2
        STR r1, [r4, r0]
        
        # Increment and start next iteration
        SUB r0, r0, #4
        B StartLoopTwosComplement
    EndLoopTwosComplement:
    
    LDR r0, =twosComplementAddendBigInt
    MOV r1, #0
    BL bigIntZero
    LDR r0, =twosComplementAddendBigInt
    MOV r1, #1
    STR r1, [r0, #0]
    MOV r0, r4
    LDR r1, =twosComplementAddendBigInt
    BL bigIntAdd

    # pop stack
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
    LDR r5, [sp, #8]
    LDR r6, [sp, #12]
    LDR r7, [sp, #16]
    ADD sp, sp, #20
    MOV pc, lr
.data
    twosComplementAddendBigInt: .space 4 * 128 // BigIntSizeLimit
# END bigIntTwosComplement


#Purpose: Finds the modulus of two BigInts
#Notes: Result space must be at least as large as global max size
#       Behavior is undefined if divisor is less than 1
#Inputs: r0 - address of dividend, r1 - address of divisor, r2 - address of result
.text
bigIntMod:
    # push stack
    SUB sp, sp, #20
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    STR r5, [sp, #8]
    STR r6, [sp, #12]
    STR r7, [sp, #16]
    
    MOV r4, r0
    MOV r5, r1
    MOV r6, r2
    
    # copy values into temporary BigInts
    MOV r0, r6
    MOV r1, #0
    BL bigIntZero
    MOV r0, r6
    MOV r1, r4
    BL bigIntAdd
    
    StartLoopMod:
        # Check end condition
        MOV r0, r6
        MOV r1, r5
        BL bigIntCompare
        CMP r0, #0
        BLE EndLoopMod
    
        # Loop body
        MOV r0, r6
        BL bigIntMSB
        MOV r7, r0 // MSB of dividend
        MOV r0, r5
        BL bigIntMSB // MSB of divisor
        SUB r7, r7, r0 // bit difference
        CMP r7, #0
        SUBGT r7, r7, #1 // reduce by 1 if greater than 0
        
        # Shift temporary value for divisor
        LDR r0, =modAddendBigInt
        MOV r1, #0
        BL bigIntZero
        LDR r0, =modAddendBigInt
        MOV r1, r5
        BL bigIntAdd
        LDR r0, =modAddendBigInt
        MOV r1, r7
        MOV r2, #0
        BL bigIntShiftLeft

        # Convert to two's complement
        LDR r0, =modAddendBigInt
        BL bigIntTwosComplement
        
        # Decrease dividend
        MOV r0, r6
        LDR r1, =modAddendBigInt
        BL bigIntAdd
        
        B StartLoopMod
    EndLoopMod:

    # pop stack
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
    LDR r5, [sp, #8]
    LDR r6, [sp, #12]
    LDR r7, [sp, #16]
    ADD sp, sp, #20
    MOV pc, lr
.data
    modAddendBigInt: .space 4 * 128 // BigIntSizeLimit
# END bigIntMod


#Purpose: Prints 32-bit words forming the BigInteger
#Inputs: r0 - BigInt address
.text
bigIntPrintElements:
	# push stack
    SUB sp, sp, #12
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    STR r5, [sp, #8]
	
	MOV r4, r0
    LDR r5, =wordsPerBigInt
    LDR r5, [r5, #0]
    SUB r5, r5, #1
	
	StartLoopPrint:
		# Check if loop end condition met
        CMP r5, #0
	    BLT EndLoopPrint
	
		# Loop body
		LDR r0, =bigIntFormatStr
        LSL r3, r5, #2
        LDR r1, [r4, r3]
        BL printf        
		
		SUB r5, r5, #1
		B StartLoopPrint
	EndLoopPrint:

    LDR r0, =newlineStr
    BL printf

	# pop stack
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
    LDR r5, [sp, #8]
    ADD sp, sp, #12
    MOV pc, lr
.data
    bigIntFormatStr: .asciz "%u "
# END bigIntPrintElements


#Purpose: Helper for BCD conversion by ensuring all BCD digits are less than 5
#Notes: Mutates input
#Inputs: r0 - address of BigInt
.text
bigIntPrintDecimalHelper:
    # push stack
    SUB sp, sp, #12
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    STR r5, [sp, #8]
    
    MOV r5, r0
    
    # Check for bcd value greater than 4
    MOV r4, #0
    StartPrintLoopBCD:
        # Check end condition
        LDR r0, =wordsPerBigInt
        LDR r0, [r0]
        LSL r0, r0, #3
        CMP r4, r0
        BGE EndPrintLoopBCD
            
        # Loop body
        LDR r0, [r5, r4]
        MOV r1, #0 // loop counter
        StartPrintNibbleLoop:
            # Check end condition
            CMP r1, #8
            BGE EndPrintNibbleLoop
            
            # Loop body
            # Mask bits
            MOV r2, #15
            LSL r3, r1, #2 // mask shift amount
            LSL r2, r2, r3 
            AND r2, r0, r2
            EOR r0, r0, r2 // zero masked section
            # Adjust if greater than or equal to 5
            LSR r2, r2, r3
            CMP r2, #5
            ADDGE r2, #3
            # Update masked section
            LSL r2, r2, r3
            ADD r0, r0, r2
        
            # Increment and start next iteration
            ADD r1, #1
            B StartPrintNibbleLoop
        EndPrintNibbleLoop:
    
        STR r0, [r5, r4]
    
        # Increment and start next iteration
        ADD r4, #4
        B StartPrintLoopBCD
    EndPrintLoopBCD:
    
    # pop stack
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
    LDR r5, [sp, #8]
    ADD sp, sp, #12
    MOV pc, lr
# END bigIntPrintDecimalHelper


#Purpose: Prints BigInt in decimal format
#Notes: Uses double-dabble algorithm to convert binary number
#Inputs: r0 - address of BigInt
.text
bigIntPrintDecimal:
    # push stack
    SUB sp, sp, #20
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    STR r5, [sp, #8]
    STR r6, [sp, #12]
    STR r7, [sp, #16]

    # Save argument
    MOV r4, r0
    
    # Set addend to input BigInt
    LDR r0, =printBCDAddendBigInt
    MOV r1, #0
    BL bigIntZero
    MOV r1, r4
    BL bigIntAdd
    
    # Zero bcd representation
    LDR r0, =printBCDOutputBigInt
    MOV r1, #1
    BL bigIntZero
    
    MOV r5, #0
    StartPrintLoopConvertDecimal:
        # Check end condition
        LDR r0, =wordsPerBigInt
        LDR r0, [r0]
        LSL r0, r0, #5
        CMP r5, r0
        BGE EndPrintLoopConvertDecimal
        
        # Loop body
        # Check for bcd value greater than 4
        LDR r0, =printBCDOutputBigInt
        BL bigIntPrintDecimalHelper
        
        # Perform shifts
        LDR r0, =printBCDOutputBigInt
        MOV r1, #1
        MOV r2, #1
        BL bigIntShiftLeft
        # Get last word
        LDR r0, =wordsPerBigInt
        LDR r0, [r0]
        SUB r0, r0, #1
        LSL r0, r0, #2
        LDR r1, =printBCDAddendBigInt
        LDR r0, [r1, r0]
        # Check highest bit
        MOV r1, #1
        LSL r1, r1, #31
        AND r0, r0, r1
        # PrintHighestBitCheck
        CMP r0, #0
        BEQ EndPrintHighestBitCheck
            # Add one to bcdBigInt
            LDR r0, =printBCDOutputBigInt
            LDR r1, [r0]
            ADD r1, r1, #1
            STR r1, [r0, #0]
        EndPrintHighestBitCheck:
        LDR r0, =printBCDAddendBigInt
        MOV r1, #1
        MOV r2, #0
        BL bigIntShiftLeft
    
        # Increment and start next iteration
        ADD r5, #1
        B StartPrintLoopConvertDecimal
    EndPrintLoopConvertDecimal:
    
    LDR r5, =wordsPerBigInt
    LDR r5, [r5]
    SUB r5, r5, #1
    LSL r5, r5, #3
    StartPrintLoopDecimal:
        # Check end condition
        CMP r5, #0
        BLT EndPrintLoopDecimal

        # Loop body
        LDR r7, =printBCDOutputBigInt
        LDR r7, [r7, r5]
        
        
        MOV r6, #7
        StartPrintDigitLoop:
            # Check end condition
            CMP r6, #0
            BLT EndPrintDigitLoop
            
            # Loop body
            LSL r0, r6, #2 // mask shift amount
            MOV r1, #15 // mask
            LSL r1, r1, r0
            AND r1, r7, r1
            LSR r1, r1, r0
            LDR r0, =decimalFormatStr
            BL printf
            
            # Increment and start next iteration
            SUB r6, r6, #1
            B StartPrintDigitLoop
        EndPrintDigitLoop:

        # Increment and start next iteration
        SUB r5, r5, #4
        B StartPrintLoopDecimal
    EndPrintLoopDecimal:

    LDR r0, =newlineStr
    BL printf

    # pop stack
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
    LDR r5, [sp, #8]
    LDR r6, [sp, #12]
    LDR r7, [sp, #16]
    ADD sp, sp, #20
    MOV pc, lr
.data
    decimalFormatStr: .asciz "%d"
    printBCDAddendBigInt: .space 4 * 128 // BigIntSizeLimit
    printBCDOutputBigInt: .space 2 * 4 * 128 // BigIntSizeLimit
# END bigIntPrintDecimal


#Purpose: Converts a decimal string into a BigInt
#Notes: Address of BigInt must be at least the size the library max BigInt size
#       Does not support negative numbers
#Inputs: r0 - address of string, r1 - address of BigInt
.text
bigIntParseDecimalStr:
    # push stack
    SUB sp, sp, #20
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    STR r5, [sp, #8]
    STR r6, [sp, #12]
    STR r7, [sp, #16]

    # Save arguments
    MOV r4, r0
    MOV r5, r1
    
    # Find end of string
    MOV r0, #0
    StartLoopParseStrTerminator:
        # Check end condition
        LDRB r1, [r4, r0]
        CMP r1, #0
        BEQ EndLoopParseStrTerminator // string terminator found
        LDR r1, =wordsPerBigInt
        LDR r1, [r1]
        LSL r1, r1, #5
        CMP r0, r1
        BGE EndLoopParseStrTerminator // string greater than max size terminate search
        
        # Increment and start next iteration
        ADD r0, #1
        B StartLoopParseStrTerminator
    EndLoopParseStrTerminator:
    
    SUB r0, r0, #1 // remove null character from length count
    MOV r6, r0 // current byte
    
    MOV r0, r5
    MOV r1, #0
    BL bigIntZero
    LDR r0, =parseDecimalAddendBigInt
    MOV r1, #0
    BL bigIntZero
    # set decimal multiplier to 1
    LDR r0, =parseDecimalMultiplierBigInt
    MOV r1, #0
    BL bigIntZero
    LDR r0, =parseDecimalMultiplierBigInt
    MOV r1, #1
    STR r1, [r0, #0] 
    
    StartLoopParse:
        # Check end condition
        CMP r6, #0
        BLT EndLoopParse
        
        # Loop body
        LDRB r7, [r4, r6]
        CMP r7, #0
        SUBNE r7, r7, #48 // if not null value, convert from char to int
        CMP r7, #0
        BEQ EndParseAdjustment
            LDR r0, =parseDecimalAddendBigInt
            MOV r1, #0
            BL bigIntZero
            LDR r0, =parseDecimalAddendBigInt
            STR r7, [r0, #0]
            
            LDR r0, =parseDecimalAddendBigInt
            LDR r1, =parseDecimalMultiplierBigInt
            BL bigIntMult
            
            MOV r0, r5
            LDR r1, =parseDecimalAddendBigInt
            BL bigIntAdd
        EndParseAdjustment:
        
        # set temporary value to current multiplier
        LDR r0, =parseDecimalAddendBigInt
        MOV r1, #0
        BL bigIntZero
        LDR r0, =parseDecimalAddendBigInt
        LDR r1, =parseDecimalMultiplierBigInt
        BL bigIntAdd
        
        # zero current multiplier
        LDR r0, =parseDecimalMultiplierBigInt
        MOV r1, #0
        BL bigIntZero
        
        # Change multiplication into powers of 2; 10x = 8x + 2x
        LDR r0, =parseDecimalAddendBigInt
        MOV r1, #1
        MOV r2, #0
        BL bigIntShiftLeft
        LDR r0, =parseDecimalMultiplierBigInt
        LDR r1, =parseDecimalAddendBigInt
        BL bigIntAdd
        
        LDR r0, =parseDecimalAddendBigInt
        MOV r1, #2
        MOV r2, #0
        BL bigIntShiftLeft
        LDR r0, =parseDecimalMultiplierBigInt
        LDR r1, =parseDecimalAddendBigInt
        BL bigIntAdd
        
        # Increment and start next iteration
        SUB r6, r6, #1
        B StartLoopParse
    EndLoopParse:

    # pop stack
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
    LDR r5, [sp, #8]
    LDR r6, [sp, #12]
    LDR r7, [sp, #16]
    ADD sp, sp, #20
    MOV pc, lr
.data
    parseDecimalAddendBigInt: .space 4 * 128 // BigIntSizeLimit
    parseDecimalMultiplierBigInt: .space 4 * 128 // BigIntSizeLimit
# END bigIntParseDecimalStr
