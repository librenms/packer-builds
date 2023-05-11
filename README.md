
## Usage

Clone the repository:

```bash
git clone https://github.com/librenms/packer-builds && cd packer-builds
```

Install requirements:

  - [packer.io](https://packer.io/downloads.html)
  - [VirtualBox](https://www.virtualbox.org/wiki/Linux_Downloads)

## Configuration

You can configure each template to match your requirements by setting the following [user variables](https://packer.io/docs/templates/user-variables.html).

 User Variable       | Default Value | Description
---------------------|---------------|----------------------------------------------------------------------------------------
 `cpus`              | 1             | Number of CPUs
 `disk_size`         | 40000         | [Documentation](https://packer.io/docs/builders/virtualbox-iso.html#disk_size)
 `headless`          | 0             | [Documentation](https://packer.io/docs/builders/virtualbox-iso.html#headless)
 `memory`            | 512           | Memory size in MB
 `mirror`            |               | A URL of the mirror where the ISO image is available
 `librenms_version`  | master        | Available options are master or release, master will be up to the latest commit and release will be the latest tag
 `oxidized`          | true          | Install Oxidized as part of the image
 `syslog_ng`         | true          | Install and configure Syslog-NG

### Example

Build a LibreNMS Ubuntu 22.04 (NGINX) box with a 10GB hard disk using the VirtualBox provider:

```bash
packer build -only=virtualbox-iso -var disk_size=10000 ubuntu-22.04-amd64.json
```

If running on a remote system over ssh, or on a system without a graphical
console, add `-var headless=true`

For debugging, run with `PACKER_LOG=1` and/or check `~/.config/VirtualBox/VBoxSVC.log`
