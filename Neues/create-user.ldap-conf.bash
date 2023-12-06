#!/bin/bash
#
#####################################################
# Skript zur Erstellung einer eignen .ldaprc Datei  #
# um die Verwendung der ldap-Kommandos anzupassen   #
# ###################################################
#                                                   #
# Alle Parameter werden ueber getopts uebergeben    #
# Die in den Vorbelegungen angegebenen Werte	    #
# sind lediglich als Platzhalter und Beispiele      #
# gedacht                                           #
# ################################################### 
#
# Sollen die Werte aus der systemweiten ldap.conf nicht
# ausgewertet werden, dann kann die Option "-n" bei getopts genutzt werden

# Default-Werte aus der systemweiten ldap.conf werden nicht uebernommen
# Die Option "-n" wird ohne Wert an getopts uebergeben
NODEFAULT=""
# Als "BASE" wird der basedn des LDAP benoetigt z.b. dc=example,dc=net
# Der Parameter fuer getopts ist -b
BASE="dc=example,dc=net"

# Als "SUFFIX" wird der DNS-Suffix benoetig um die SRV-Records auszuwerten 
# Der Parameter fuer getopts ist "-s"
SUFFIX="example.net"

# Das zu verwendende Protokoll ldap oder ldaps
# Der Parameter fuer getopts ist "-P" (fuer LDAPS) oder "-p" (fuer LDAP)
LDAP_PROTOKOLL="ldaps"

# Um nicht immer einen Benutzername übergeben zu muessen
# wird der "BASEDN" in die .ldaprc eingetragen
BINDDN="uid=dummy,ou=users,dc=example,dc=net"

# Wird ldaps als Protokoll genutzt wird der Pfad zum root-Zertifkat
# mit getopts ueber die Option "-T" uebergeben
TLS_CACERT="/opt/symas/etc/openldap/cacert.pem"

# Die Zertifkatsoption z.B fuer self-signed Zertifikate
# wird uebr die getopts Option "-R" uebergeben
TLS_REQCERT="demand"

# In "LOCAL_LDAPRC" wird der Pfad fuer die lokal Datei hinterlegt
# Fuer getopts wird der Parmeter "-L" genutzt
LOCAL_LDAPRC="$HOME/.ldaprc"

# Der COUNTER wird fuer die Anzahl der SRV-Records benoetigt
COUNTER=0

# Die "URI_CONF" setzt sich spaeter durch die Namen der
# LDAP-Server der SRV-Records zusammen
URI_CONF="URI "

clear
if [ $# -eq 0 ]
then
cat << EOT1	
	############ Hilfe #############
	
	-n Verwerfen der systemweiten Einstellungen 
	-b [ARG] Festleben der BASE 
	-s [ARG] Festlegen den DNS-Suffix 
	-p Verwende LDAP als Protokoll 
	-P Verwende LDAPS als Protokoll 
	-D [ARG] Eintragen eines binddn 
	-T [ARG] Pfad zum root-Zertifikate für TLS 
	-R [ARG] TLS_REQCERT Optionen 
	-L [ARG] Datei für die eigenen Einstellungen 
	
	################################

EOT1
	J_N=""
	while [ "$J_N" != "J" -a "$J_N" != "N" ]
	do
		echo -n "Soll die Default-Werte angezeigt werden (J/N)? "
		read J_N
	done

	if [ "$J_N" = "J" ]
	then
cat << EOT2
	systemweite Einstellungen werden übernommen
	BASE == $BASE
	DNS-Suffix == $SUFFIX
	LDAP-Protokoll == $LDAP_PROTOKOLL
	binddn == $BINDDN
	Pfad zum root-Zertifikat == $TLS_CACERT
	TLS_REQCERT == $TLS_REQCERT
	Pfad zur Datei == $LOCAL_LDAPRC
EOT2
	fi
	J_N=""
	while [ "$J_N" != "J" -a "$J_N" != "N" ]
	do
		echo -n "Soll die Default-Werte übernommen werden (J/N)? "
		read J_N
	done
	if [ "$J_N" = "N" ]
	then
		exit 2
	fi
fi


while getopts npPb:s:D:T:R:L: OPT 2>/dev/null
do
	case "$OPT" in
		n) NODEFAULT="export LDAPNOINIT=false";;
		b) BASE=($OPTARG);;
		s) SUFFIX=($OPTARG);;
		p) LDAP_PROTOKOLL="ldap";;
		P) LDAP_PROTOKOLL="ldaps";;
		D) BINDDN=($OPTARG);;
		T) TLS_CACERT=($OPTARG);;
		R) TLS_REQCERT=($OPTARG);;
		L) LOCAL_LDAPRC=($OPTARGS);;
		?) echo "Falsche Option"
		   exit 1;;
	esac
done	

# Pruefen ob die angegeben Datei bereits vorhanden ist

if [ -f "$LOCAL_LDAPRC" ]
then
	echo "Datei $LOCAL_LDAPRC ist bereits vorhanden! "
	J_N=""
	while [ "$J_N" != "J" -a "$J_N" != "N" ]
	do
		echo -n "Soll die Datei überschrieben werden (J/N)? "
		read J_N
	done
fi


# Wenn $J_N = N dann verlasse das Skript
if [ "$J_N" = "N" ]
then
	exit 2
fi

#Ermittle alle SRV-Records und setzt die URI-Zeile zusammen
for i in $(host -t SRV _${LDAP_PROTOKOLL}._tcp.${SUFFIX} | cut -d  " " -f 8 )
do
	SRV_RECORD[$COUNTER]=${i%.}
	((COUNTER=COUNTER+1))
done
((COUNTER=COUNTER-1))
for ((i=0; i<=$COUNTER; i++))
do
	URI_CONF="${URI_CONF}${LDAP_PROTOKOLL}://${SRV_RECORD[$i]} "
done

# Ausgabe der Einstellungen
echo " Diese Inhalte werden in die Datei $LOCAL_LDAPRC  geschrieben"
echo " ####################################################################################"
echo ""
echo "no default $NODEFAULT"
echo "URI $URI_CONF"
echo "BASE $BASE"
echo "BINDDN $BINDDN"
echo "TLS_CACERT $TLS_CACERT"
echo "TLS_REQCERT $TLS_REQCERT"
echo ""
J_N=""
while [ "$J_N" != "J" -a "$J_N" != "N" ]
do
	echo -n "Sollen die Werte übernommen werden (J/N) ? "
	read J_N
done

# Wenn $J_N = N dann verlasse das Skript
if [ "$J_N" = "N" ]
then
	exit 3
fi


# Sollen die systemweiten Einstellungen verworfen werden?
if [ -n "$NODEFAULT" ]
then
	echo "export LDAPNOINIT=false" > $LOCAL_LDAPRC
fi

#Schreiben der Optionen mit Argument
echo "$URI_CONF" >> $LOCAL_LDAPRC
echo "BASE $BASE" >> $LOCAL_LDAPRC
echo "BINDDN $BINDDN" >> $LOCAL_LDAPRC
echo "TLS_CACERT $TLS_CACERT" >> $LOCAL_LDAPRC
echo "TLS_REQCERT $TLS_REQCERT" >> $LOCAL_LDAPRC
