#!/bin/bash
#
LDAPSEARCH='/opt/symas/bin/ldapsearch'
MANAGERDN='cn=admin,dc=example,dc=net'
URIP1='ldaps://ldap-r01.example.net'
PASSWD='geheim'
DC='net'
TESTDIR=$(mktemp -dp ./)
SEARCHOUT=output.binary
USERDN=$1
EXISTS=$($LDAPSEARCH -D $MANAGERDN -H $URIP1 -w $PASSWD -LLL  "$USERDN" dn)
EXISTS=${#EXISTS}
echo $EXISTS
if [ $EXISTS -eq 0 ]
then
        echo "Benutzer/Host $USERDN ist nicht vorhanden"
        exit 1
fi
RDN=$(echo $USERDN | egrep '^uid=|^cn=')
if [ -z $RDN ]
then
        echo " Kein RDN angegeben Benutzer im Format "
        echo " uid=object oder cn=object angeben"
        exit 2
fi

NOCERT=$($LDAPSEARCH -D $MANAGERDN -H $URIP1 -w $PASSWD -LLL  "$USERDN" | grep  'userCertificate;binary' )
echo "wert: $NOCERT"
NOCERT=${#NOCERT}
echo "zahl: $NOCERT"
if [ $NOCERT -eq 0  ]
then
        echo "Benutzer/Host hat noch kein Zertifikat"
        while [ "$CREATECERT" != "J" -a "$CREATECERT" != "N" ]
        do
                echo -n "Soll ein Zertifikat erstellt werden (j/n)? "
                read CREATECERT
                CREATECERT=$(echo $CREATECERT | tr a-z A-Z)
        done
        if [ $CREATECERT == "J" ]
        then
                $LDAPSEARCH -D $MANAGERDN -H $URIP1 -w $PASSWD -LLL  "$USERDN"  'userCertificate;binary' 'userPrivateKey;binary' >/dev/null
        else
                echo "Kein Zertifikat vorhanden und es wurde auch keins erstellt"
                exit 1
        fi
fi
echo "Suche das Zertifikat für $USERDN mit ldapsearch"
$LDAPSEARCH -D $MANAGERDN -H $URIP1 -w $PASSWD -LLL  "$USERDN"  'userCertificate;binary' > $SEARCHOUT 2>&1
echo "Erstelle das Zertifikat"
echo "-----BEGIN CERTIFICATE-----" > $TESTDIR/"${USERDN}"-usercert.pem
sed -e "/^dn:/d" -e "/^ dc=${DC}/d" -e "s/userCertificate;binary:://" -e "/^$/d" $SEARCHOUT >> $TESTDIR/"${USERDN}"-usercert.pem
echo "-----END CERTIFICATE-----" >> $TESTDIR/"${USERDN}"-usercert.pem

echo "Suche den Key für $USERDN mit ldapsearch"
$LDAPSEARCH -D $MANAGERDN -H $URIP1 -w $PASSWD -LLL  "$USERDN" 'userPrivateKey;binary'  > $SEARCHOUT 2>&1
echo "Erstelle den Key"
echo "-----BEGIN PRIVATE KEY-----" > $TESTDIR/"${USERDN}"-userkey.pem
sed -e "/^dn:/d" -e "/^ dc=${DC}/d" -e "s/userPrivateKey;binary:://" -e "/^$/d" $SEARCHOUT >> $TESTDIR/"${USERDN}"-userkey.pem
echo "-----END PRIVATE KEY-----" >> $TESTDIR/"${USERDN}"-userkey.pem

echo "Inhalt des Zertifikats"
openssl x509 -noout -text -in  $TESTDIR/"${USERDN}"-usercert.pem
echo "Weiter mit RETURN" ; read

echo "Vergleich der Prüfsumme des Zertifikate mit der des keys"
echo ""
echo "Prüfsumme des Keys:       $(openssl pkey -in $TESTDIR/"$USERDN"-userkey.pem -pubout -outform pem | sha256sum)"
echo ""
echo "Prüfsumme des Zertifikat: $(openssl x509 -in $TESTDIR/"$USERDN"-usercert.pem -pubkey -noout -outform pem | sha256sum)"
