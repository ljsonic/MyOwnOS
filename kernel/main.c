
#include "print.h"
#include "init.h"


int in_a = 5, in_b = 10, out_sum;

void main(void)
{
   put_str("I am kernel\n");
   put_int(0);
   put_char('\n');
   put_int(9);
   put_char('\n');
   put_int(0x00021a3f);
   put_char('\n');
   put_int(0x12345678);
   put_char('\n');
   put_int(0x00000000);

   asm("pusha; \
   		movl in_a, %eax; \
   		movl in_b, %ebx; \
   		addl %ebx, %eax;  \
   		movl %eax, out_sum; \
   	  	popa");
   put_int(out_sum);
	while(1);
}