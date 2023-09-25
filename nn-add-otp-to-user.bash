#!/bin/bash
#
# Benutzer-DN und Email-Adresse werden benoetigt
if [ $# -ne 2 ]
then
        echo "User-DN and User-Mail is needed"
        echo "usage: $0 userdn user@mail"
        exit 1
fi
# Setzen der verwendeten Variablen
BASE_DN="dc=example,dc=net"
USER_DN=$1
USER_MAIL=$2
USER_OU="ou=users,ou=verwaltung,ou=firma,dc=example,dc=net"
LDAP_SERVER=ldaps://provider02.example.net
USE_LDAPI=1 # set to "0" if userlogin is prefered
USE_TLS=0 # if TLS should not be used set to "0"
LDAP_ADMIN="cn=admin,dc=example,dc=net"
LDAP_ADMIN_PW="geheim"
TOPT_ISSUER=stka
USER_NAME=""
PATH_FOR_SHARED_KEY="/root/sharedkey"
USER_SHARED_KEY=""
QR_TEXT=""
SALT_LENGTH=20
if [ ! -d $PATH_FOR_SHARED_KEY ]
then
        mkdir $PATH_FOR_SHARED_KEY
fi
if [ "$USE_TLS" -eq 1 ]
then
        ACTIVATE_TLS="-ZZ"
else
        ACTIVATE_TLS=""
fi
# zur Generierung des QR-Codes wird qrencode genutzt
if [ ! -f "/usr/bin/qrencode" ]
then
        echo "qrencode is not installed!"
        exit 2
fi
USER_NAME=$(echo "$USER_DN" | cut -d "," -f 1)
# Benutzer vorhanden?
if [ $USE_LDAPI -eq 1 ]
then
        USER_DN_IN_DB=$(ldapsearch -Q -Y EXTERNAL -LLL -H ldapi:/// -b $BASE_DN $USER_NAME dn 2>/dev/null | cut -d" " -f2)
else
        USER_DN_IN_DB=$(ldapsearch -xLLL "$ACTIVATE_TLS" -D "$LDAP_ADMIN" -w "$LDAP_ADMIN_PW" -H "$LDAP_SERVER" -b $BASE_DN '($USER_NAME)' dn 2>/dev/null | cut -d " " -f 2)
fi
if [ "${USER_DN,,}" != "${USER_DN_IN_DB,,}" ]
then
        echo "User $USER_DN not found in database"
        exit 4
fi
USER_OU=${USER_OU,,}
# Erstellen des Benutzer-Keys
USER_SHARED_KEY="${PATH_FOR_SHARED_KEY}/${USER_NAME}-sharedkey.data"
touch $USER_SHARED_KEY
chmod 600 $USER_SHARED_KEY
openssl rand $SALT_LENGTH > $USER_SHARED_KEY
USER_SHARED_KEY_BASE32=$(base32 $USER_SHARED_KEY)
echo $USER_SHARED_KEY_BASE32 > ${PATH_FOR_SHARED_KEY}/${USER_NAME}-sharedkey.b64
# LDIF-Datei um den Benutzer zu aendern
while read LINE
do
        echo $LINE >> $PATH_FOR_SHARED_KEY/${USER_NAME}-totp.ldif
done << EOT
dn: $USER_DN
changetype: modify
add: objectClass
objectClass: oathTOTPToken
-
add: oathTOTPParams
oathTOTPParams: $USER_OU
-
add: oathSecret
oathSecret:< file://$USER_SHARED_KEY
-
add: objectClass
objectClass: oathTOTPUser
-
add: oathTOTPToken
oathTOTPToken: $USER_DN
EOT
if [ $USE_LDAPI -eq 1 ]
then
        ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f $PATH_FOR_SHARED_KEY/${USER_NAME}-totp.ldif
else
        ldapmodify -x "$ACTIVATE_TLS" -D "$LDAP_ADMIN" -w "$LDAP_ADMIN_PW" -H "$LDAP_SERVER" -f $PATH_FOR_SHARED_KEY/${USER_NAME}-totp.ldif
fi
# Erstellen des QR-Codes
QR_TEXT="otpauth://totp/$LDAP_SERVER:$USER_MAIL?secret=${USER_SHARED_KEY_BASE32}&issuer=${TOTP_ISSUER}&period=30&digits=6&algorithm=SHA1"
echo $QR_TEXT |  qrencode -s9 -o $PATH_FOR_SHARED_KEY/${USER_MAIL}.png
# Informationen ausgeben
echo "Der Key für den Benutzer $USER_DN lautet $USER_SHARED_KEY_BASE32"
echo "Sie finden den Key in binärem Format unter $USER_SHARED_KEY"
echo "Der QR-Code wurde in der Datei ${USER_MAIL}.png abgespeichert"

