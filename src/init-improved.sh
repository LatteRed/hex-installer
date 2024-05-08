#!/bin/bash

# Improved Exherbo installation script with better error handling and user control
# Based on the original init.sh but with fixes for the immediate reboot issue

STAGE_URL="https://stages.exherbolinux.org/x86_64-pc-linux-gnu"
STAGE_FILE="exherbo-x86_64-pc-linux-gnu-gcc-current.tar.xz"
SCRIPT_DIR=$PWD

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==========================================${NC}"
}

echo

if [ -f "params" ]; then
    source params
    print_status "The 'params' file has been found and loaded"
else
    print_warning "There is no 'params' file, default parameters will be used"
fi

# Function to detect and select disk
detect_and_select_disk() {
    print_status "Scanning for available disks..."
    
    # Get list of available block devices (excluding loop devices and partitions)
    local available_disks=()
    local disk_list=()
    
    # Find all block devices that are not partitions or loop devices
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            available_disks+=("$line")
        fi
    done < <(lsblk -d -n -o NAME,TYPE,SIZE,MODEL | grep -E 'disk|nvme' | awk '{print "/dev/" $1 " (" $3 " - " $4 ")"}')
    
    if [ ${#available_disks[@]} -eq 0 ]; then
        print_error "No suitable disks found!"
        exit 1
    fi
    
    if [ ${#available_disks[@]} -eq 1 ]; then
        # Only one disk found, use it automatically
        DISK=$(echo "${available_disks[0]}" | awk '{print $1}')
        print_status "Only one disk found: ${available_disks[0]}"
        read -rp "Use this disk for installation? [y/n] " confirm
        if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
            print_error "Installation cancelled by user"
            exit 1
        fi
    else
        # Multiple disks found, let user choose
        print_status "Multiple disks found:"
        echo
        for i in "${!available_disks[@]}"; do
            echo "$((i+1)). ${available_disks[i]}"
        done
        echo
        
        while true; do
            read -rp "Select disk number (1-${#available_disks[@]}): " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#available_disks[@]}" ]; then
                DISK=$(echo "${available_disks[$((choice-1))]}" | awk '{print $1}')
                print_status "Selected disk: ${available_disks[$((choice-1))]}"
                break
            else
                print_error "Invalid selection. Please enter a number between 1 and ${#available_disks[@]}"
            fi
        done
    fi
    
    # Final confirmation
    print_warning "You have selected: ${DISK}"
    print_warning "This disk will be completely wiped and Exherbo Linux will be installed on it."
    read -rp "Are you sure you want to continue? [y/n] " final_confirm
    if [[ ! "${final_confirm}" =~ ^[Yy]$ ]]; then
        print_error "Installation cancelled by user"
        exit 1
    fi
}

# Set the target device, show usage if more than one argument or --help is given
if [ -z "${DISK}" ]; then
    detect_and_select_disk
fi

if [ $# -gt 1 ] || [[ $1 == "--help" ]]; then
print_header "Exherbo Setup - Exherbo Linux Installation Script"
echo "Usage:"
echo "  ./init-improved.sh <device>    - Installs Exherbo Linux on the specified device"
echo "  ./init-improved.sh             - Installs Exherbo Linux on /dev/sda by default"
echo ""
echo "Options:"
echo "  <device>    - The target device for Exherbo Linux installation"
echo "                Example: ./init-improved.sh /dev/nvme0n1"
echo ""
echo "Description:"
echo "  Exherbo Setup is a simple script to automate the installation of Exherbo Linux."
echo "  It can be run with a specific target device or without any arguments,"
echo "  in which case it will use /dev/sda as the default installation target."
echo "  The script will automatically detect if you're using a BIOS or EFI based system."
echo ""
echo "  You can set some parameters through the 'params' file."
echo ""
echo "  WARNING: This script will format the target device and install Exherbo Linux."
echo "           Make sure to back up any important data on the device before proceeding."
echo ""
echo "For more information on Exherbo Linux installation, visit:"
echo "https://github.com/davlgd/exherbo-setup"
exit
elif [ $# -eq 1 ] && [ -b "$1" ]; then
    DISK=$1
fi

if [ ! -b "${DISK}" ]; then
    print_error "Invalid device: ${DISK}"
    exit 1
fi

bios_or_uefi() {
    if [ -d /sys/firmware/efi ]; then
        SYSTEM_TYPE="UEFI"
        print_status "UEFI system detected"
    else
        SYSTEM_TYPE="BIOS"
        print_status "BIOS system detected"
    fi
}

wipe_disk() {
    print_warning "You're about to wipe ${DISK}. This will destroy all data on this device!"
    read -rp "Do you want to continue? [y/n] "
    if [[ ! "${REPLY}" =~ ^[Yy]$ ]]; then
        echo
        print_error "Installation cancelled by user"
        exit 1
    fi

    print_status "Wiping disk ${DISK}..."
    wipefs -a "${DISK}"
    if [ $? -eq 0 ]; then
        print_status "Disk wiped successfully"
    else
        print_error "Failed to wipe disk"
        exit 1
    fi
}

ask_swap() {
    if [ -z "${SWAP_SIZE}" ]; then
        read -rp "Do you want to create a swap partition? [y/n] "
        if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
            echo -n "Enter the size of the swap partition (in GB): "
            read -r SWAP_SIZE
        fi
    fi

    if [ -n "${SWAP_SIZE}" ]; then
        if ! [[ "${SWAP_SIZE}" =~ ^[0-9]+$ ]] || [ "${SWAP_SIZE}" -lt 1 ] || [ "${SWAP_SIZE}" -gt 32 ]
        then
            print_error "Invalid swap size: ${SWAP_SIZE}"
            exit 1
        fi
    fi
}

format_disk() {
    print_status "Disk wiped successfully"
    echo
    print_status "Exherbo Linux will be installed on ${DISK}"
    echo
    echo "You need to create at least 2 partitions:"
    echo " - /     : Linux Filesystem"
    echo " - /boot : Linux Extended Boot"
    echo " - /efi  : EFI System (only for UEFI)"
    echo
    case ${SYSTEM_TYPE} in
    "UEFI")
        print_warning "cfdisk will be launched to allow configuration of disk partitions..."
        echo -n "IMPORTANT: SELECT 'Linux Extended Boot' TYPE FOR BOOT PARTITION AND WRITE!"
        echo
        echo && read -n 1 -s -r -p "Press any key to continue..."

        print_status "Creating partition table..."
        echo "label: gpt"   | sfdisk -W always ${DISK} > /dev/null 2>&1
        echo ", 512M, U"    | sfdisk -W always -a ${DISK} > /dev/null 2>&1
        echo ", 512M, L"    | sfdisk -W always -a ${DISK} > /dev/null 2>&1
        if [ "${SWAP_SIZE}" ]; then
            echo ", ${SWAP_SIZE}G, L" | sfdisk -W always -a ${DISK} > /dev/null 2>&1
        fi
        echo ","            | sfdisk -W always -a ${DISK} > /dev/null 2>&1
        print_status "Launching cfdisk for manual partition configuration..."
        cfdisk ${DISK}
        ;;
    "BIOS")
        print_status "Creating partitions for BIOS system..."
        echo ", 512M, U"    | sfdisk -W always ${DISK} > /dev/null 2>&1
        if [ "${SWAP_SIZE}" ]; then
            echo ", ${SWAP_SIZE}G, L" | sfdisk -W always -a ${DISK} > /dev/null 2>&1
        fi
        echo ","            | sfdisk -W always -a ${DISK} > /dev/null 2>&1
        ;;
    esac
}

get_disk_partitions() {
    case ${SYSTEM_TYPE} in
    "UEFI")
        if [[ "${DISK}" == /dev/sd* ]]; then
            PART_EFI="${DISK}1"
            PART_BOOT="${DISK}2"
            if [ "${SWAP_SIZE}" ]; then
                PART_SWAP="${DISK}3"
                PART_ROOT="${DISK}4"
            else
                PART_ROOT="${DISK}3"
            fi
        elif [[ "${DISK}" == /dev/nvme* ]]; then
            PART_EFI="${DISK}p1"
            PART_BOOT="${DISK}p2"
            if [ "${SWAP_SIZE}" ]; then
                PART_SWAP="${DISK}p3"
                PART_ROOT="${DISK}p4"
            else
                PART_ROOT="${DISK}p3"
            fi
        else
            print_error "Storage device not recognized"
            exit 1
        fi
        ;;
    "BIOS")
        if [[ "${DISK}" == /dev/sd* ]]; then
            PART_BOOT="${DISK}1"
            if [ "${SWAP_SIZE}" ]; then
                PART_SWAP="${DISK}2"
                PART_ROOT="${DISK}3"
            else
                PART_ROOT="${DISK}2"
            fi
        elif [[ "${DISK}" == /dev/nvme* ]]; then
            PART_BOOT="${DISK}p1"
            if [ "${SWAP_SIZE}" ]; then
                PART_SWAP="${DISK}p2"
                PART_ROOT="${DISK}p3"
            else
                PART_ROOT="${DISK}p2"
            fi
        else
            print_error "Storage device not recognized"
            exit 1
        fi
        ;;
    esac
}

create_partitions() {
    print_status "Creating filesystems..."
    # Create the filesystems
    # - FAT32 for the Boot & EFI partition
    # - ext4 for the root partition
    # - Label the partitions
    case ${SYSTEM_TYPE} in
        "UEFI")
            print_status "Formatting EFI partition: ${PART_EFI}"
            mkfs.fat -F 32 "${PART_EFI}" -n EFI
            fatlabel "${PART_EFI}" EFI
            
            print_status "Formatting boot partition: ${PART_BOOT}"
            mkfs.fat -F 32 "${PART_BOOT}" -n BOOT
            e2label "${PART_BOOT}" BOOT
            ;;
        "BIOS")
            print_status "Formatting boot partition: ${PART_BOOT}"
            mkfs.ext2 "${PART_BOOT}" -L BIOS
            e2label "${PART_BOOT}" BIOS
            ;;
    esac

    print_status "Formatting root partition: ${PART_ROOT}"
    mkfs.ext4 "${PART_ROOT}" -L EXHERBO
    e2label "${PART_ROOT}" EXHERBO

    if [ "${SWAP_SIZE}" ]; then
        print_status "Creating swap partition: ${PART_SWAP}"
        mkswap "${PART_SWAP}" -L SWAP
    fi
}

