; Guest test for DOSBox-X: results of the SSE2 instructions that are implemented.
; Needs "enable sse2 = true" and cputype=pentium_iii. Build: nasm -f bin sse2.asm -o SSE2.COM.
; Each test clears `res`, runs instructions that leave the result in `res` (16 bytes) and
; compares it with an expected 16-byte value; one PASS/FAIL line per test.
	org 100h
	cpu p4

start:
	mov eax, cr4
	or ax, 600h			; OSFXSR | OSXMMEXCPT
	mov cr4, eax
	call run
	mov dx, s_done
	mov ah, 9
	int 21h
	movzx ax, byte [fails]
	aam
	add ax, 3030h
	mov bx, ax
	mov dl, bh
	mov ah, 2
	int 21h
	mov dl, bl
	mov ah, 2
	int 21h
	mov dx, s_nl
	mov ah, 9
	int 21h
	mov al, [fails]
	mov ah, 4Ch
	int 21h

; di = expected (16 bytes), dx = name ('$' terminated)
check:
	push dx
	mov si, res
	mov cx, 16
	repe cmpsb
	pop dx
	jne .fail
	push dx
	mov dx, s_pass
	jmp .print
.fail:
	inc byte [fails]
	push dx
	mov dx, s_fail
.print:
	mov ah, 9
	int 21h
	pop dx
	mov ah, 9
	int 21h
	mov dx, s_nl
	mov ah, 9
	int 21h
	ret

%macro CLR 0
	xor eax, eax
	mov [res], eax
	mov [res+4], eax
	mov [res+8], eax
	mov [res+12], eax
%endmacro

%macro CHK 2			; name, expected label
	jmp short %%go
%%n:	db %1, '$'
%%go:
	mov dx, %%n
	mov di, %2
	call check
%endmacro

