
#include "print.h"
#include "init.h"
#include "debug.h"

int in_a = 5, in_b = 10, out_sum;

int main(void)
{
   put_str("I am kernel\n");

   init_all();

   ASSERT(1==2);


	while(1);

   return 0;
}