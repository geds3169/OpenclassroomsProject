#!/bin/bash

##############################
# Install repository and tools
##############################
yum -y update
yum install -y epel-release
yum install -y yum-utils
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

# Non-interactive SSH login
yum install -y sshpass

# Other tools
yum install -y python3
yum install -y wget
yum install -y git
yum install -y tree
yum install -y net-tools
yum install -y bind-utils
yum install -y unzip
yum install -y bash-completion
yum install -y jq

# Change keyboard to fr
localectl set-keymap fr
echo "loadkeys fr" >> ~vagrant/.bashrc


# Install zsh autocompletion
cd /etc/yum.repos.d/
wget https://download.opensuse.org/repositories/shells:zsh-users:zsh-completions/CentOS_7/shells:zsh-users:zsh-completions.repo
yum install zsh-completions



# VAULT Hashicorp, Download package & move & test & install autocompletion
#variables
VAULT_VERSION="1.12.0"

curl -sO https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip vault_${VAULT_VERSION}_linux_amd64.zip

sudo mv vault /usr/local/bin/

# Creating a directory structure to hold the binary, logs, and vault data
mkdir -p /etc/vault
mkdir -p /var/lib/vault/data

# Create user vault
useradd --system --home /etc/vault --shell /bin/false vault
chown -R vault:vault /etc/vault /var/lib/vault/

# Write basic configuration settings for Vault
touch /etc/vault/config.hcl

cat <<EOF | sudo tee /etc/vault/config.hcl
disable_cache = true
disable_mlock = true
ui = true
listener "tcp" {
   address          = "0.0.0.0:8200"
   tls_disable      = true
}
storage "file" {
   path  = "/var/lib/vault/data"
 }
api_addr         = "http://0.0.0.0:8200"
max_lease_ttl         = "10h"
default_lease_ttl    = "10h"
cluster_name         = "vault"
raw_storage_endpoint     = true
disable_sealwrap     = true
disable_printable_check = false # default true
EOF


# Write Configuration Service file
cat <<EOF | sudo tee /etc/systemd/system/vault.service
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=http://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault/config.hcl

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.hcl
ExecReload=/bin/kill --signal HUP 
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitBurst=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Open Firewall
#firewall-cmd --add-port="8200"/tcp --permanent
#firewall-cmd --reload

# Enable & start the vault service
systemctl daemon-reload
systemctl enable --now vault
systemctl status vault

# Add PATH environment variable
# root & vagrant user
export VAULT_ADDR=http://127.0.0.1:8200
echo "export VAULT_ADDR=http://127.0.0.1:8200" >> /root/.bashrc
echo "export PATH=/usr/local/bin:$PATH" >> /root/.bashrc
echo "complete -C /usr/local/bin/vault vault" >> /root/.bashrc
source /root/.bashrc

echo "export VAULT_ADDR=http://127.0.0.1:8200" >> /home/vagrant/.bashrc
echo "export PATH=/usr/local/bin:$PATH" >> /home/vagrant/.bashrc
echo "complete -C /usr/local/bin/vault vault" >> /home/vagrant/.bashrc
source /home/vagrant/.bashrc

rm -rf  /var/lib/vault/data/*

echo "#################################################################"
echo "                 Your keys are here, don't lose them !           "
echo "#################################################################"
echo
# Run a production server /etc/vault/config.hcl
vault server -config=./config.hcl
# Initialize the Vault Server
vault operator init
echo
vault --version
#vault -autocomplete-install
source $HOME/.bashrc
source /root/.bashrc

echo "#################################################################"
echo "                             Your access                         "
echo "#################################################################"
IP=$(ip -f inet addr show eth1 | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')
echo
# End of script return IP access
echo "For this Stack, you will use ${IP} IP Address, port 22, private key is located in local_dir/.vagrant/machines/centos/vmware_deskto/private_key"
echo
echo "The URL of your vault is http://$IP:8200/ui"
echo
echo "#################################################################"
echo "                    MANUAL ACTION REQUIERED                      "
echo "#################################################################"
echo
echo "1) run the command in your terminal: export VAULT_ADDR=http://127.0.0.1:8200"
echo "2) Open your local browser Open the vault url"
echo "3) Use 3 keys to Unseal Vault, Look at the 'Your keys...' section"
echo "4) Enter the Initial Root Token"