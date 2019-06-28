section .data
str: db "asm_print says hello world!", 0xa, 0
str_length equ $ - str

section .text
;extern c_print
global _start
_start:
	push str_length
	push str
	call asm_print
	add esp, 4

	mov eax, 1
	int 0x80


asm_print:
	push ebp
	mov ebp, esp
	mov eax, 4
	mov ebx, 1
	mov ecx, [ebp + 8]
	mov edx, [ebp + 12]
	int 0x80
	pop ebp
	ret
