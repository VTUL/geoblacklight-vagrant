Install Scripts for GeoBlacklight Application
=============================================

These files are used to install the [VTUL GeoBlacklight application](https://github.com/VTUL/geoblacklight) on a target server. They can be used to install the application either to a VM under VirtualBox or to a server running under Amazon Web Services (AWS). Installation is done via [Vagrant](https://www.vagrantup.com/).

When installing the GeoBlacklight application, the `vagrant up` command is used to set up the server and deploy the application on the chosen platform. To deploy to AWS, select the `aws` Vagrant provider: `vagrant up --provider aws`. If no provider is specified, it defaults to VirtualBox, which will set up a local VM.

Installation
------------

These scripts are intended to be run on a Unix-like system. They are tested to work on Mac OSX.

To use these scripts, [Vagrant](https://www.vagrantup.com/) must already been installed on the local system with the [VirtualBox](http://www.virtualbox.org) provider working. For provisioning to AWS, the `aws` provider must also be installed. This can be done by executing the following command, which will install the `aws` Vagrant provider plugin: `vagrant plugin install vagrant-aws`.

Finally, these install scripts must be installed on the local machine. This is most easily done by cloning the [VTUL/geoblacklight-vagrant](https://github.com/VTUL/geoblacklight-vagrant) repository from GitHub:

```
git clone https://github.com/VTUL/geoblacklight-vagrant
```

Configuration
-------------

When using the `aws` provider to `vagrant up` it is necessary to define several environment variables in order to authenticate to AWS and supply a keypair with which Vagrant can log in to the new AWS EC2 instance being deployed.  These environment variables are as follows:

- `KEYPAIR_NAME`: the name of the AWS keypair that will be used to log in to the instance. This should also be the same as the keypair private key file.  This keypair should already exist within your AWS account and its private key file should reside on the local system.
- `KEYPAIR_PATH`: the path of the directory on the local system in which the aforementioned keypair private key file resides (e.g., `~/.ssh`).
- `AWS_ACCESS_KEY`: the AWS IAM access key to the account under which the EC2 instance will be created.
- `AWS_SECRET_KEY`: the AWS IAM secret key to the account under which the EC2 instance will be created.

WARNING: Many of the other AWS EC2 instance settings (e.g., instance type, security groups) are set directly in the `Vagrantfile` and make sense only for VTUL users. Please check these are appropriate before bringing up the instance with Vagrant and edit where necessary beforehand.

Usage
-----

To install the GeoBlacklight application from scratch on a server using the current local configuration file settings, do the following:

```
cd /path/to/install/scripts
vagrant up
```

This will install to a local VM. To install to AWS do the following:

```
cd /path/to/install/scripts
vagrant up --provider aws
```

### Local VM

In the case of the `vagrant up` option, a VM will be brought up and configured in the current directory. The GeoBlacklight application is accessible on the local machine from a Web browser at `https://192.168.0.2`.

You can use `vagrant ssh` to log in to this VM when it is up. When logged out of the VM, `vagrant halt` can be used to shut down the VM. The command `vagrant destroy` will destroy it entirely, requiring another `vagrant up` to recreate it.

To access the Solr admin page in the VM from the local machine you would access this URL when the VM is running: `http://192.168.0.2:8983/solr`

### AWS

For the `vagrant up --provider aws` option, a server running the application will be provisioned in AWS. After a while, it should be possible to log in to this machine via SSH:

```
vagrant ssh
```

The installation and setup of the GeoBlacklight application and associated software could take quite a while. Its progress will be logged to the screen during the execution of `vagrant up --provider aws`.

When installation is complete and services are running, you can access the GeoBlacklight application via this URL: `https://$SERVER_HOSTNAME`, where `$SERVER_HOSTNAME` is the hostname of the AWS instance just deployed.  This can be determined by running the following command in the installation scripts directory:

```
vagrant ssh-config | grep HostName | awk '{print $2}'
```

NB: Unless a different `aws.security_groups` setting is used in the `Vagrantfile` prior to running `vagrant up --provider aws` then the Solr Web interface will not be accessible via the Web, unlike when using a local Vagrant VM.

Vagrant commands such as `halt` and `destroy` behave analogously on the AWS instance as they do for local Vagrant VMs.
