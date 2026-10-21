start:
	mov eax, cr4
	or ax, 600h			; OSFXSR | OSXMMEXCPT
	mov cr4, eax
	call run
	mov dx, s_passes
	mov ah, 9
	int 21h
	mov ax, [passes]
	call printdec
	mov dx, s_nl
	mov ah, 9
	int 21h
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

; di = expected (16 bytes), dx = name ('$' terminated); prints FAIL lines and counts PASS silently
check:
	push dx
	mov si, res
	mov cx, 16
	repe cmpsb
	pop dx
	jne .fail
	inc word [passes]
	ret
.fail:
	inc byte [fails]
	push dx
	mov dx, s_fail
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

printdec:
	xor cx, cx
	mov bx, 10
.l:	xor dx, dx
	div bx
	push dx
	inc cx
	test ax, ax
	jnz .l
.p:	pop dx
	add dl, '0'
	mov ah, 2
	int 21h
	loop .p
	ret

s_passes:	db 'PASSES=$'
s_fail:	db 'FAIL $'
s_nl:	db 13, 10, '$'
s_done:	db 'DONE fails=$'
fails:	db 0
passes:	dw 0
