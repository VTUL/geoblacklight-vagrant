Install Scripts for GeoBlacklight Application
=============================================

These files are used to install the [VTUL GeoBlacklight application](https://github.com/VTUL/geoblacklight) on a target server. They can be used to install the application either to a VM under VirtualBox; to a server running under Amazon Web Services (AWS); or to a server running under OpenStack in the Chameleon Cloud. Installation is done via [Vagrant](https://www.vagrantup.com/).

When installing the GeoBlacklight application, the `vagrant up` command is used to set up the server and deploy the application on the chosen platform. To deploy to AWS, select the `aws` Vagrant provider: `vagrant up --provider aws`.  To deploy to OpenStack in the Chameleon Cloud, select the `openstack` provider: `vagrant up --provider openstack`. If no provider is specified, it defaults to VirtualBox, which will set up a local VM.

Installation
------------

These scripts are intended to be run on a Unix-like system. They are tested to work on Mac OSX.

To use these scripts, [Vagrant](https://www.vagrantup.com/) must already have been installed on the local system with the [VirtualBox](http://www.virtualbox.org) provider working. For provisioning to AWS, the `aws` provider must also be installed. This can be done by executing the following command, which will install the `aws` Vagrant provider plugin: `vagrant plugin install vagrant-aws`. To provision to the OpenStack Chameleon Cloud, the `openstack` provider needs to be installed. It can be installed via the following command: `vagrant plugin install vagrant-openstack-plugin`.

Finally, these install scripts must be installed on the local machine. This is most easily done by cloning the [VTUL/geoblacklight-vagrant](https://github.com/VTUL/geoblacklight-vagrant) repository from GitHub:

```
git clone https://github.com/VTUL/geoblacklight-vagrant
```

Configuration
-------------

### AWS

When using the `aws` provider to `vagrant up` it is necessary to define several environment variables in order to authenticate to AWS and supply a keypair with which Vagrant can log in to the new AWS EC2 instance being deployed.  These environment variables are as follows:

- `KEYPAIR_NAME`: the name of the AWS keypair that will be used to log in to the instance. This should also be the same as the keypair private key file.  This keypair should already exist within your AWS account and its private key file should reside on the local system.
- `KEYPAIR_PATH`: the path of the directory on the local system in which the aforementioned keypair private key file resides (e.g., `~/.ssh`).
- `AWS_ACCESS_KEY`: the AWS IAM access key to the account under which the EC2 instance will be created.
- `AWS_SECRET_KEY`: the AWS IAM secret key to the account under which the EC2 instance will be created.

WARNING: Many of the other AWS EC2 instance settings (e.g., instance type, security groups) are set directly in the `Vagrantfile` and make sense only for VTUL users. Please check these are appropriate before bringing up the instance with Vagrant and edit where necessary beforehand.

### OpenStack

When deploying to the OpenStack Chameleon Cloud, several environment variables must be defined in order to authenticate to OpenStack and define a keypair to be used to log in to the new Chameleon Cloud instance being deployed.  The following environment variables must be defined:

- `KEYPAIR_NAME`: the name of the OpenStack keypair that will be used to log in to the instance. This should also be the same as the keypair private key file.  This keypair should already exist within your OpenStack account and its private key file should reside on the local system.
- `KEYPAIR_PATH`: the path of the directory on the local system in which the aforementioned keypair private key file resides (e.g., `~/.ssh`).
- `OS_FLOATING_IP`: The floating IP address (as a "dotted quad", i.e., x.x.x.x) to be assigned to this instance. This floating IP must already be available to the OpenStack project under which the instance is being deployed.
- `OS_USERNAME`: your OpenStack user name
- `OS_PASSWORD`: your OpenStack login password
- `OS_AUTH_URL`: the URL of the OpenStack endpoint
- `OS_TENANT_NAME`: the ID of your OpenStack Chameleon Cloud project (tenant)
- `OS_REGION_NAME`: the OpenStack region in which you wish to deploy the instance

The `OS_USERNAME`; `OS_PASSWORD`; `OS_AUTH_URL`; `OS_TENANT_NAME`; and `OS_REGION_NAME` settings are most easily set via an OpenStack RC file downloaded via the OpenStack dashboard. To do this, log in to the dashboard and select the "Compute" -> "Access & Security" page. On that page, select the "API Access" tab. Click the "Download OpenStack RC File" to download the RC script to your local system. This is a bash script that sets the aforementioned environment variables when run. The script also prompts the user to enter his or her OpenStack password. The `OS_PASSWORD` environment variable is set to the value entered. You should run this script to define those environment variables prior to deploying via Vagrant, e.g., by executing `. /path/to/OpenStack_RC_File.sh`.

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

If you wish to install to OpenStack then do the following:

```
cd /path/to/install/scripts
vagrant up --provider openstack
```

### Local VM

In the case of the plain `vagrant up` option, a VM will be brought up and configured in the current directory. The GeoBlacklight application is accessible on the local machine from a Web browser at `https://192.168.0.2`.

You can use `vagrant ssh` to log in to this VM when it is up. When logged out of the VM, `vagrant halt` can be used to shut down the VM. The command `vagrant destroy` will destroy it entirely, requiring another `vagrant up` to recreate it.

To access the Solr admin page in the VM from the local machine you would access this URL when the VM is running: `http://192.168.0.2:8983/solr`

The local VM option is most often used for local development. The running VM is only accessible from the local machine (not the Internet) and so is isolated for testing purposes. This is why some of its services (like Solr) are more accessible and exposed.

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

### OpenStack

Installation to OpenStack is similar to that of AWS above. After provisioning with `vagrant up --provider openstack` it should be possible to log in to the newly-deployed machine via SSH:

```
vagrant ssh
```

As with the `aws` provider, the application can be accessed via the URL `https://$SERVER_HOSTNAME`, where `$SERVER_HOSTNAME` is the hostname of the OpenStack instance just deployed. You can determine the hostname by using the following command:

```
vagrant ssh-config | grep HostName | awk '{print $2}'
```

As with the `aws` provider, Vagrant commands such as `halt` and `destroy` behave analogously on the OpenStack instance as they do for local Vagrant VMs.
