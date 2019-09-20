# OpenShift 4 UPI Install

This is a high-level guide that will help you install OCP 4.1 UPI on BareMetal (but works on VMs). OCP4.x requires more infra components than 3.x and makes a lot of assumptions. I will go over them here; but remember. These are **__HIGH LEVEL__** notes and assumes you know what you're doing.

Please consult the [official docs](https://docs.openshift.com/container-platform/4.1/installing/installing_bare_metal/installing-bare-metal.html) to see up to date information.

* [Prereqs](docs/0.prereqs.md)
* [Setup Artifacts](docs/1.setup.md)
* [Install RHCOS](docs/2.installrhcos.md)
* [Install OCP4](docs/3.installocp4.md)

If you are using Libvirt, and/or doing a "lab" install (or PoC)...I suggest you look at my [helper node](https://github.com/christianh814/ocp4-upi-helpernode#ocp4-upi-helper-node-playbook) repo to expedite things. In that repo there is a [quick start](https://github.com/christianh814/ocp4-upi-helpernode/blob/master/quickstart.md) guide that makes things extra fast!

# OpenShift 4 IPI Cloud Installers

Using the IPI Cloud installers is an easier, more automated, but less flexiable way of installing OCP4.x and requires less setup. If installing in the cloud, I recommend one of these.

* [AWS Installer](https://docs.openshift.com/container-platform/4.1/installing/installing_aws/installing-aws-default.html)
* [Azure Installer](https://github.com/openshift/installer/tree/master/docs/user/azure)
  * [Helpful Azure Install Blog](https://blog.openshift.com/openshift-4-2-on-azure-preview/)
* [GCP Installer](https://github.com/openshift/installer/tree/master/docs/user/gcp)
  * [Helpful GCP Install Video](https://www.youtube.com/watch?v=v17Taqza3ZU)

# OpenShift 4 Restricted Installs

The following are guide for "restricted" type of installs of OpenShift 4

* [Disconnected Install](https://github.com/christianh814/blogs/blob/master/docs/openshift-4.2-disconnected/README.md)
* [Proxy Install](docs/proxy_notes.md)