mount_stage() {
    print_status "Creating mountpoint and mounting root partition..."
    # Create the mountpoint and mount the root partition
    mkdir -p /mnt/exherbo/
    mount "${PART_ROOT}" /mnt/exherbo
    cd /mnt/exherbo

    print_status "Downloading Exherbo stage tarball..."
    # Download and extract the stage3 tarball
    curl -Os "${STAGE_URL}/${STAGE_FILE}"

    # Download and verify the checksum
    print_status "Verifying download integrity..."
    curl -Os "${STAGE_URL}/${STAGE_FILE}.sha256sum"
    if diff -q "${STAGE_FILE}.sha256sum" <(sha256sum ${STAGE_FILE}) > /dev/null; then
        print_status "File integrity verified successfully"
    else
        print_error "File integrity check failed!"
        exit 1
    fi

    print_status "Extracting Exherbo stage tarball..."
    # Extract the tarball and remove it
    tar xJpf "${STAGE_FILE}"
    rm "${STAGE_FILE}*"
}

prepare_chroot() {
    print_status "Preparing chroot environment..."
    # Define the partition to be mounted at boot
    case ${SYSTEM_TYPE} in
        "UEFI")
            cat <<EOF > /mnt/exherbo/etc/fstab
# <fs>          <mountpoint>    <type> <opts>           <dump/pass>
${PART_ROOT}    /               ext4   defaults,noatime 0 1
${PART_BOOT}    /boot           vfat   defaults         0 0
${PART_EFI}     /efi            vfat   umask=0077       0 0
EOF
            ;;
        "BIOS")
            cat <<EOF > /mnt/exherbo/etc/fstab
