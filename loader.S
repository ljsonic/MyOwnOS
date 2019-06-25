%include "boot.inc"
   section loader vstart=LOADER_BASE_ADDR
   LOADER_STACK_TOP equ LOADER_BASE_ADDR
   
;构建gdt及其内部的描述符
   GDT_BASE:   dd    0x00000000 
	       dd    0x00000000

   CODE_DESC:  dd    0x0000FFFF 
	       dd    DESC_CODE_HIGH4

   DATA_STACK_DESC:  dd    0x0000FFFF
		     dd    DESC_DATA_HIGH4

   VIDEO_DESC: dd    0x80000007	       ; limit=(0xbffff-0xb8000)/4k=0x7
	       dd    DESC_VIDEO_HIGH4  ; 此时dpl为0

   GDT_SIZE   equ   $ - GDT_BASE
   GDT_LIMIT   equ   GDT_SIZE -	1 
   times 60 dq 0					 ; 此处预留60个描述符的空位(slot)
   SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0         ; 相当于(CODE_DESC - GDT_BASE)/8 + TI_GDT + RPL0
   SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0	 ; 同上
   SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0	 ; 同上 

   ; total_mem_bytes用于保存内存容量,以字节为单位,此位置比较好记。
   ; 当前偏移loader.bin文件头0x200字节,loader.bin的加载地址是0x900,
   ; 故total_mem_bytes内存中的地址是0xb00.将来在内核中咱们会引用此地址
   total_mem_bytes dd 0					 
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   ;以下是定义gdt的指针，前2字节是gdt界限，后4字节是gdt起始地址
   gdt_ptr  dw  GDT_LIMIT 
	    dd  GDT_BASE

   ;人工对齐:total_mem_bytes4字节+gdt_ptr6字节+ards_buf244字节+ards_nr2,共256字节
   ards_buf times 244 db 0
   ards_nr dw 0		      ;用于记录ards结构体数量	

loader_start:

	mov byte [gs:160], 'T'

;INT15 eax = 0xe820,edx = 534D4150h('SMAP')

	xor ebx, ebx
	mov edx, 0x534d150
	mov di, ards_buf

.e820_mem_get_loop:
	
	mov eax, 0x0000e820
	mov ecx, 20
	int 0x15
	 jc .e820_failed_so_try_e801
	add di, cx
	inc word [ards_nr]
	cmp ebx, 0
	jnz .e820_mem_get_loop


;遍历 ards 结构，找出，base_add_low+length_low 的最大值

	mov cx, [ards_nr]
	mov ebx, ards_buf
	xor edx, edx

.find_max_mem_area:
	mov eax, [ebx]
	add eax, [ebx + 8]
	add ebx, 20
	cmp edx, eax

	jge .next_ards
	mov edx,eax

.next_ards:
	loop .find_max_mem_area
	jmp .mem_get_ok


;INT15 ax = 0xe801,最大支持4G
	
.e820_failed_so_try_e801:
	mov ax, 0xe801
	int 0x15
	jc .e801_failed_so_try88

;低15MB内存，单位是KB
	mov cx, 0x400
	mul cx
	shl edx, 16
	and eax, 0x0000FFFF
	or edx, eax
	add edx, 0x100000
	mov esi, edx

	xor eax, eax
	mov ax, bx
	mov ecx, 0x10000
	mul ecx
	add esi, eax
	mov edx, esi
	jmp .mem_get_ok

.e801_failed_so_try88:
	mov ah, 0x88
	int 0x15
	jc .error_hlt
	and eax, 0x0000FFFF
	mov cx, 0x400
	mul cx
	shl edx, 16
	or edx, eax
	add edx, 0x100000

.error_hlt:
	jmp $

.mem_get_ok:
	mov [total_mem_bytes], edx
	jmp .into_pe

.into_pe:

;INT0x10  功能号0x13，打印字符串

	loadermsg db '2 loader in real.'

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
	mov esp, LOADER_STACK_TOP
	mov ax, SELECTOR_VIDEO

	mov gs, ax

	mov byte [gs:320], 'T'


   call setup_page
   sgdt [gdt_ptr]

   mov ebx, [gdt_ptr + 2]
   or dword [ebx + 0x18 + 4], 0xc0000000
   add dword [gdt_ptr + 2], 0xc0000000
   add esp, 0xc0000000
   mov eax,PAGE_DIR_TABLE_POS
   mov cr3, eax
   mov eax, cr0
   or eax , 0x80000000
   mov cr0, eax

   lgdt[gdt_ptr]

   mov byte [gs:320],'V'

   jmp $


;----------------- 创建页目录及页表 ---------------
setup_page:
   mov ecx, 4096
   mov esi, 0
.clear_page_dir:
   mov byte [PAGE_DIR_TABLE_POS + esi],0
   inc esi
   loop .clear_page_dir
;开始创建页目录项
.create_pde:
   mov eax, PAGE_DIR_TABLE_POS
   add eax, 0x1000
   mov ebx, eax

   or eax, PG_US_U | PG_RW_W | PG_P
   mov [PAGE_DIR_TABLE_POS + 0x0],eax
   mov [PAGE_DIR_TABLE_POS + 0xc00],eax

   sub eax, 0x1000
   mov [PAGE_DIR_TABLE_POS + 4092],eax

;创建页表项
   mov ecx, 256
   mov esi, 0
   mov edx, PG_US_U | PG_RW_W | PG_P
.create_pte:
   mov [ebx + esi*4],edx
   add edx, 4096
   inc esi
   loop .create_pte
;创建内核其他页表的PDE
   mov eax, PAGE_DIR_TABLE_POS
   add eax, 0x2000
   or eax, PG_US_U | PG_RW_W | PG_P
   mov ebx, PAGE_DIR_TABLE_POS
   mov ecx, 254
   mov esi, 769
.create_kernel_pde:
   mov [ebx + esi*4],eax
   inc esi
   add eax, 0x1000
   loop .create_kernel_pde
   ret






