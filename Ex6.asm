.data
	input_buffer:    .space 1024
	temp_reg:       .word 1
	prompt_msg:     .asciz "Please input a string (length must be multiple of 8): \n"
	error_msg:      .asciz "Error: Length must be divisible by 8. Try again! \n"
	header:         .asciz "     Disk 1               Disk 2               Disk 3      \n"
	divider:        .asciz " --------------       --------------       -------------- \n"
	start_ascii:    .asciz "|     "
	end_ascii:      .asciz "     |     "
	start_hex:      .asciz "[[ "
	end_hex:        .asciz "]]     "
	hex_map:        .asciz "0123456789abcdef"

.text

main:
	la a0, prompt_msg
	li a7, 4
	ecall

	la a0, input_buffer
	add a0, a0, s11
	li a1, 1024
	sub a1, a1, s11
	li a7, 8
	ecall

	la t0, input_buffer
	li t1, 0

count_chars:
	lb t2, 0(t0)
	beqz t2, validate_length
	addi t1, t1, 1
	addi t0, t0, 1
	j count_chars

validate_length:
	li t3, 8
	addi t1, t1, -1
	rem t4, t1, t3
	beqz t4, process_string

	la a0, error_msg
	li a7, 4
	ecall
	j main

process_string:
	mv s11, t1
	la s0, input_buffer
	la s5, hex_map

	la a0, header
	li a7, 4
	ecall

	la a0, divider
	li a7, 4
	ecall

	li t3, 0

data_loop:
	lw t0, 0(s0)
	lw t1, 4(s0)

	xor t2, t0, t1
	li t6, 3

	rem t3, t3, t6
	li t5, 1

	li s1, 0
	li s2, 0
	li s3, 0

	beqz t3, disk_3
	beq t3, t5, disk_2
	j disk_1

disk_3:
	li s3, 1
	j display_data

disk_2:
	mv t4, t1
	mv t1, t2
	mv t2, t4
	li s2, 1
	j display_data

disk_1:
	mv t4, t0
	mv t0, t2
	mv t2, t4
	li s1, 1

display_data:
	la a1, temp_reg
	sw t0, 0(a1)
	mv a2, s1
	jal output_data

	la a1, temp_reg
	sw t1, 0(a1)
	mv a2, s2
	jal output_data

	la a1, temp_reg
	sw t2, 0(a1)
	mv a2, s3
	jal output_data

	j next_block

output_data:
	addi sp, sp, -16
	sw t0, 0(sp)
	sw t1, 4(sp)
	sw t2, 8(sp)
	sw t3, 12(sp)

	beqz a2, ascii_output
	hex_output:
		li t0, 4

		la a0, start_hex
		li a7, 4
		ecall

	hex_print_loop:
		

		lb t1, 0(a1)

		andi t2, t1, 0xF0
		srli t2, t2, 4
		add t3, s5, t2
		lb a0, 0(t3)
		li a7, 11
		ecall

		andi t2, t1, 0x0F
		add t3, s5, t2
		lb a0, 0(t3)
		li a7, 11
		ecall

		
            	
		addi t0, t0, -1
		addi a1, a1, 1
		beqz t0, hex_done
		
		li a7, 11
            	li a0, ','
            	ecall
            	
		j hex_print_loop

	hex_done:
		la a0, end_hex
		li a7, 4
		ecall
		j restore_stack

ascii_output:
		la a0, start_ascii
		li a7, 4
		ecall

		li t0, 4

	ascii_print_loop:
		beqz t0, ascii_done
		lb a0, 0(a1)
		li a7, 11
		ecall
		addi t0, t0, -1
		addi a1, a1, 1
		j ascii_print_loop

	ascii_done:
		la a0, end_ascii
		li a7, 4
		ecall

restore_stack:
	lw t0, 0(sp)
	lw t1, 4(sp)
	lw t2, 8(sp)
	lw t3, 12(sp)
	addi sp, sp, 16
	jr ra

next_block:
	addi s0, s0, 8
	addi t3, t3, 1

	li a0, '\n'
	li a7, 11
	ecall

	lb t1, 0(s0)
	li t6, '\n'
	bne t1, t6, data_loop

end_program:
	la a0, divider
	li a7, 4
	ecall

	j main
