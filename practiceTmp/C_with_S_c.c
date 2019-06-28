extern void asm_print(char *,int);
void c_print(char *str){
	int length = 0;
	while(str[length++]);
	asm_print(str,length);
}