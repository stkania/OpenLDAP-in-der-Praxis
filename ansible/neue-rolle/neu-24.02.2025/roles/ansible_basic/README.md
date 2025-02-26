Role Name
=========

This role will do the basic setup of a new ansible-client. 

Requirements
------------

##
No additional ansible-packages are required. 

##
The role is only tested with Debian 10

##
An inventory with the via DNS resolveable  hostname is required

Role Variables
--------------

All needed variables are defined in default/main.yml

Dependencies
------------

There arew no dependencies to other roles

Example inventory
-----------------
```
[ldap_server]
ldapmaster
ldapslave-01
ldapslave-02

[ldap_master]
ldapmaster

[ldap_slave]
ldapslave-01
ldapslave-02

[ldap_server:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_user=ansible
ansible_become=yes
```


Example Playbook
----------------
```
- hosts: ldap_consumer
      roles:
         - ansible_basic
```

Description
-----------
All you need is a basic Debian 10 System with root-access via SSH allowed (will be disabled at the end of the role)
During the first run of the role the two settings
```
ansible_user=ansible
ansible_become=yes
```
In the inventory must be deactivated! You can again actived the settings after the first run

Start the first run with "-u root --ask-pass" to run as root

During the run the role will do the following:
- copy local public-key ofg the ansible-user to the new host
- creats an ansible-user 
- give the ansible-user root-permission via sudo without the need of entering a password
- disallow root-login via SSH
- 
Author Information
------------------
Stefan Kania stefan@kania-online.de

