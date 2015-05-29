#!/bin/bash
HELP="
##############################################################################
# Backup script desigend to be used with the IDP installer                   #
#    NOTE! the tar file WILL contain cleartext passwords.                    #
#                                                                            #
# Options                                                                    #
# -i <idp base directory>         Default: /opt/shibboleth-idp               #
# -t <tomcat/jetty config directory>    Default: /etc/tomcat6 and            #
#                                                /opt/jetty/base/etc         #
##############################################################################
"

if [ "${USERNAME}" != "root" -a "${USER}" != "root" ]; then
        echo "Run as root!"
        exit
fi


Spath="$(cd "$(dirname "$0")" && pwd)"
. ${Spath}/files/script.bootstrap.functions.sh
filesPath="${Spath}/backup-files"
sqlDumpFile="${filesPath}/sql.dump"
eptidVarsFile="${filesPath}/eptid.vars"
tomcatVarsFile="${filesPath}/tomcat.vars"
importFile="${filesPath}/settingsToImport.sh"
files="${sqlDumpFile} ${eptidVarsFile} ${tomcatVarsFile} ${tomcatVarsFile} ${importFile}"
locationsToTar="/opt/shibboleth-idp/credentials/* /opt/shibboleth-idp/metadata/idp-metadata.xml `basename ${importFile}`"

idpBase="/opt/shibboleth-idp"
tomcatConfBases="/etc/tomcat6 /opt/jetty/base/etc"
for i in $tomcatConfBases; do
	if [ -d "${i}" ]; then
		tomcatConfBase=${i}
	fi
done


options=$(getopt -o "t:i:h" -l "help" -- "$@")
eval set -- "${options}"
while [ $# -gt 0 ]; do
	case "${1}" in
		-i)
			if [ -n "$2" ]; then
				idpBase="${2}"
			fi
			shift 2
		;;
		-t)
			if [ -n "$2" ]; then
				tomcatConfBase="${2}"
			fi
			shift 2
		;;
		-h | --help)
			echo "${HELP}"
			exit
		;;
		--)
			break;
		;;
	esac
done

if [ -z "`which xsltproc`" ]; then
	guessLinuxDist
	if [ "${dist}" = "ubuntu" ]; then
		apt-get install xsltproc
	elif [ "${dist}" = "centos" ]; then
		echo "Please install xsltproc."
		exit
	elif [ "${dist}" = "redhat" ]; then
		echo "Please install xsltproc."
		exit
	elif [ "${dist}" = "sles" ]; then
		echo "Please install xsltproc."
		exit
	fi
fi

if [ ! -d "${idpBase}/conf" ]; then
	echo "Can not find IDP at: ${idpBase}"
	exit
fi

if [ ! -s "${tomcatConfBase}/server.xml" -a ! -s "${tomcatConfBase}/jetty-shibboleth.xml" ]; then
	echo "Can not find tomcat/jetty config at: ${tomcatConfBase}"
	exit
fi

if [ ! -d "${filesPath}" ]; then
	mkdir ${filesPath}
fi
echo "" > ${importFile}

