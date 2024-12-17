.eqv IN_ADDRESS_HEXA_KEYBOARD 0xFFFF0012
.eqv OUT_ADDRESS_HEXA_KEYBOARD 0xFFFF0014
.eqv SEVENSEG_LEFT 0xFFFF0011
.eqv SEVENSEG_RIGHT 0xFFFF0010

.data
table: .byte 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F 	# from 0 to 9 to display 7 segments
day_in_month: .word 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31		# numbers of days in each month
day_in_month_leaf: .word 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31	# numbers of days in each month of leaf year

.text
main:
	li s1, IN_ADDRESS_HEXA_KEYBOARD
	li s2, OUT_ADDRESS_HEXA_KEYBOARD
polling:
check_full_min:	
	jal get_time
	jal get_sec
	beq a0, zero, play_sound
continue_polling:
	li s3, 0x01
	sb s3, 0(s1) 
	lb s4, 0(s2)
	bne s4, zero, perform
	li s3, 0x02
	sb s3, 0(s1) 
	lb s4, 0(s2)
	bne s4, zero, perform	
	j back_to_polling
perform:
display_time:
	jal get_time
	# If press 1
	li t0, 0x21
	beq s4, t0, display_hour
	# If press 2
	li t0, 0x41
	beq s4, t0, display_min
	# If press 3
	li t0, 0xffffff81
	beq s4, t0, display_sec
	# If press 4
	li t0, 0x12
	beq s4, t0, display_day
	# If press 5
	li t0, 0x22
	beq s4, t0, display_month
	# If press 6
	li t0, 0x42
	beq s4, t0, display_year
back_to_polling:
	j polling

display_number:
# display the number in a0
	li t1, 10
	la t4, table
	# 2nd digit
	rem t2, a0, t1
	li t0, SEVENSEG_RIGHT
	add t2, t2, t4
	lb t5, 0(t2)
	sb t5, 0(t0)
	# 1st digit
	div a0, a0, t1
	rem t2, a0, t1
	li t0, SEVENSEG_LEFT
	add t2, a0, t4
	lb t5, 0(t2)
	sb t5, 0(t0)
	jr ra	
	
display_hour:
	jal get_hour
	jal display_number
	j back_to_polling
display_min:
	jal get_min
	jal display_number
	j back_to_polling
display_sec:
	jal get_sec
	jal display_number
	j back_to_polling
display_day:
	jal get_year_month_day
	mv a0, a1
	jal display_number
	j back_to_polling
display_month:
	jal get_year_month_day
	mv a0, a2
	jal display_number
	j back_to_polling
display_year:
	jal get_year_month_day
	jal display_number
	j back_to_polling
	
get_time:
# Get the time using syscall and convert to seconds and assign to s0
	li a7, 30
	ecall
	# Load the time into floating point register
	fcvt.d.wu ft0, a1		# ft0 stores 32 higher bits
	li t0, 0x80000000
	fcvt.d.wu ft1, t0
	li t0, 2
	fcvt.d.wu ft2, t0
	fmul.d ft2, ft1, ft2		# ft2 = 2^32
	fcvt.d.wu ft1, a0		# ft1 stores 32 lower bits
	fmadd.d ft0, ft0, ft2, ft1	# ft0 = ft0 * 2^32 + ft1 is the complete time
	li t0, 1000
	fcvt.d.wu ft1, t0		# ft1 = 1000
	fdiv.d ft0, ft0, ft1		# ft0 = ft0 / 1000 to convert millisecond to second
	fcvt.wu.d s0, ft0

	
get_sec:
# Get the second from total second in s0 and assign to a0
	li t0, 60
	remu a0, s0, t0
	jr ra
		
get_min:
# Get the minute from total second in s0 and assign to a0
	li t0, 3600
	li t1, 60
	remu a0, s0, t0
	divu a0, a0, t1
	jr ra
	
get_hour:
# Get the hour from total second in s0 and assign to a0
	li t0, 86400
	li t1, 3600
	remu a0, s0, t0
	divu a0, a0, t1
	li t0, 16
	bgt a0, t0, next_day
	addi a0, a0, 7
	j continue_get_hour
next_day:
	addi a0, a0, -17
	li s11, 1
continue_get_hour:
	jr ra
	
	
get_year_month_day:
	addi sp, sp, -4
	sw ra, 0(sp)
	jal get_hour		# Get_hour to check the flag s11 for next day
	lw ra, 0(sp)
	addi sp, sp, 4
	
# Get the year, month, day from total second in s0 and assign to a0
	li t0, 86400		# 86400 seconds in a day
	div t1, s0, t0		# Get the number of days from 1970 to present
	addi t1, t1, 1
	beq s11, zero, continue
	addi t1, t1, 1		# Next day for GMT+7
continue:
	li t0, -10957
	add t1, t1, t0		# Get the number of days from 2000 to present
	# Consider 400 years
	li t0, 146097		# Number of days in 400 consecutive years
	div t2, t1, t0
	remu t1, t1, t0		# Number of days left after 400x years
	li t0, 400
	mul a0, t2, t0	
	# Consider 100 years
	li t0, 36524		# Number of days in 100 consecutive years
	div t4, t1, t0
	remu t1, t1, t0		# Number of days left after 100y years
	li t0, 100
	mul t4, t4, t0
	add a0, a0, t4
	# Consider 4 years
	li t0, 1461		# Number of days in 4 consecutive years
	div t2, t1, t0
	slli t2, t2, 2
	add a0, a0, t2
	remu t1, t1, t0
	# Consider 1 years
	li t0, 365
	div t3, t1, t0
	add a0, a0, t3
	remu a1, t1, t0		
	
	li t6, 0		# index
	j check_leaf		# load day list to t2
continue_get_day:
loop:
	slli t3, t6, 2
	add t4, t2, t3
	lw t5, 0(t4)
	ble a1, t5, end_get_day
	sub a1, a1, t5
	addi t6, t6, 1
	j loop
end_get_day:
	addi a2, t6, 1		# a2 store month
	jr ra
	
play_sound:
# Play a sound
	li a7, 31
	li a0, 69
	li a1, 100
	li a2, 7
	li a3, 50
	ecall
	j continue_polling
	
check_leaf:
# Check year stored in a0
	li t0, 4
	remu t1, a0, t0
	bne t1, zero, end_not_leaf
	li t0, 100
	remu t1, a0, t0
	bne t1, zero, end_leaf
	li t0, 400
	rem t1, a0, t0
	bne t1, zero, end_not_leaf
end_leaf:
	la t2, day_in_month_leaf
	j continue_get_day
end_not_leaf:
	la t2, day_in_month
	j continue_get_day
