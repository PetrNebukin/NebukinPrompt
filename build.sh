#!/bin/sh

# Этот скрипт собирает загрузчик NebukinPrompt, ядро и программы
# с помощью NASM, а затем создает образы дискет и компакт-дисков (в Linux).

# Только root может монтировать образ floppy, как виртуальный
# диск (loopback mounting), для пофайлового копирования.


if test "`whoami`" != "root" ; then
	echo "You must be logged in as root to build (for loopback mounting)"
	echo "Enter 'su' or 'sudo bash' to switch to root"
	exit
fi


if [ ! -e disk_images/nebukinprompt.flp ]
then
	echo ">>> Creating new floppy image..."
	mkdosfs -C disk_images/nebukinprompt.flp 1440 || exit
	chown $SUDO_USER disk_images/nebukinprompt.flp
fi


echo ">>> Assembling bootloader..."

nasm -O0 -w+orphan-labels -f bin -o source/bootload/bootload.bin source/bootload/bootload.asm || exit


echo ">>> Assembling TachyonOS kernel..."

cd source
nasm -O0 -w+orphan-labels -f bin -o kernel.bin kernel.asm || exit
nasm -O0 -w+orphan-labels -f bin -o zkernel.sys zkernel.asm || exit
cd ..


echo ">>> Assembling programs..."

cd programs

for i in *.asm
do
	nasm -O0 -w+orphan-labels -f bin $i -o `basename $i .asm`.bin || exit
done

cd ..


echo ">>> Adding bootloader to floppy image..."

dd status=noxfer conv=notrunc if=source/bootload/bootload.bin of=disk_images/nebukinprompt.flp || exit


echo ">>> Copying TachyonOS kernel and programs..."

rm -rf tmp-loop

mkdir tmp-loop && mount -o loop -t vfat disk_images/nebukinprompt.flp tmp-loop && cp source/kernel.bin tmp-loop/ && cp source/zkernel.sys tmp-loop/

cp programs/*.bin programs/*.bas diskfiles/*.* tmp-loop

sleep 0.2

echo ">>> Unmounting loopback floppy..."

umount tmp-loop || exit

rm -rf tmp-loop

echo ">>> Creating CD-ROM ISO image..."

rm -f disk_images/tachyonos.iso
mkisofs -quiet -V 'NBKNPRPT' -input-charset iso8859-1 -o disk_images/tachyonos.iso -b nebukinprompt.flp disk_images/ || exit

echo '>>> Done!'