EPTIDtest=`xsltproc ${Spath}/xslt/get_data_connector.xsl ${idpBase}/conf/attribute-resolver.xml | grep "^ref="`
if [ ! -z "${EPTIDtest}" ]; then
	# grab mysql creds
	EPTIDref=`echo $EPTIDtest | cut -d= -f2-`
	cat ${Spath}/xslt/get_data_vars.xsl.template | sed s/###ConnectorRef###/${EPTIDref}/ > ${Spath}/xslt/get_data_vars.xsl
	xsltproc -o ${eptidVarsFile} ${Spath}/xslt/get_data_vars.xsl ${idpBase}/conf/attribute-resolver.xml
	rm ${Spath}/xslt/get_data_vars.xsl
	locationsToTar="${locationsToTar} `basename ${sqlDumpFile}`"

	sqlURL=`grep "^jdbcURL" ${eptidVarsFile} | cut -d= -f2-`
	sqlUser=`grep "^jdbcUserName" ${eptidVarsFile} | cut -d= -f2-`
	sqlPass=`grep "^jdbcPassword" ${eptidVarsFile} | cut -d= -f2-`
	sqlHost=`echo ${sqlURL} | cut -d: -f3 | sed 's/\///g'`
	sqlType=`echo ${sqlURL} | cut -d: -f2`
	sqlPort=`echo ${sqlURL} | cut -d: -f4 | cut -d/ -f1`
	sqlDB=`echo ${sqlURL} | cut -d: -f4 | cut -d/ -f2 | cut -d'?' -f1`

	if [ "${sqlType}" = "mysql" ]; then
		mysqldump -h ${sqlHost} -P ${sqlPort} --user=${sqlUser} --password="${sqlPass}" --skip-lock-tables ${sqlDB} > ${sqlDumpFile}
	else
		echo "Unknown database type."
	fi

	echo "etype=\"${sqlType}\"" >> ${importFile}
	echo "epass=\"${sqlPass}\"" >> ${importFile}
	echo "euser=\"${sqlUser}\"" >> ${importFile}
	echo "ehost=\"${sqlHost}\"" >> ${importFile}
	echo "eport=\"${sqlPort}\"" >> ${importFile}
	echo "eDB=\"${sqlDB}\"" >> ${importFile}
	esalt=`grep "^salt" ${eptidVarsFile} | cut -d= -f2-`
	echo "esalt=\"${esalt}\"" >> ${importFile}
else
	echo "Can not find attribute eduPersonTargetedID in attribute-resolver.xml, not running sql-dump."
fi

keystoreName=""
keystorePassword=""
keystoreType=""

if [ -s "${tomcatConfBase}/server.xml" ]; then
	keystoreName="keystoreFile"
	keystorePassword="keystorePass"
	keystoreType=""
	xsltproc -o ${tomcatVarsFile} ${Spath}/xslt/tomcat_data.xsl ${tomcatConfBase}/server.xml
elif [ -s "${tomcatConfBase}/jetty-shibboleth.xml" ]; then
	keystoreName="KeyStorePath"
	keystorePassword="KeyStorePassword"
	keystoreType="KeyStoreType"
	xsltproc -o ${tomcatVarsFile} ${Spath}/xslt/jetty_data.xsl ${tomcatConfBase}/jetty-shibboleth.xml
else
	echo "Could not find jetty/tomcat configuration."
	exit
fi

for i in `cat ${tomcatVarsFile} | grep ${keystoreName}`; do
	keyFile=`echo ${i} | cut -d= -f2`
	locationsToTar="${locationsToTar} ${keyFile}"
done

# get data for HTTPS port
tomcatSSLport=`cat ${tomcatVarsFile} | grep ${keystoreName} | grep -v "^8443" | cut -d'-' -f1`
echo "tomcatSSLport=\"${tomcatSSLport}\"" >> ${importFile}
httpspass=`cat ${tomcatVarsFile} | grep "^${tomcatSSLport}-${keystorePassword}" | cut -d= -f2-`
echo "httpspass=\"${httpspass}\"" >> ${importFile}
httpsP12=`cat ${tomcatVarsFile} | grep "^${tomcatSSLport}-${keystoreName}" | cut -d= -f2-`
echo "httpsP12=\"${httpsP12}\"" >> ${importFile}

# get data for port 8443
pass=`cat ${tomcatVarsFile} | grep "^8443-${keystorePassword}" | cut -d= -f2-`
echo "pass=\"${pass}\"" >> ${importFile}

if [ -d "/opt/kerberos" ]; then
	locationsToTar="${locationsToTar} /opt/kerberos/*"
fi
if [ -d "/opt/idp-kerberos" ]; then
	locationsToTar="${locationsToTar} /opt/idp-kerberos/*"
fi
if [ -f "/opt/shibboleth-idp/conf/fticks-key.txt" ]; then
	locationsToTar="${locationsToTar} /opt/shibboleth-idp/conf/fticks-key.txt"
fi

cd ${filesPath}
tarFile="${Spath}/idp-export-`hostname`_`date +%Y%m%d`.tar.gz"
tar zpcf ${tarFile} ${locationsToTar}

rm -r ${filesPath}

echo "
Please move the file ${tarFile} to the new IDP and put it in the deployer directory.
NOTE! The file contains cleartext passwords!
"
