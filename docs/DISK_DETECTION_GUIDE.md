# Disk Detection Guide

This guide explains the automatic disk detection feature in the Exherbo installer and how it works with different environments.

## How Disk Detection Works

The installer automatically scans for available disks and presents them to the user for selection. This eliminates the need to manually specify disk names and works across different environments.

### Detection Process

1. **Scan for Disks**: Uses `lsblk` to find all block devices
2. **Filter Results**: Excludes loop devices, partitions, and other non-disk devices
3. **Display Options**: Shows disk name, size, and model information
4. **User Selection**: Allows user to choose from available disks
5. **Confirmation**: Requires final confirmation before proceeding

## Supported Environments

### Virtual Machines

| VM Type | Disk Names | Example |
|---------|------------|---------|
| **QEMU/KVM** | `/dev/vda`, `/dev/vdb` | `/dev/vda (20G - QEMU HARDDISK)` |
| **VirtualBox** | `/dev/sda`, `/dev/sdb` | `/dev/sda (20G - VBOX HARDDISK)` |
| **VMware** | `/dev/sda`, `/dev/sdb` | `/dev/sda (20G - VMware Virtual S)` |
| **Hyper-V** | `/dev/sda`, `/dev/sdb` | `/dev/sda (20G - Msft Virtual Disk)` |

### Physical Machines

| Disk Type | Names | Example |
|-----------|-------|---------|
| **SATA/IDE** | `/dev/sda`, `/dev/sdb` | `/dev/sda (500G - WDC WD5000AAKS)` |
| **NVMe** | `/dev/nvme0n1`, `/dev/nvme1n1` | `/dev/nvme0n1 (1T - Samsung SSD 980)` |
| **USB** | `/dev/sda`, `/dev/sdb` | `/dev/sda (32G - SanDisk Cruzer)` |

## Usage Examples

### Single Disk Environment

When only one disk is found, the installer will automatically select it:

```bash
$ ./init-openrc.sh
[INFO] Scanning for available disks...
[INFO] Only one disk found: /dev/vda (20G - QEMU HARDDISK)
Use this disk for installation? [y/n] y
[WARNING] You have selected: /dev/vda
[WARNING] This disk will be completely wiped and Exherbo Linux will be installed on it.
Are you sure you want to continue? [y/n] y
```

### Multiple Disk Environment

When multiple disks are found, the installer will present a menu:

```bash
$ ./init-improved.sh
[INFO] Scanning for available disks...
[INFO] Multiple disks found:

1. /dev/sda (500G - WDC WD5000AAKS)
2. /dev/nvme0n1 (1T - Samsung SSD 980)
3. /dev/sdb (32G - SanDisk Cruzer)

Select disk number (1-3): 2
[INFO] Selected disk: /dev/nvme0n1 (1T - Samsung SSD 980)
[WARNING] You have selected: /dev/nvme0n1
[WARNING] This disk will be completely wiped and Exherbo Linux will be installed on it.
Are you sure you want to continue? [y/n] y
```

### Manual Disk Specification

You can still specify a disk manually to bypass detection:

```bash
# Specify disk manually
./init-openrc.sh /dev/vda
./init-improved.sh /dev/nvme0n1
```

## Testing Disk Detection

Use the test script to see how disk detection works without installing:

```bash
# Test disk detection
./test-disk-detection.sh
```

This will:
- Show current disk layout
- Demonstrate the detection process
- Allow you to select a disk
- Show what would be selected (without actually installing)

## Troubleshooting

### No Disks Found

If no suitable disks are found:

```bash
[ERROR] No suitable disks found!
```

**Solutions:**
1. Check if disks are properly connected
2. Verify disk is not mounted
3. Check for hardware issues
4. Try running as root: `sudo ./init-openrc.sh`

### Invalid Disk Selection

If you select an invalid disk number:

```bash
[ERROR] Invalid selection. Please enter a number between 1 and 3
```

**Solutions:**
1. Enter a valid number from the list
2. Check the disk list again
3. Restart the installer

### Disk Already in Use

If the selected disk is already mounted:

```bash
[ERROR] Disk /dev/sda is currently mounted
```

**Solutions:**
1. Unmount the disk: `umount /dev/sda`
2. Choose a different disk
3. Check what's using the disk: `lsof /dev/sda`

## Disk Detection Logic

### What Gets Detected

**Included:**
- Physical disks (`/dev/sda`, `/dev/nvme0n1`)
- Virtual disks (`/dev/vda`, `/dev/xvda`)
- USB drives (`/dev/sdb`, `/dev/sdc`)
- Any block device with `TYPE=disk`

**Excluded:**
- Loop devices (`/dev/loop0`)
- Partitions (`/dev/sda1`, `/dev/nvme0n1p1`)
- CD/DVD drives (`/dev/sr0`)
- Memory devices (`/dev/ram0`)

### Detection Command

The installer uses this command to detect disks:

```bash
lsblk -d -n -o NAME,TYPE,SIZE,MODEL | grep -E 'disk|nvme' | awk '{print "/dev/" $1 " (" $3 " - " $4 ")"}'
```

## Best Practices

### Before Installation

1. **Backup Important Data**: Always backup data before installation
2. **Check Disk Health**: Use `smartctl` to check disk health
3. **Verify Disk Size**: Make sure the disk is large enough (minimum 10GB)
4. **Test Detection**: Use the test script first

### During Installation

1. **Read Carefully**: Pay attention to disk selection prompts
2. **Double-Check**: Verify the selected disk is correct
3. **Confirm Actions**: Don't skip confirmation prompts
4. **Monitor Progress**: Watch for any error messages

### After Installation

1. **Verify Installation**: Check that the system boots correctly
2. **Test Services**: Ensure all services start properly
3. **Check Partitions**: Verify partitions are created correctly
4. **Update System**: Run system updates after installation

## Related Commands

### Manual Disk Information

```bash
# List all block devices
lsblk

# Show disk information
fdisk -l

# Check disk usage
df -h

# Show mounted filesystems
mount
```

### Disk Health Checks

```bash
# Check disk health (if smartmontools installed)
smartctl -a /dev/sda

# Check disk errors
dmesg | grep -i error

# Monitor disk activity
iostat -x 1
```

## Tips

1. **Use Test Script**: Always test disk detection before installing
2. **Check Logs**: Look at system logs if detection fails
3. **Verify Environment**: Make sure you're in a rescue system
4. **Root Access**: Some operations may require root privileges
5. **Network Access**: Ensure internet connection for downloads

---

**Happy disk detection!**
