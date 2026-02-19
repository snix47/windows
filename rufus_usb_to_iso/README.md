
#    Rufus USB-Stick to .iso file converter
    
    This script converts a RUFUS-created Windows 11 USB installation drive
    into a fully bootable ISO file suitable for virtualization platforms
    such as Hyper-V, Proxmox, VMware, and VirtualBox.

    It preserves any RUFUS customizations (e.g. bypassed TPM, Secure Boot,
    or CPU requirements) and rebuilds the media into a dual-mode ISO
    supporting:

        • Legacy BIOS
    perhaps supporting:
        • UEFI (this is untested)

    The resulting ISO can be used for:
        - Virtual machines
        - Lab environments
        - Backup of customized install media
        - Deployment scenarios