# <fs>          <mountpoint>    <type> <opts>           <dump/pass>
${PART_ROOT}    /               ext4   defaults,noatime 0 1
${PART_BOOT}    /boot           ext2   defaults         0 0
EOF
            ;;
    esac

    if [ "${SWAP_SIZE}" ]; then
        echo "${PART_SWAP}    none            swap    sw              0 0" >> /mnt/exherbo/etc/fstab
    fi

    # Mount the system directories
    print_status "Mounting system directories for chroot..."
    mount -o rbind /dev /mnt/exherbo/dev
    mount -o bind /sys /mnt/exherbo/sys
    mount -t proc none /mnt/exherbo/proc

    # Mount the boot/efi partition
    mkdir -p /mnt/exherbo/boot
    mount "${PART_BOOT}" /mnt/exherbo/boot

    if [ ${SYSTEM_TYPE} == "UEFI" ]; then
        mount -o x-mount.mkdir "${PART_EFI}" /mnt/exherbo/efi
    fi
}

# Main installation process
clear
print_header "Exherbo Linux Installation Script"
echo

bios_or_uefi
ask_swap
wipe_disk
format_disk
get_disk_partitions

clear
print_header "Exherbo Linux Installation"
echo

print_status "Creating partitions and filesystems..."
create_partitions

