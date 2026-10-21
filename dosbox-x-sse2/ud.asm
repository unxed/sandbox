; Guest test for DOSBox-X: does an instruction raise #UD (INT 6) or run?
; The table is at the end: TEST name, length, expected (1 = #UD, 0 = runs), bytes.
; Build: nasm -f bin ud.asm -o UD.COM. Output (stdout): one PASS/FAIL line per test.
; cputype must be pentium_iii (MMX and SSE). Assemble with -DSSE2 when the guest has "enable sse2 = true".
	org 100h
	cpu 686

start:
	xor ax, ax
	mov es, ax
	cli
	mov word [es:6*4], ud_handler
	mov [es:6*4+2], cs
	sti
	; CR4.OSFXSR | OSXMMEXCPT, otherwise SSE is #UD
	mov eax, cr4
	or ax, 600h
	mov cr4, eax
	; CPUID.1:EDX bit 26 (SSE2) and bit 19 (CLFLUSH)
	mov eax, 1
	cpuid
	mov [cpuid_edx], edx
	mov dx, s_cpuid
	mov ah, 9
	int 21h
	mov eax, [cpuid_edx]
	shr eax, 26
	and al, 1
	add al, '0'
	mov dl, al
	mov ah, 2
	int 21h
	mov dx, s_nl
	mov ah, 9
	int 21h
%ifdef SSE2
	cmp byte [cpuid_edx+3], 0
	mov al, [cpuid_edx+3]
	and al, 04h
	jnz .cpuid_ok
	inc byte [fails]
	mov dx, s_cpuid_fail
	mov ah, 9
	int 21h
.cpuid_ok:
%else
	mov al, [cpuid_edx+3]
	and al, 04h
	jz .cpuid_ok
	inc byte [fails]
	mov dx, s_cpuid_fail
	mov ah, 9
	int 21h
.cpuid_ok:
%endif
	mov si, table
next:
	mov al, [si]
	test al, al
	jz done
	mov [curlen], al
	mov al, [si+1]
	mov [expect], al
	lea bx, [si+2]
	mov di, exe
	mov cx, 5
.copy:
	mov al, [bx]
	mov [di], al
	inc bx
	inc di
	loop .copy
	movzx bx, byte [curlen]
	mov byte [exe+bx], 0C3h		; ret right after the instruction
	mov byte [udflag], 0
	call exe
	db 0Fh, 77h			; emms
	mov al, [udflag]
	cmp al, [expect]
	jne .fail
	mov dx, s_pass
	jmp .print
.fail:
	inc byte [fails]
	mov dx, s_fail
.print:
	mov ah, 9
	int 21h
	lea dx, [si+7]
	mov ah, 9
	int 21h
	mov dx, s_ud
	mov ah, 9
	int 21h
	mov dl, [udflag]
	add dl, '0'
	mov ah, 2
	int 21h
	mov dx, s_nl
	mov ah, 9
	int 21h
	lea di, [si+7]
.scan:
	cmp byte [di], '$'
	je .eos
	inc di
	jmp .scan
.eos:
	lea si, [di+1]
	jmp next
done:
	mov dx, s_done
	mov ah, 9
	int 21h
	movzx ax, byte [fails]
	aam				; ah = tens, al = ones
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

ud_handler:
	push bp
	mov bp, sp
	push ax
	movzx ax, byte [cs:curlen]
	add [bp+2], ax			; skip the instruction
	mov byte [cs:udflag], 1
	pop ax
	pop bp
	iret

s_pass:	db 'PASS $'
s_fail:	db 'FAIL $'
s_ud:	db '  ud=$'
s_nl:	db 13, 10, '$'
s_done:	db 'DONE fails=$'
s_cpuid:	db 'CPUID.1:EDX[26]=$'
s_cpuid_fail:	db 'FAIL cpuid sse2 bit', 13, 10, '$'
cpuid_edx:	dd 0
curlen:	db 0
expect:	db 0
udflag:	db 0
fails:	db 0
exe:	times 8 db 0

%macro TEST 4+
	db %2, %3
%%b:	db %4
	times 5-($-%%b) db 90h
	db %1, '$'
%endmacro

%ifdef SSE2
FENCE equ 0
%else
FENCE equ 1
%endif

table:
	; SSE2 fences and CLFLUSH: run with "enable sse2", #UD without
	TEST "lfence", 3, FENCE, 0Fh,0AEh,0E8h
	TEST "mfence", 3, FENCE, 0Fh,0AEh,0F0h
	TEST "clflush [bx] (0F AE /7 m)", 3, FENCE, 0Fh,0AEh,3Fh
	TEST "0F AE /6 m is #UD", 3, 1, 0Fh,0AEh,37h
	TEST "sfence", 3, 0, 0Fh,0AEh,0F8h
	; legacy MMX and SSE: must run
	TEST "mmx pxor mm0,mm1", 3, 0, 0Fh,0EFh,0C1h
	TEST "mmx movq mm0,mm1", 3, 0, 0Fh,06Fh,0C1h
	TEST "mmx punpcklbw mm0,mm1", 3, 0, 0Fh,060h,0C1h
	TEST "mmx movd mm0,eax", 3, 0, 0Fh,06Eh,0C0h
	TEST "mmx psllq mm0,1", 4, 0, 0Fh,073h,0F0h,01h
	TEST "mmx pshufw mm0,mm1,0", 4, 0, 0Fh,070h,0C1h,00h
	TEST "mmx paddb mm0,mm1", 3, 0, 0Fh,0FCh,0C1h
	TEST "sse xorps xmm0,xmm1", 3, 0, 0Fh,057h,0C1h
	TEST "sse movups xmm0,xmm1", 3, 0, 0Fh,010h,0C1h
	TEST "sse movss xmm0,xmm1", 4, 0, 0F3h,0Fh,010h,0C1h
	; SSE2 forms of MMX opcodes: SSE2 is not emulated, so #UD (before the fix they ran as MMX)
	TEST "sse2 pxor xmm0,xmm1 (66 0F EF)", 4, 1, 66h,0Fh,0EFh,0C1h
	TEST "sse2 movdqa xmm0,xmm1 (66 0F 6F)", 4, 1, 66h,0Fh,06Fh,0C1h
	TEST "sse2 movdqu xmm0,xmm1 (F3 0F 6F)", 4, 1, 0F3h,0Fh,06Fh,0C1h
	TEST "sse2 movq xmm0,xmm1 (F3 0F 7E)", 4, 1, 0F3h,0Fh,07Eh,0C1h
	TEST "sse2 movd xmm0,eax (66 0F 6E)", 4, 1, 66h,0Fh,06Eh,0C0h
	TEST "sse2 movdqa xmm1,xmm0 (66 0F 7F)", 4, 1, 66h,0Fh,07Fh,0C1h
	TEST "sse2 pshufd (66 0F 70)", 5, 1, 66h,0Fh,070h,0C1h,00h
	TEST "sse2 pshuflw (F2 0F 70)", 5, 1, 0F2h,0Fh,070h,0C1h,00h
	TEST "sse2 pshufhw (F3 0F 70)", 5, 1, 0F3h,0Fh,070h,0C1h,00h
	TEST "sse2 punpcklbw xmm (66 0F 60)", 4, 1, 66h,0Fh,060h,0C1h
	TEST "sse2 paddb xmm (66 0F FC)", 4, 1, 66h,0Fh,0FCh,0C1h
	TEST "sse2 paddq xmm (66 0F D4)", 4, 1, 66h,0Fh,0D4h,0C1h
	TEST "sse2 psllq xmm,1 (66 0F 73)", 5, 1, 66h,0Fh,073h,0F0h,01h
	TEST "sse2 pcmpeqb xmm (66 0F 74)", 4, 1, 66h,0Fh,074h,0C1h
	TEST "sse2 pmullw xmm (66 0F D5)", 4, 1, 66h,0Fh,0D5h,0C1h
	TEST "sse2 psubb xmm (66 0F F8)", 4, 1, 66h,0Fh,0F8h,0C1h
	TEST "sse2 xorpd xmm (66 0F 57)", 4, 1, 66h,0Fh,057h,0C1h
	TEST "sse2 movsd xmm (F2 0F 10)", 4, 1, 0F2h,0Fh,010h,0C1h
	TEST "sse2 movq xmm,xmm (66 0F D6)", 4, 1, 66h,0Fh,0D6h,0C1h
	db 0
