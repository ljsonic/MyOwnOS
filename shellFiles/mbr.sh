nasm -I ../boot/include/ -o mbr.bin mbr.S && dd if=./mbr.bin of=../../hd60M.img bs=512 count=1  conv=notrunc
