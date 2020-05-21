#!/bin/bash -l

function stage_vmx() {
  cat << VMXFILE > "${1}.vmx"
.encoding = "UTF-8"
displayname = "${1}"
annotation = "${1}"
guestos = "otherlinux-64"
virtualHW.version = "8"
config.version = "8"
numvcpus = "1"
cpuid.coresPerSocket = "1"
memsize = "256"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
vmci0.present = "TRUE"
floppy0.present = "FALSE"
ide0:0.clientDevice = "FALSE"
ide0:0.present = "TRUE"
ide0:0.deviceType = "atapi-cdrom"
ide0:0.autodetect = "TRUE"
ide0:0.startConnected = "FALSE"
mks.enable3d = "false"
svga.autodetect = "false"
svga.vramSize = "4194304"
scsi0:0.present = "TRUE"
scsi0:0.deviceType = "disk"
scsi0:0.fileName = "$2"
scsi0:0.mode = "persistent"
scsi0:0.writeThrough = "false"
scsi0.virtualDev = "lsilogic"
scsi0.present = "TRUE"
vmci0.unrestricted = "false"
vcpu.hotadd = "false"
vcpu.hotremove = "false"
firmware = "bios"
mem.hotadd = "false"
VMXFILE
}

DISK_NAME=alpine-virthardened-$(date +%Y-%m-%d).qcow2
time sudo ./alpine-make-vm-image \
        --image-format qcow2 \
        --image-size 2G \
        --repositories-file example/repositories \
        --packages "$(cat example/packages)" \
        --script-chroot \
        $DISK_NAME -- ./example/configure.sh

echo "Converting to qcow2/KVM"
qemu-img convert -o compat=0.10 -f qcow2 -c -O qcow2 $DISK_NAME systemvm-kvm.qcow2

echo "Converting to vhd/XenServer"
qemu-img convert -f qcow2 -O raw $DISK_NAME img.raw
vhd-util convert -s 0 -t 1 -i img.raw -o stagefixed.vhd
faketime '2010-01-01' vhd-util convert -s 1 -t 2 -i stagefixed.vhd -o systemvm-xen.vhd
rm -f *.bak

echo "Converting to ova/VMware"
qemu-img convert -f qcow2 -O vmdk $DISK_NAME systemvm-vmware.vmdk
chmod 666 systemvm-vmware.vmdk
stage_vmx systemvm-vmware systemvm-vmware.vmdk
ovftool systemvm-vmware.vmx systemvm-vmware.ova
rm -f *vmx *vmdk
