# OpenShift 4.1 UPI Install

This is a high-level guide that will help you install OCP 4.1 UPI on BareMetal (but works on VMs). OCP4.x requires more infra components than 3.x and makes a lot of assumptions. I will go over them here; but remember. These are **__HIGH LEVEL__** notes and assumes you know what you're doing.

Please consult the [official docs](https://docs.openshift.com/container-platform/4.1/installing/installing_bare_metal/installing-bare-metal.html) to see up to date information.

* [Prereqs](docs/0.prereqs.md)
* [Setup Artifacts](docs/1.setup.md)
* [Install RHCOS](docs/2.installrhcos.md)
* [Install OCP4](docs/3.installocp4.md)


# OpenShift 4.1 IPI Cloud Installers

Using the IPI Cloud installers is an easier, more automated, but less flexiable way of installing OCP4.x and requires less setup. If installing in the cloud, I recommend one of these.

* [AWS Installer](https://docs.openshift.com/container-platform/4.1/installing/installing_aws/installing-aws-default.html)
* [Azure Installer](https://image.freepik.com/free-vector/coming-soon-message-illuminated-with-light-projector_1284-3622.jpg)
* [GCE Installer](https://image.freepik.com/free-vector/coming-soon-message-illuminated-with-light-projector_1284-3622.jpg)
