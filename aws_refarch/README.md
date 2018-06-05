# AWS Installer

This installer sets up OpenShift on AWS in a HA configuration. This is a summary of the [official documentation](https://access.redhat.com/documentation/en-us/reference_architectures/2018/html/deploying_and_managing_openshift_3.9_on_amazon_web_services) with some "gottchas" outlined.

In the end you'll have the following.

![aws refarch overview](./ose-on-aws-architecture.jpg)

You will need the following to get started
* An AWS IAM account
  * This account pretty much needs full access
  * AWS Secret Key
  * AWS Key ID
* Delegate a Subdomain to AWS Route53
* OpenShift Subs
* A host to launch the commands from (This is **NOT** the bastian host...this is like, your laptop or a vm on your laptop)

## Set Up Host

First, setup EPEL

```
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
```

Now, install some key components

```
yum install -y python-pip jq unzip git
```

You won't need EPEL anymore so you can erase it if you'd like

```
yum -y erase epel-release
```

Next, you'll need to install the `awscli` tools. The below are "quicknotes" for more detailed information look [here](https://docs.aws.amazon.com/cli/latest/userguide/installing.html).

```
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
cd awscli-bundle
sudo ./install -i /usr/local/aws -b /usr/local/bin/aws
```

Verify with

```
aws --version
```

Now, you need to setup the Boto3 AWS SDK for Python. Again, these are "quicknotes". Detailed Boto3 AWS python bindings installation procedure is [here](http://boto3.readthedocs.io/en/latest/guide/quickstart.html#installation) and legacy Boto AWS python bindings installation procedure is [here](http://boto.cloudhackers.com/en/latest/getting_started.html)

Set up `boto` config in your homedir

```
cat << EOF > ~/.boto
[Boto]
debug = 0
num_retries = 10
EOF
```

Now install required versions (please look at the [official documentation](https://access.redhat.com/documentation/en-us/reference_architectures/2018/html/deploying_and_managing_openshift_3.9_on_amazon_web_services) for current versions)

```
pip install --upgrade pip
pip install boto3==1.5.24
pip install boto==2.48.0
```

Verify with

```
pip freeze | grep boto
```

Once you have that in place, export your `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` entries.

```
export AWS_SECRET_ACCESS_KEY=ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
export AWS_ACCESS_KEY_ID=XXXXXXXXXXXXXXXXXXXX
```

Now, test connectivity. Comamnds and sample (successful) output below

```
$ aws sts get-caller-identity

output:
{
    "Account": "123123123123",
    "UserId": "TH75ISMYR3F4RCHUS3R1D",
    "Arn": "arn:aws:iam::123123123123:user/refarchuser"
}


$ cat << EOF | python
import boto3
print(boto3.client('sts').get_caller_identity()['Arn'])
EOF

arn:aws:iam::123123123123:user/refarch
```

Set up your SSH keys. the `clusterid` can be anything, and `dns_domain` needs to be the domain you delegated. The `region` is where you want to install OCP.

```
$ export clusterid=myocp
$ export dns_domain=example.com
$ export region=us-east-1
$ if [ ! -f ${HOME}/.ssh/${clusterid}.${dns_domain} ]; then
  echo 'Enter ssh key password'
  read -r passphrase
  ssh-keygen -P ${passphrase} -o -t rsa -f ~/.ssh/${clusterid}.${dns_domain}
fi
```

Lastley, register the system with RHN and install `atomic-openshift-utils`

```
subscription-manager register
subscription-manager attach --pool NUMBERIC_POOLID
subscription-manager repos \
    --disable="*" \
    --enable=rhel-7-server-rpms \
    --enable=rhel-7-server-extras-rpms \
    --enable=rhel-7-server-ansible-2.4-rpms \
    --enable=rhel-7-server-ose-3.9-rpms
yum -y install atomic-openshift-utils
```
## Provision The Environment

We will be using ansible to provision the infra before we install openshift. Make sure you have delegated a subdomain to route53 before you get started


You will need the following repo

```
git clone https://github.com/openshift/openshift-ansible-contrib.git
cd openshift-ansible-contrib/reference-architecture/3.9
```

Create a simple ansible inventory file for this run

```
$ sudo vi /etc/ansible/hosts
[local]
127.0.0.1

[local:vars]
ansible_connection=local
ansible_become=False
```

Now, you'll need to edit the `playbooks/vars/main.yaml` file to match your paticular environment. Here are what I did to mine (YMMV). I just changed `sshkey_password`, `clusterid`, `dns_domain`, `aws_region`

```
---
aws_cred_profile: "default"

# password for ssh key - ~/.ssh/{{ clusterid }}.{{ dns_domain }}
sshkey_password: 'openshift'

clusterid: "myocp"
dns_domain: "example.com"
aws_region: "us-east-1"

vpc_cidr: "172.16.0.0/16"

subnets_public_cidr:
  - 172.16.0.0/24
  - 172.16.1.0/24
  - 172.16.2.0/24

subnets_private_cidr:
  - 172.16.16.0/20
  - 172.16.32.0/20
  - 172.16.48.0/20

ec2_type_bastion: "t2.medium"
ec2_type_master: "m5.2xlarge"
ec2_type_infra: "m5.2xlarge"
ec2_type_node: "m5.2xlarge"
ec2_type_cns: "m5.2xlarge"

rhel_release: "rhel-7.5"
```

**NOTE** I Also needed to edit `playbooks/roles/aws/tasks/getec2ami.yaml` because it couldn't find  the right AMI, YMMV but here is how mine looked like. Specifically, II only changed the `shell` module in this task. This may or maynot apply to you.

```
---
- name: Fetch Red Hat Cloud Access ami
  ###shell: aws ec2 describe-images \
  ###  --region "{{ aws_region }}" --owners 309956199498 | \
  ###  jq -r '.Images[] | [.Name,.ImageId] | @csv' | \
  ###  sed -e 's/\"//g' | \
  ###  grep -v Beta | \
  ###  grep -i Access2-GP2 | \
  ###  grep -i "{{ rhel_release }}" | \
  ###  sort | \
  ###  tail -1
  shell: aws ec2 describe-images \
    --region "{{ aws_region }}" --owners 309956199498 | \
    jq -r '.Images[] | [.Name,.ImageId] | @csv' | \
    sed -e 's/\"//g' | \
    grep -v Beta | \
    grep -i "{{ rhel_release }}" | \
    sort | \
    tail -1
  args:
    executable: /bin/bash
  register: ec2ami
  changed_when: "'ami-' not in ec2ami.stdout"

- name: 'NOTICE!  Red Hat Cloud Access machine image not found'
  vars:
    notice: |
         NOTICE!  Red Hat Cloud Access machine image not found!
         Please verify the process has been completed successfully.

         See the following url...
         https://access.redhat.com/cloude/manager/gold_imports/new
  debug:
    msg: "{{ notice.split('\n') }}"
  when: ec2ami.changed
  failed_when: "'ami-' not in ec2ami.stdout"

- name: 'Set fact: ec2ami'
  set_fact:
    ec2ami: "{{ ec2ami.stdout.split(',')[1] }}"
```


Now you can run the playbook to provision the environment

```
ansible-playbook playbooks/deploy_aws.yaml
```

If you'd like CNS, run this playbook in addition to the one above.

```
ansible-playbook playbooks/deploy_aws_cns.yaml
```
## Install OpenShift

First you need to set up connection to your bastion host. 

```
mv ~/.ssh/config ~/.ssh/config-orig
ln -s ~/.ssh/config-${clusterid}.${dns_domain} ~/.ssh/config
chmod 400 ~/.ssh/config-${clusterid}.${dns_domain}
```

Next, setup `ssh-agent` is running and local ssh key can be used to proxy connections to target EC2 instances

```
$ if [ ! "$(env | grep SSH_AGENT_PID)" ] || [ ! "$(ps -ef | grep -v grep | grep ${SSH_AGENT_PID})" ]; then
  rm -rf ${SSH_AUTH_SOCK} 2> /dev/null
  unset SSH_AUTH_SOCK
  unset SSH_AGENT_PID
  pkill ssh-agent
  export sshagent=$(nohup ssh-agent &)
  export sshauthsock=$(echo ${sshagent} | awk -F'; ' {'print $1'})
  export sshagentpid=$(echo ${sshagent} | awk -F'; ' {'print $3'})
  export ${sshauthsock}
  export ${sshagentpid}
  for i in sshagent sshauthsock sshagentpid; do
    unset $i
  done
fi

$ export sshkey=($(cat ~/.ssh/${clusterid}.${dns_domain}.pub))

$ IFS=$'\n'; if [ ! $(ssh-add -L | grep ${sshkey[1]}) ]; then
  ssh-add ~/.ssh/${clusterid}.${dns_domain}
fi

$ unset IFS
```

Run this to verify. The `ssh` should log you into the bastion host. Go ahead and logout once you verify you can login
```
ssh-add -l
ssh bastion
```

You should be ready to install openshift now. You will have various configs under

```
~/.ssh/config-${clusterid}.${dns_domain}-*
```

These files have examples of what you need to use for  your inventory file. I created an inventory file called `~/aws_inventory.ini`, [here is an example](), use this to compile your own inventory file. **DON'T JUST COPY THIS ONE!!!**  	
