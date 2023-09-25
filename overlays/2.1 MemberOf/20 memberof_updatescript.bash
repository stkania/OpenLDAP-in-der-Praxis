#!/bin/bash
echo -n "Bitte geben sie den DN des Administratorkontos an : "
read ADM
echo -n "Bitte geben sie das Kennwort zur LDAP-Authentifizierung ein : "
read PASS
for GRP in `ldapsearch -D "$ADM" -w$PASS -b "dc=example,dc=net" \
  '(objectClass=groupOfNames)' -LLL dn|grep "^dn:"|sed s/"dn: "//`
do
  for MEMBER in `ldapsearch -D "$ADM" -w$PASS -b $GRP -LLL \
    member|grep "^member:"|sed s/"member: "//g`
  do
    ldapmodify -D "$ADM" -w$PASS << EOF
dn: $GRP
changetype: modify
delete: member
member: $MEMBER

dn: $GRP
changetype: modify
add: member
member: $MEMBER
EOF
  done
done