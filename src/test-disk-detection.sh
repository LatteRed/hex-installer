#!/bin/bash

# Test script to demonstrate disk detection functionality
# This script shows how the disk detection works without actually installing anything

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

# Function to detect and select disk (same as in the installers)
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

# Main test function
main() {
    clear
    print_header "Disk Detection Test"
    echo
    print_status "This script demonstrates the disk detection functionality"
    print_status "It will scan for available disks and let you select one"
    print_status "No actual installation will be performed"
    echo
    
    # Show current disk layout
    print_status "Current disk layout:"
    lsblk
    echo
    
    # Test disk detection
    detect_and_select_disk
    
    print_status "Disk detection test completed successfully!"
    print_status "Selected disk: ${DISK}"
    print_status "This would be the disk used for installation"
}

# Run the test
main
