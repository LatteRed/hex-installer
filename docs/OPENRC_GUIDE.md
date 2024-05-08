# OpenRC Configuration Guide for Exherbo

This guide explains how to use the OpenRC version of the Exherbo installer and configure your system.

## What is OpenRC?

OpenRC is a dependency-based init system that works with the system provided init program, normally /sbin/init. It is not a replacement for /sbin/init, but rather a system that works with it.

## OpenRC vs SystemD

| Feature | OpenRC | SystemD |
|---------|--------|---------|
| **Init System** | Traditional, lightweight | Modern, feature-rich |
| **Boot Speed** | Fast | Slower |
| **Resource Usage** | Low | Higher |
| **Learning Curve** | Steeper | Easier |
| **Compatibility** | Excellent | Good |
| **Configuration** | Text files | Binary + text |

## Installation with OpenRC

### Step 1: Prepare the Installation

```bash
# Download the installer
git clone <your-repo-url>
cd exherbo-installer/src

# Copy OpenRC configuration
cp params-openrc params

# Edit configuration if needed
nano params
```

### Step 2: Run the OpenRC Installer

```bash
# Make scripts executable
chmod +x init-openrc.sh chrooted-openrc.sh

# Run the installer
./init-openrc.sh /dev/sda
```

## OpenRC Configuration

### Essential Services

The installer automatically configures these services:

```bash
# Core services
rc-update add sshd default      # SSH daemon
rc-update add dhcpcd default    # Network configuration
rc-update add dbus default      # D-Bus message bus
rc-update add elogind default   # Login manager
rc-update add consolekit default # Console management
```

### Network Configuration

```bash
# Configure networking
echo 'config_eth0="dhcp"' > /etc/conf.d/net
ln -sf /etc/init.d/net.lo /etc/init.d/net.eth0
rc-update add net.eth0 default
```

### Console Configuration

```bash
# Set keymap
echo 'keymap="us"' > /etc/conf.d/keymaps

# Set console font
echo 'consolefont="lat9w-16"' > /etc/conf.d/consolefont
```

## Post-Installation Configuration

### Service Management

```bash
# List all services
rc-update show

# Start a service
rc-service <service> start

# Stop a service
rc-service <service> stop

# Restart a service
rc-service <service> restart

# Enable a service
rc-update add <service> default

# Disable a service
rc-update del <service> default
```

### Common Services

```bash
# Network services
rc-update add net.eth0 default
rc-update add sshd default
rc-update add dhcpcd default

# System services
rc-update add dbus default
rc-update add elogind default
rc-update add consolekit default

# Optional services
rc-update add cronie default    # Cron daemon
rc-update add cupsd default     # Printing
rc-update add avahi-daemon default  # Network discovery
```

## Advanced Configuration

### Custom Service Scripts

Create custom service scripts in `/etc/init.d/`:

```bash
#!/sbin/openrc-run
# Example custom service

name="my-service"
command="/usr/bin/my-service"
command_args="--daemon"
pidfile="/var/run/my-service.pid"

depend() {
    need dbus
    use net
}
```

### Service Dependencies

Configure service dependencies:

```bash
# In /etc/conf.d/<service>
rc_need="dbus net"
rc_use="elogind"
```

### Runlevels

OpenRC uses runlevels to organize services:

```bash
# Default runlevel
echo 'default' > /etc/runlevels/default

# Add services to runlevel
rc-update add <service> default
```

## Troubleshooting

### Service Issues

```bash
# Check service status
rc-service <service> status

# View service logs
rc-service <service> --verbose

# Debug service
rc-service <service> --debug
```

### Boot Issues

```bash
# Check boot logs
dmesg | grep -i error

# Check service dependencies
rc-update show

# Test service manually
rc-service <service> start
```

### Network Issues

```bash
# Check network configuration
cat /etc/conf.d/net

# Test network service
rc-service net.eth0 start

# Check network status
ip addr show
```

## Useful Commands

### System Information

```bash
# Check OpenRC version
openrc --version

# List all services
rc-update show

# Check service status
rc-status
```

### Service Management

```bash
# Start all services in runlevel
rc default

# Stop all services
rc shutdown

# Restart all services
rc restart
```

### Logs and Debugging

```bash
# View system logs
dmesg

# Check service logs
tail -f /var/log/<service>.log

# Debug service startup
rc-service <service> --debug
```

## Additional Resources

- [OpenRC Documentation](https://github.com/OpenRC/openrc)
- [Exherbo OpenRC Guide](https://www.exherbo.org/docs/install-guide.html)
- [OpenRC Service Scripts](https://github.com/OpenRC/openrc/tree/master/service-scripts)

## Tips

1. **Start with minimal services** and add more as needed
2. **Use `rc-status`** to check which services are running
3. **Check logs** when services fail to start
4. **Test services manually** before enabling them
5. **Keep service dependencies simple** to avoid conflicts

---

**Happy OpenRC configuration!**