run:
	; ---- moves
	CLR
	movupd xmm0, [va]
	movupd [res], xmm0
	CHK "movupd load/store", va
	CLR
	movapd xmm0, [va]
	movapd [res], xmm0
	CHK "movapd load/store", va
	CLR
	movups xmm0, [v9]
	movsd xmm0, [va]
	movups [res], xmm0
	CHK "movsd xmm,m64 zeroes the upper half", e_lo_a_zero
	CLR
	movups xmm0, [v9]
	movups xmm1, [va]
	movsd xmm0, xmm1
	movups [res], xmm0
	CHK "movsd xmm,xmm keeps the upper half", e_movsd_rr
	CLR
	movups xmm1, [va]
	movsd [res], xmm1
	CHK "movsd m64,xmm", e_lo_a_zero
	CLR
	movups xmm0, [va]
	movlpd xmm0, [vb]
	movups [res], xmm0
	CHK "movlpd xmm,m64", e_movlpd
	CLR
	movups xmm0, [va]
	movhpd xmm0, [vb]
	movups [res], xmm0
	CHK "movhpd xmm,m64", e_movhpd
	CLR
	movups xmm0, [va]
	movlpd [res], xmm0
	CHK "movlpd m64,xmm", e_lo_a_zero
	CLR
	movups xmm0, [va]
	movhpd [res], xmm0
	CHK "movhpd m64,xmm", e_hi_a_zero
	CLR
	movups xmm0, [va]
	movntpd [res], xmm0
	CHK "movntpd", va
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	unpcklpd xmm0, xmm1
	movups [res], xmm0
	CHK "unpcklpd", e_unpckl
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	unpckhpd xmm0, xmm1
	movups [res], xmm0
	CHK "unpckhpd", e_unpckh
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	shufpd xmm0, xmm1, 1
	movups [res], xmm0
	CHK "shufpd 1", e_shuf1
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	shufpd xmm0, xmm1, 2
	movups [res], xmm0
	CHK "shufpd 2", e_shuf2

	; ---- packed arithmetic
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	addpd xmm0, xmm1
	movups [res], xmm0
	CHK "addpd", e_addpd
	CLR
	movups xmm0, [va]
	subpd xmm0, [vb]
	movups [res], xmm0
	CHK "subpd m128", e_subpd
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	mulpd xmm0, xmm1
	movups [res], xmm0
	CHK "mulpd", e_mulpd
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	divpd xmm0, xmm1
	movups [res], xmm0
	CHK "divpd", e_divpd
	CLR
	movups xmm1, [vc]
	sqrtpd xmm0, xmm1
	movups [res], xmm0
	CHK "sqrtpd", e_sqrtpd
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	minpd xmm0, xmm1
	movups [res], xmm0
	CHK "minpd", e_minpd
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	maxpd xmm0, xmm1
	movups [res], xmm0
	CHK "maxpd", e_maxpd

	; ---- scalar arithmetic: the upper half of the destination stays
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	addsd xmm0, xmm1
	movups [res], xmm0
	CHK "addsd", e_addsd
	CLR
	movups xmm0, [va]
	subsd xmm0, [vb]
	movups [res], xmm0
	CHK "subsd m64", e_subsd
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	mulsd xmm0, xmm1
	movups [res], xmm0
	CHK "mulsd", e_mulsd
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	divsd xmm0, xmm1
	movups [res], xmm0
	CHK "divsd", e_divsd
	CLR
	movups xmm0, [va]
	movups xmm1, [vc]
	sqrtsd xmm0, xmm1
	movups [res], xmm0
	CHK "sqrtsd", e_sqrtsd
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	minsd xmm0, xmm1
	movups [res], xmm0
	CHK "minsd", e_minsd
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	maxsd xmm0, xmm1
	movups [res], xmm0
	CHK "maxsd", e_maxsd
	; NaN and zero rules: MIN/MAX return the second operand
	CLR
	movups xmm0, [vnan]
	movups xmm1, [va]
	minsd xmm0, xmm1
	movups [res], xmm0
	CHK "minsd NaN, x = x", e_nan_minmax1
	CLR
	movups xmm0, [va]
	movups xmm1, [vnan]
	maxsd xmm0, xmm1
	movups [res], xmm0
	CHK "maxsd x, NaN = NaN", e_nan_minmax2

	; ---- logic
	CLR
	movups xmm0, [m1]
	movups xmm1, [m2]
	andpd xmm0, xmm1
	movups [res], xmm0
	CHK "andpd", e_andpd
	CLR
	movups xmm0, [m1]
	movups xmm1, [m2]
	andnpd xmm0, xmm1
	movups [res], xmm0
	CHK "andnpd", e_andnpd
	CLR
	movups xmm0, [m1]
	movups xmm1, [m2]
	orpd xmm0, xmm1
	movups [res], xmm0
	CHK "orpd", e_orpd
	CLR
	movups xmm0, [m1]
	movups xmm1, [m2]
	xorpd xmm0, xmm1
	movups [res], xmm0
	CHK "xorpd", e_xorpd

	; ---- comparisons (flags ZF PF CF)
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	ucomisd xmm0, xmm1
	pushf
	pop ax
	and ax, 45h
	mov [res], ax
	CHK "ucomisd greater", e_f_gt
	CLR
	movups xmm0, [vb]
	movups xmm1, [va]
	comisd xmm0, xmm1
	pushf
	pop ax
	and ax, 45h
	mov [res], ax
	CHK "comisd less", e_f_lt
	CLR
	movups xmm0, [va]
	comisd xmm0, xmm0
	pushf
	pop ax
	and ax, 45h
	mov [res], ax
	CHK "comisd equal", e_f_eq
	CLR
	movups xmm0, [va]
	movups xmm1, [vnan]
	ucomisd xmm0, xmm1
	pushf
	pop ax
	and ax, 45h
	mov [res], ax
	CHK "ucomisd unordered", e_f_un
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	cmpltpd xmm0, xmm1
	movups [res], xmm0
	CHK "cmpltpd", e_cmpltpd
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	cmpnltpd xmm0, xmm1
	movups [res], xmm0
	CHK "cmpnltpd", e_cmpnltpd
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	cmpeqsd xmm0, xmm1
	movups [res], xmm0
	CHK "cmpeqsd keeps the upper half", e_cmpeqsd
	CLR
	movups xmm0, [vnan]
	movups xmm1, [va]
	cmpnltsd xmm0, xmm1
	movups [res], xmm0
	CHK "cmpnltsd NaN is true", e_cmpnltsd_nan
	CLR
	movups xmm0, [vnan]
	movups xmm1, [va]
	cmpunordsd xmm0, xmm1
	movups [res], xmm0
	CHK "cmpunordsd", e_cmpunordsd
	CLR
	movups xmm0, [va]
	movups xmm1, [vb]
	cmpltsd xmm0, xmm1
	movups [res], xmm0
	CHK "cmpltsd", e_cmpltsd

	; ---- movmskpd
	CLR
	movups xmm0, [vneg1]
	movmskpd eax, xmm0
	mov [res], eax
	CHK "movmskpd (-1.0, 2.0)", e_msk1
	CLR
	movups xmm0, [vneg2]
	movmskpd eax, xmm0
	mov [res], eax
	CHK "movmskpd (-1.0, -2.0)", e_msk3

	; ---- conversions with integers
	CLR
	movups xmm0, [va]
	mov eax, -7
	cvtsi2sd xmm0, eax
	movups [res], xmm0
	CHK "cvtsi2sd", e_cvtsi2sd
	CLR
	movups xmm0, [vtr]
	cvttsd2si eax, xmm0
	mov [res], eax
	CHK "cvttsd2si -2.9 = -2", e_m2
	CLR
	movups xmm0, [vbig]
	cvttsd2si eax, xmm0
	mov [res], eax
	CHK "cvttsd2si 3e10 = indefinite", e_indef
	CLR
	movups xmm0, [vnan]
	cvttsd2si eax, xmm0
	mov [res], eax
	CHK "cvttsd2si NaN = indefinite", e_indef
	CLR
	movups xmm0, [v25]
	cvtsd2si eax, xmm0
	mov [res], eax
	CHK "cvtsd2si 2.5 = 2 (nearest even)", e_2
	CLR
	movups xmm0, [v35]
	cvtsd2si eax, xmm0
	mov [res], eax
	CHK "cvtsd2si 3.5 = 4", e_4
	ldmxcsr [mx_down]
	CLR
	movups xmm0, [v25]
	cvtsd2si eax, xmm0
	mov [res], eax
	CHK "cvtsd2si 2.5 rounding down = 2", e_2
	ldmxcsr [mx_up]
	CLR
	movups xmm0, [v25]
	cvtsd2si eax, xmm0
	mov [res], eax
	CHK "cvtsd2si 2.5 rounding up = 3", e_3
	ldmxcsr [mx_def]

	; ---- conversions between single and double
	CLR
	movups xmm0, [va]
	movups xmm1, [vf]
	cvtss2sd xmm0, xmm1
	movups [res], xmm0
	CHK "cvtss2sd", e_cvtss2sd
	CLR
	movups xmm0, [vfill]
	movups xmm1, [va]
	cvtsd2ss xmm0, xmm1
	movups [res], xmm0
	CHK "cvtsd2ss keeps the rest", e_cvtsd2ss
	CLR
	movups xmm1, [vf]
	cvtps2pd xmm0, xmm1
	movups [res], xmm0
	CHK "cvtps2pd", e_cvtps2pd
	CLR
	movups xmm1, [va]
	cvtpd2ps xmm0, xmm1
	movups [res], xmm0
	CHK "cvtpd2ps", e_cvtpd2ps
	ret

