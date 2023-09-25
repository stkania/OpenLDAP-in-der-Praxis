#!/bin/bash
DEBIAN_FRONTEND=noninteractive apt install -yq gnupg2 argon2 python3-ldap
wget -O- https://repo.symas.com/repo/gpg/RPM-GPG-KEY-symas-com-signing-key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/symas-com-gpg.gpg > /dev/null
echo "deb [arch=amd64] https://repo.symas.com/repo/deb/main/release26 bullseye main" | tee -a /etc/apt/sources.list.d/symas26.list
apt update -y
groupadd -r  openldap
useradd -r -g openldap -d /opt/symas/ openldap
DEBIAN_FRONTEND=noninteractive apt install -yq symas-openldap-clients symas-openldap-server
chown openldap:openldap /var/symas/openldap-data/
chmod 770 /var/symas/openldap-data/
chown openldap:openldap /var/symas/run
chmod 770 /var/symas/run
mkdir -m 770 /opt/symas/etc/openldap/slapd.d
chown openldap:openldap /opt/symas/etc/openldap/slapd.d
