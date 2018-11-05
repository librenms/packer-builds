
## Usage

Clone the repository:

    $ git clone https://github.com/librenms/packer-templates && cd packer-templates

Install requirements:

  - packer.io
  - VirtualBox

Build a machine image from the template in the repository:

    $ packer build -only=virtualbox-iso archlinux-x86_64.json

## Configuration

You can configure each template to match your requirements by setting the following [user variables](https://packer.io/docs/templates/user-variables.html).

 User Variable       | Default Value | Description
---------------------|---------------|----------------------------------------------------------------------------------------
 `cpus`              | 1             | Number of CPUs
 `disk_size`         | 40000         | [Documentation](https://packer.io/docs/builders/virtualbox-iso.html#disk_size)
 `headless`          | 0             | [Documentation](https://packer.io/docs/builders/virtualbox-iso.html#headless)
 `memory`            | 512           | Memory size in MB
 `mirror`            |               | A URL of the mirror where the ISO image is available
 `librenms_version`  | master        | The version to build LibreNMS agains. You can use a branch name or tag
 `oxidized`          | true          | Install Oxidized as part of the image
 `syslog_ng`         | true          | Install and configure Syslog-NG

### Example

Build a CentOS 7 box with a 4GB hard disk using the VirtualBox provider:

    $ packer build -only=virtualbox-iso -var disk_size=4000 centos-7.4-x86_64.json