s_pass:	db 'PASS $'
s_fail:	db 'FAIL $'
s_nl:	db 13, 10, '$'
s_done:	db 'DONE fails=$'
fails:	db 0
mx_def:	dd 1F80h
mx_down: dd 3F80h
mx_up:	dd 5F80h

	align 16
res:	times 16 db 0
va:	dq 1.5, 2.25
vb:	dq 0.5, 4.0
vc:	dq 4.0, 2.25
v9:	dq 9.0, 9.0
vnan:	dq 0x7FF8000000000000, 0x4000000000000000	; NaN, 2.0
vneg1:	dq -1.0, 2.0
vneg2:	dq -1.0, -2.0
vtr:	dq -2.9, 0.0
vbig:	dq 3.0e10, 0.0
v25:	dq 2.5, 0.0
v35:	dq 3.5, 0.0
vf:	dd 1.5, 2.25, 9.0, 9.0
vfill:	dd 0x11111111, 0x11111111, 0x11111111, 0x11111111
m1:	dq 0xFFFF0000FFFF0000, 0x0F0F0F0F0F0F0F0F
m2:	dq 0x00FF00FF00FF00FF, 0xFFFFFFFFFFFFFFFF

e_lo_a_zero:	dq 1.5, 0.0
e_hi_a_zero:	dq 2.25, 0.0
e_movsd_rr:	dq 1.5, 9.0
e_movlpd:	dq 0.5, 2.25
e_movhpd:	dq 1.5, 0.5
e_unpckl:	dq 1.5, 0.5
e_unpckh:	dq 2.25, 4.0
e_shuf1:	dq 2.25, 0.5
e_shuf2:	dq 1.5, 4.0
e_addpd:	dq 2.0, 6.25
e_subpd:	dq 1.0, -1.75
e_mulpd:	dq 0.75, 9.0
e_divpd:	dq 3.0, 0.5625
e_sqrtpd:	dq 2.0, 1.5
e_minpd:	dq 0.5, 2.25
e_maxpd:	dq 1.5, 4.0
e_addsd:	dq 2.0, 2.25
e_subsd:	dq 1.0, 2.25
e_mulsd:	dq 0.75, 2.25
e_divsd:	dq 3.0, 2.25
e_sqrtsd:	dq 2.0, 2.25
e_minsd:	dq 0.5, 2.25
e_maxsd:	dq 1.5, 2.25
e_nan_minmax1:	dq 1.5, 2.0
e_nan_minmax2:	dq 0x7FF8000000000000, 2.25
e_andpd:	dq 0x00FF000000FF0000, 0x0F0F0F0F0F0F0F0F
e_andnpd:	dq 0x000000FF000000FF, 0xF0F0F0F0F0F0F0F0
e_orpd:		dq 0xFFFF00FFFFFF00FF, 0xFFFFFFFFFFFFFFFF
e_xorpd:	dq 0xFF0000FFFF0000FF, 0xF0F0F0F0F0F0F0F0
e_f_gt:		dq 0, 0
e_f_lt:		dq 1, 0
e_f_eq:		dq 40h, 0
e_f_un:		dq 45h, 0
e_cmpltpd:	dq 0, 0xFFFFFFFFFFFFFFFF
e_cmpnltpd:	dq 0xFFFFFFFFFFFFFFFF, 0
e_cmpeqsd:	dq 0, 2.25
e_cmpnltsd_nan:	dq 0xFFFFFFFFFFFFFFFF, 2.0
e_cmpunordsd:	dq 0xFFFFFFFFFFFFFFFF, 2.0
e_cmpltsd:	dq 0, 2.25
e_msk1:		dq 1, 0
e_msk3:		dq 3, 0
e_cvtsi2sd:	dq -7.0, 2.25
e_m2:		dq 0xFFFFFFFE, 0
e_indef:	dq 0x80000000, 0
e_2:		dq 2, 0
e_3:		dq 3, 0
e_4:		dq 4, 0
e_cvtss2sd:	dq 1.5, 2.25
e_cvtsd2ss:	dd 0x3FC00000, 0x11111111, 0x11111111, 0x11111111
e_cvtps2pd:	dq 1.5, 2.25
e_cvtpd2ps:	dd 0x3FC00000, 0x40100000, 0, 0
