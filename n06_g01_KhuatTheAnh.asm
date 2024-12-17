.data
input_buffer:    .space 1024            # Allocate 1024 bytes for input buffer
temp_reg:       .word 1                 # Temporary register storage
prompt_msg:     .asciz "Please input a string (length must be multiple of 8): \n"  # Prompt message
error_msg:      .asciz "Error: Length must be divisible by 8. Try again! \n"     # Error message
header:         .asciz "     Disk 1               Disk 2               Disk 3      \n"  # Header for output
divider:        .asciz " --------------       --------------       -------------- \n"  # Divider line
start_ascii:    .asciz "|     "          # Starting marker for ASCII output
end_ascii:      .asciz "     |     "      # Ending marker for ASCII output
start_hex:      .asciz "[[ "             # Starting marker for Hexadecimal output
end_hex:        .asciz "]]     "         # Ending marker for Hexadecimal output
hex_map:        .asciz "0123456789abcdef" # Hexadecimal character map

.text
main:
    # Display prompt message to the user
    la a0, prompt_msg
    li a7, 4
    ecall

    # Input string into buffer
    la a0, input_buffer               # Load address of input buffer
    add a0, a0, s11                   # Move to the end of previous string
    li a1, 1024                       # Buffer size
    sub a1, a1, s11
    li a7, 8                          # Syscall for string input
    ecall

    # Count characters in the string
    la t0, input_buffer               # Load input buffer address
    li t1, 0                          # Character count = 0

count_chars:
    lb t2, 0(t0)                      # Load byte from buffer
    beqz t2, validate_length          # If null terminator, validate length
    addi t1, t1, 1                    # Increment character count
    addi t0, t0, 1                    # Move to the next character
    j count_chars

validate_length:
    li t3, 8                          # Length must be divisible by 8
    addi t1, t1, -1                   # Exclude null terminator
    rem t4, t1, t3                    # t4 = t1 % 8
    beqz t4, process_string           # If remainder is 0, continue

    # Display error message and restart
    la a0, error_msg
    li a7, 4
    ecall
    j main

process_string:
    mv s11, t1                        # Save string length
    la s0, input_buffer               # Load buffer into s0
    la s5, hex_map                    # Load hex map for hex conversions

    # Print table header
    la a0, header
    li a7, 4
    ecall

    la a0, divider
    li a7, 4
    ecall

    li t3, 0                          # Block counter (used to determine Disk)

data_loop:
    lw t0, 0(s0)                      # Load first 4-byte
    lw t1, 4(s0)                      # Load second 4-byte

    xor t2, t0, t1                    # XOR first and second word for redundancy
    li t6, 3                          # Disk selection modulus

    rem t3, t3, t6                    # Determine disk based on block counter
    li t5, 1                          # Constant for Disk 2

    # Reset disk flags
    li s1, 0                          # Disk 1 flag
    li s2, 0                          # Disk 2 flag
    li s3, 0                          # Disk 3 flag

    # Determine which disk to use
    beqz t3, disk_3                   # If t3 == 0 -> Disk 3
    beq t3, t5, disk_2                # If t3 == 1 -> Disk 2
    j disk_1                          # Else -> Disk 1

disk_3:
    li s3, 1                          # Set Disk 3 flag
    j display_data

disk_2:
    mv t4, t1                         # Swap t1 and t2
    mv t1, t2
    mv t2, t4
    li s2, 1                          # Set Disk 2 flag
    j display_data

disk_1:
    mv t4, t0                         # Swap t0 and t2
    mv t0, t2
    mv t2, t4
    li s1, 1                          # Set Disk 1 flag

display_data:
    # Output Disk 1 data
    la a1, temp_reg
    sw t0, 0(a1)                      # Store t0 in temp_reg
    mv a2, s1                         # Disk 1 flag
    jal output_data

    # Output Disk 2 data
    la a1, temp_reg
    sw t1, 0(a1)                      # Store t1 in temp_reg
    mv a2, s2                         # Disk 2 flag
    jal output_data

    # Output Disk 3 data
    la a1, temp_reg
    sw t2, 0(a1)                      # Store t2 in temp_reg
    mv a2, s3                         # Disk 3 flag
    jal output_data

    j next_block                      # Move to the next block

output_data:
    addi sp, sp, -16                  # Create stack frame
    sw t0, 0(sp)
    sw t1, 4(sp)
    sw t2, 8(sp)
    sw t3, 12(sp)

    beqz a2, ascii_output             # If disk flag is 0, print ASCII

    # Hexadecimal output
    hex_output:
        li t0, 4                      # Process 4 bytes
        la a0, start_hex              # Print start of hex block
        li a7, 4
        ecall
    hex_print_loop:
        lb t1, 0(a1)                  # Load byte
        andi t2, t1, 0xF0             # Extract high nibble
        srli t2, t2, 4
        add t3, s5, t2                # Map to hex_map
        lb a0, 0(t3)                  # Print high nibble
        li a7, 11
        ecall

        andi t2, t1, 0x0F             # Extract low nibble
        add t3, s5, t2
        lb a0, 0(t3)                  # Print low nibble
        li a7, 11
        ecall

        addi t0, t0, -1               # Decrement byte counter
        addi a1, a1, 1                # Move to next byte
        beqz t0, hex_done             # Done printing the storing block

        li a7, 11                     # Print ',' separator
        li a0, ','
        ecall
        j hex_print_loop

    hex_done:
        la a0, end_hex                # Print end of hex block
        li a7, 4
        ecall
        j restore_stack

ascii_output:
    la a0, start_ascii                # Print start of ASCII block
    li a7, 4
    ecall

    li t0, 4                          # Process 4 bytes

ascii_print_loop:
    beqz t0, ascii_done               # Done printing the loading block
    lb a0, 0(a1)                      # Load byte
    li a7, 11                         # Print character
    ecall
    addi t0, t0, -1                   # Decrement counter
    addi a1, a1, 1                    # Move to next byte
    j ascii_print_loop

ascii_done:
    la a0, end_ascii                  # Print end of ASCII block
    li a7, 4
    ecall

restore_stack:
    lw t0, 0(sp)                      # Restore registers
    lw t1, 4(sp)
    lw t2, 8(sp)
    lw t3, 12(sp)
    addi sp, sp, 16                   # Restore stack pointer
    jr ra

next_block:
    addi s0, s0, 8                    # Move to next 8-byte block
    addi t3, t3, 1                    # Increment block counter

    li a0, '\n'                      # Print newline
    li a7, 11
    ecall

    lb t1, 0(s0)                      # Check for end of input
    li t6, '\n'
    bne t1, t6, data_loop	      #If it is not the end of string, move back to data processing
    
end_program:
	la a0, divider			
	li a7, 4
	ecall				#Print divider line

	j main				#Jump back to continue getting user input
