%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LODER_STACK_TOP equ LOADER_BASE_ADDR
	jmp loader_start

;构建GDT及其内部的描述符

	GDT_BASE: dd 0x00000000
				dd 0x00000000
	CODE_DESC: dd 0x0000FFFF
				dd DESC_CODE_HIGH4
	DATA_STACK_DESC: dd 0x0000FFFF
						dd DESC_DATA_HIGH4
	VIDEO_DESC:	dd  0x80000007;
					dd DESC_VIDEO_HIGH4
	GDT_SIZE equ $ - GDT_BASE
	GDT_LIMIT equ GDT_SIZE - 1
	
	times 30 dq 0

	SELECTOR_CODE equ (0x0001 << 3) + TI_GDT + RPL0
	SELECTOR_DATA equ (0x0002 << 3) + TI_GDT + RPL0
	SELECTOR_VIDEO equ (0x0003 << 3) + TI_GDT + RPL0

	gdt_ptr dw GDT_LIMIT
				dd GDT_BASE
	loadermsg db '2 loader in real.'

loader_start:

;INT0x10  功能号0x13，打印字符串


	mov sp, LOADER_BASE_ADDR
	mov bp, loadermsg
	mov cx, 17
	mov ax, 0x1301
	mov bx, 0x001f
	mov dx, 0x1800
	int 0x10



;准备进入保护模式
	
	;打开A20
	in al, 0x92
	or al, 0000_0010b
	out 0x92, al

	;加载GDT
	lgdt [gdt_ptr]

	;CR0第0位置1
	mov eax, cr0
	or eax, 0x00000001
	mov cr0, eax




	jmp dword SELECTOR_CODE: p_mode_start


[bits 32]
p_mode_start:

	

	mov ax, SELECTOR_DATA
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov esp, LODER_STACK_TOP
	mov ax, SELECTOR_VIDEO

	mov byte [gs:160], 'T'

	mov gs, ax

	mov byte [gs:320], 'Q'

	jmp $