print_status "Downloading and extracting Exherbo stage tarball..."
mount_stage

print_status "Preparing chroot environment..."
prepare_chroot

print_status "Copying configuration scripts..."
# Let's chroot!
cp "${SCRIPT_DIR}"/chrooted.sh /mnt/exherbo
if [ -f "${SCRIPT_DIR}"/params ]; then
    cp "${SCRIPT_DIR}"/params /mnt/exherbo
fi

print_status "Starting system configuration in chroot environment..."
env -i TERM="${TERM}" SHELL=/bin/bash HOME="${HOME}" "$(which chroot)" /mnt/exherbo /bin/bash chrooted.sh "${SYSTEM_TYPE}" "${DISK}"

# Cleanup and final steps
print_status "Cleaning up temporary files..."
rm /mnt/exherbo/chrooted.sh
rm -f /mnt/exherbo/params
cd / && umount -R /mnt/exherbo
umount -l /mnt/exherbo

print_header "Installation Completed Successfully!"
echo
echo "The Exherbo Linux system has been installed and configured."
echo "System details:"
echo "- System type: ${SYSTEM_TYPE}"
echo "- Root partition: ${PART_ROOT}"
echo "- Boot partition: ${PART_BOOT}"
if [ "${SYSTEM_TYPE}" == "UEFI" ]; then
    echo "- EFI partition: ${PART_EFI}"
fi
if [ "${SWAP_SIZE}" ]; then
    echo "- Swap partition: ${PART_SWAP}"
fi
echo
echo "You can now:"
echo "1. Reboot to start using Exherbo Linux"
echo "2. Stay in the rescue system to make additional changes"
echo
read -rp "Do you want to reboot now? [y/n] " reboot_choice
if [[ "${reboot_choice}" =~ ^[Yy]$ ]]; then
    print_status "Rebooting in 5 seconds..."
    sleep 5
    reboot
else
    print_status "Installation complete. You can reboot manually when ready."
    echo "To reboot manually, run: reboot"
fi
