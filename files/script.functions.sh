#!/bin/sh
# UTF-8



setBackTitle ()
{
	#	echo "in setBackTitle"
		btVar="BackTitle${my_ctl_federation}"
	#echo "in setBackTitle btVar=${btVar}, ${!btVar}"

	BackTitle="${!btVar} ${BackTitle}"
	
	# used in script.eduroam.functions.sh
	GUIbacktitle="${BackTitle}"

}



patchFirewall()
{
        #Replace firewalld with iptables (Centos7)
	${Echo} "Working with Distro:${dist} with version: ${redhatDist}"
        
        if [ "${dist}" == "centos" -a "${redhatDist}" == "7" ]; then
		${Echo} "Updating firewall settings - changing from firewalld to iptables "
		${Echo} "Detected ${dist} ${redhatDist}"
                systemctl stop firewalld
                systemctl mask firewalld
                eval "yum -y install iptables-services" >> ${statusFile} 2>&1
                systemctl enable iptables
                systemctl start iptables

        elif [ "${dist}" == "redhat" -a "${redhatDist}" == "7" ]; then
		${Echo} "Updating firewall settings - changing from firewalld to iptables "
		${Echo} "Detected ${dist} ${redhatDist}"
                systemctl stop firewalld
                systemctl mask firewalld
                eval "yum -y install iptables-services" >> ${statusFile} 2>&1
                systemctl enable iptables
                systemctl start iptables

	elif [ "${dist}" == "ubuntu" ]; then
		${Echo} "Detected ${dist} ${redhatDist}"

		DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent	
        fi

}

fetchJavaIfNeeded ()

{
	${Echo} "setJavaHome deprecates fetchJavaIfNeeded and ensures latest java is used"
	

}

notifyMessageDeployBeginning ()
{
	${Echo} "Starting deployment!"
}


setVarUpgradeType ()

{

	if [ -d "/opt/shibboleth-idp" ]; then
		upgrade=1
	fi
}

setVarPrepType ()

{
prep="prep/${type}"

}

setVarCertCN ()

{
certCN=`${Echo} ${idpurl} | cut -d/ -f3`

}
setVarIdPScope ()
{

	idpScope="${freeRADIUS_realm}"
}

updateJavaAlternatives() {
	for i in `ls $JAVA_HOME/bin/`; do
		rm -f /var/lib/alternatives/$i
		update-alternatives --install /usr/bin/$i $i $JAVA_HOME/bin/$i 100
		update-alternatives --set $i $JAVA_HOME/bin/$i
	done
}

installOracleJava () {
	javaType=$1

	if [ "${javaType}" != "jdk" ]; then
		javaType="jre"
	fi

	javaSrc="${javaType}-${javaName}-linux-x64.tar.gz"
	javaDownloadLink="http://download.oracle.com/otn-pub/java/jdk/${javaBuildName}/${javaSrc}"
	jceDownloadLink="http://download.oracle.com/otn-pub/java/jce/${javaMajorVersion}/${jcePolicySrc}"

	# force the latest java onto the system to ensure latest is available for all operations.
	# including the calculation of JAVA_HOME to be what this script sees on the system, not what a stale environment may have

	if [ -L "/usr/java/default" -a -d "/usr/java/${javaType}${javaVer}" ]; then
		export JAVA_HOME=/usr/java/default
		${Echo} "Detected Java allready installed in ${JAVA_HOME}."

		if [ -z "`readlink -e /usr/bin/java | grep \"${javaType}${javaVer}\"`" ]; then
			${Echo} "${JAVA_HOME} not used as default java. Updating system links.".
			updateJavaAlternatives
		fi
	else
		${Echo} "Oracle java not detected."

		unset JAVA_HOME

		# Download if needed and install from src
		${Echo} "Downloading java."
		if [ ! -s "${downloadPath}/${javaSrc}" ]; then
			${fetchCmd} ${downloadPath}/${javaSrc} -j -L -H "Cookie: oraclelicense=accept-securebackup-cookie" ${javaDownloadLink} 2>&1
		fi

		${Echo} "Unpacking java and setting up symlinks."
		if [ ! -d "/usr/java" ]; then
			mkdir /usr/java
		fi
		tar xzf ${downloadPath}/${javaSrc} -C /usr/java/
		unpackRet=$?

		if [ "${unpackRet}" -ne 0 ]; then
			${Echo} "Unpacking java failed, aborting script."
			rm -r /usr/java/${javaType}${javaVer}/
			return 1
		fi

		if [ -d "/usr/java/latest" ]; then
			mv /usr/java/latest /usr/java/latest.old
		fi
		if [ -s "/usr/java/latest" ]; then
			rm -f /usr/java/latest
		fi
		ln -s /usr/java/${javaType}${javaVer}/ /usr/java/latest

		if [ -d "/usr/java/default" ]; then
			mv /usr/java/default /usr/java/default.old
		fi
		if [ -s "/usr/java/default" ]; then
			rm -f /usr/java/default
		fi
		ln -s /usr/java/latest /usr/java/default

		export JAVA_HOME="/usr/java/default"
		export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
		# Set the alternatives
		updateJavaAlternatives

		echo "***javahome is: ${JAVA_HOME}"
	fi


	# Regardless of origin, let's validate it's existence then ensure it's in our .bashrc and our path

	${JAVA_HOME}/bin/java -version 2>&1
	retval=$?

	if [ "${retval}" -ne 0 ]; then
		${Echo} "\n\n\nAn error has occurred in the configuration of the JAVA_HOME variable."
		${Echo} "Please review the java installation log to see what went wrong."
		return 1
	else

		${Echo} "\n\n\nJAVA_HOME version verified as good."
		jEnvString="export JAVA_HOME=${JAVA_HOME}"

		if [ -z "`grep 'JAVA_HOME' /root/.bashrc`" ]; then

			${Echo} "${jEnvString}" >> /root/.bashrc
			${Echo} "\n\n\nJAVA_HOME added to end of /root/.bashrc"

		else
			if [ "`grep "export JAVA_HOME" /root/.bashrc | tail -n1`" != "${jEnvString}" ]; then
				${Echo} "${jEnvString}" >> /root/.bashrc
				${Echo} "\n\n\n***EXISTING JAVA_HOME DETECTED AND OVERRIDDEN!***"
				${Echo} "\nA new JAVA_HOME has been appended to end of /root/.bashrc to ensure the latest javahome is used. Hand edit as needed\n\n"
			fi

		fi

		# Ensure the java is in our execution path both in execution AND in the .bashrc

		if [ -z "`grep PATH /root/.bashrc | grep \"${JAVA_HOME}/bin\"`" ]; then
			${Echo} "export PATH=${PATH}:${JAVA_HOME}/bin" >> /root/.bashrc
			${Echo} "\n\n\nUpdated PATH to add java bin dir at end of /root/.bashrc"
			export PATH=${PATH}:${JAVA_HOME}/bin
		fi

	fi


	JCETestCmd="java -classpath ${downloadPath} checkJCEStrength"

	${Echo} "Testing Java Cryptography Extensions"
	JCETestResults=$(eval ${JCETestCmd})

	if [ "${JCETestResults}" == "${JCEUnlimitedResponse}" ]; then
		${Echo} "Java Cryptography Extensions alredy installed."
	else
		${Echo} "Setting Java Cryptography Extensions to unlimited strength"

		# Backup originals
		JCEBkp1="local_policy.jar"
		JCEBkp2="US_export_policy.jar"
		JCEBkp1Path="${JAVA_HOME}/lib/security/${JCEBkp1}"
		JCEBkp2Path="${JAVA_HOME}/lib/security/${JCEBkp2}"
		JCEBkpPostfix=`date +%F-%s`
		${Echo} "Backing up ${JCEBkp1} and ${JCEBkp1} from ${JAVA_HOME} to ${Spath}"
		if [ "${javaType}" == "jdk" ]; then
			JCEBkp1Path="${JAVA_HOME}/jre/lib/security/${JCEBkp1}"
			JCEBkp2Path="${JAVA_HOME}/jre/lib/security/${JCEBkp2}"
		fi
		cp ${JCEBkp1Path} ${Spath}/${JCEBkp1}-${JCEBkpPostfix}
		cp ${JCEBkp2Path} ${Spath}/${JCEBkp2}-${JCEBkpPostfix}

		# Fetch new policy file
		if [ ! -s "${downloadPath}/${jcePolicySrc}" ]; then
			${Echo} "Fetching Java Cryptography Extensions from Oracle"
			${fetchCmd} ${downloadPath}/${jcePolicySrc} -j -L -H "Cookie: oraclelicense=accept-securebackup-cookie" ${jceDownloadLink} 2>&1
		fi

		# Extract locally into downloads directory
		unzip -o ${downloadPath}/${jcePolicySrc} -d ${downloadPath}
		jceUnpacRet=$?
		if [ "${jceUnpacRet}" -ne "0" ]; then
			${Echo} "**Unpacking Java Cryptography Extensions update failed!**"
			${Echo} "**Install will succeed but you will not operate at full crypto strength **"
			${Echo} "**Some Service Providers will fail to negotiate.**"
			return 0
		fi

		# copy into place
		${Echo} "Putting Java Cryptography Extensions from Oracle into ${JAVA_HOME}/lib/security/"

		JCEWorkingDir="${downloadPath}/UnlimitedJCEPolicyJDK8"
		cp ${JCEWorkingDir}/${JCEBkp1} ${JCEBkp1Path}
		cp ${JCEWorkingDir}/${JCEBkp2} ${JCEBkp2Path}

		${Echo} "Testing Java Cryptography Extensions"
		JCETestResults=$(eval ${JCETestCmd})

		if [ "${JCETestResults}" == "${JCEUnlimitedResponse}" ]; then
			${Echo} "Java Cryptography Extensions update succeeded"
		else
			${Echo} "**Java Cryptography Extensions update failed! rolling back using backups**"
			${Echo} "**Install will succeed but you will not operate at full crypto strength **"
			${Echo} "**Some Service Providers will fail to negotiate.**"

			cp ${downloadPath}/${JCEBkp1}-${JCEBkpPostfix} ${JCEBkp1Path}
			cp ${downloadPath}/${JCEBkp2}-${JCEBkpPostfix} ${JCEBkp2Path}
		fi
	fi

	return 0
}

setJavaHome () {
	# force the latest java onto the system to ensure latest is available for all operations.
	# including the calculation of JAVA_HOME to be what this script sees on the system, not what a stale environment may have

	# June 23, 2015, altering java detection behaviour to be more platform agnostic

	installOracleJava
	retval=$?

	if [ "${retval}" -ne 0 ]; then
		${Echo} "\n\n\nAn error has occurred in the configuration of the JAVA_HOME variable."
		${Echo} "Please review the java installation and status.log to see what went wrong."
		${Echo} "Install is aborted until this is resolved."
		cleanBadInstall
		exit
	fi
}

setJavaCACerts ()

{
        javaCAcerts="${JAVA_HOME}/lib/security/cacerts"
        keytool="${JAVA_HOME}/bin/keytool"
	
}


setJavaCryptographyExtensions ()
{
# requires that Oracle's java is already installed in the system and will auto-accept the license.
# download instructions are found here: http://www.oracle.com/technetwork/java/javase/downloads/jce8-download-2133166.html
#
# because they are crypto settings, this function is abstracted out

	${Echo} "Setting Java Cryptography Extensions to unlimited strength" | tee -a ${statusFile}

# Backup originals
	JCEBkp1="local_policy.jar"
	JCEBkp2="US_export_policy.jar"
	JCEBkpPostfix=`date +%F-%s`
	${Echo} "Backing up ${JCEBkp1} and ${JCEBkp1} from ${JAVA_HOME} to ${Spath}/backups" | tee -a ${statusFile}
	eval "cp ${JAVA_HOME}/lib/security/${JCEBkp1} ${Spath}/backups/${JCEBkp1}-${JCEBkpPostfix}" &> >(tee -a ${statusFile})
	eval "cp ${JAVA_HOME}/lib/security/${JCEBkp2} ${Spath}/backups/${JCEBkp2}-${JCEBkpPostfix}" &> >(tee -a ${statusFile})

# Fetch new policy file
	${Echo} "Fetching Java Cryptography Extensions from Oracle" | tee -a ${statusFile}

        jcePolicySrc="jce_policy-8.zip"

        if [ ! -s "${downloadPath}/${jcePolicySrc}" ]; then
                ${fetchCmd} ${downloadPath}/${jcePolicySrc} -j -L -H "Cookie: oraclelicense=accept-securebackup-cookie"  http://download.oracle.com/otn-pub/java/jce/8/${jcePolicySrc} >> ${statusFile} 2>&1
        fi
       
# Extract locally into downloads directory

       eval "(pushd ${downloadPath}; unzip -o ${downloadPath}/${jcePolicySrc}; popd)" &> >(tee -a ${statusFile})

# copy into place
	${Echo} "Putting Java Cryptography Extensions from Oracle into ${JAVA_HOME}/lib/security/" | tee -a ${statusFile}

	JCEWorkingDir="${downloadPath}/UnlimitedJCEPolicyJDK8"
	eval "cp ${JCEWorkingDir}/${JCEBkp1} ${JAVA_HOME}/lib/security/${JCEBkp1}" &> >(tee -a ${statusFile})
	eval "cp ${JCEWorkingDir}/${JCEBkp2} ${JAVA_HOME}/lib/security/${JCEBkp2}" &> >(tee -a ${statusFile})

	${Echo} "Testing Java Cryptography Extensions" | tee -a ${statusFile}
	JCEUnlimitedResponse="2147483647"
	JCETestCmd="java -classpath ${downloadPath} checkJCEStrength"
	JCETestResults=$(eval ${JCETestCmd}) 

	if [ "${JCETestResults}" ==  "${JCEUnlimitedResponse}" ]
	     then
            ${Echo} "Java Cryptography Extensions update succeeded" | tee -a ${statusFile}
	else
			${Echo} "**Java Cryptography Extensions update failed! rolling back using backups**" | tee -a ${statusFile}
			${Echo} "**Install will succeed but you will not operate at full crypto strength **" | tee -a ${statusFile}
			${Echo} "**Some Service Providers will fail to negotiate. See https://github.com/canariecaf/idp-installer-CAF/issues/71 **" | tee -a ${statusFile}

	eval "cp  ${Spath}/backups/${JCEBkp1}-${JCEBkpPostfix} ${JAVA_HOME}/lib/security/${JCEBkp1}" &> >(tee -a ${statusFile})
	eval "cp ${Spath}/backups/${JCEBkp2}-${JCEBkpPostfix} ${JAVA_HOME}/lib/security/${JCEBkp2}" &> >(tee -a ${statusFile})


	fi



}




generatePasswordsForSubsystems ()

{
	# generate keystore pass
	if [ -z "${pass}" ]; then
		pass=`${passGenCmd}`

		if [ "${installer_interactive}" = "n" ]; then
			${Echo} "Shibboleth keystore password is '${pass}'" >> ${statusFile}
		fi
	fi
	if [ -z "${httpspass}" ]; then
		httpspass=`${passGenCmd}`

		if [ "${installer_interactive}" = "n" ]; then
			${Echo} "HTTPS JKS keystore password is '${httpspass}'" >> ${statusFile}
		fi
	fi
	if [ -z "${mysqlPass}" -a "${eptid}" != "n" ]; then
		mysqlPass=`${passGenCmd}`
		${Echo} "Mysql root password generated\nPassword is '${mysqlPass}'" >> ${messages}

		if [ "${installer_interactive}" = "n" ]; then
			${Echo} "MySQL password is '${mysqlPass}'" >> ${statusFile}
		fi
	fi

}



setHostnames() {
	FQDN=`hostname`
	FQDN=`host -t A ${FQDN} | awk '{print $1}' | sed -re 's/\s+//g'`
	Dname=`${Echo} ${FQDN} | cut -d\. -f2-`
	if [ "${FQDN}" = "Host" ]
	then
		eval ${dist_install_netstat} >> ${statusFile} 2>&1

		myInterface=`netstat -nr | grep "^0.0.0.0" | awk '{print $NF}'`
		myIP=`ip addr list ${myInterface} | grep "inet " | cut -d' ' -f6 | cut -d/ -f1`
		Dname=`host -t A ${myIP} | head -1 | awk '{print $NF}' | cut -d\. -f2- | sed 's/\.$//'`
		FQDN=`host -t A ${myIP} | head -1 | awk '{print $NF}' | sed 's/\.$//'`
	fi
}



fetchCas() {
	${Echo} "Cas-client not found, fetching from web"
	${fetchCmd} ${downloadPath}/cas-client-${casVer}-release.zip ${casClientURL}

	if [ ! -s ${downloadPath}/cas-client-${casVer}-release.zip ]; then
		${Echo} "Error while downloading CAS client, aborting."
		cleanBadInstall
	fi
}

fetchMysqlCon() {

	echo "Mysql Connector now in the download folder"
	#  Deprecated fetching to presence in downloadPath

	#	if [ ! -s "${downloadPath}/mysql-connector-java-${mysqlConVer}.tar.gz" ]; then
	#		${Echo} "Error while downloading mysql-connector, aborting."
	#		cleanBadInstall
	#	fi
}


installEPTIDSupport ()
        {
        if [ "${eptid}" != "n" ]; then
                ${Echo} "Installing EPTID support"

		if [ "${dist}" == "ubuntu" ]; then
			test=`dpkg -s mysql-server > /dev/null 2>&1`
			isInstalled=$?

                elif [ "$dist" == "sles" ]; then
			#package catalog test
			#test=`zypper search -i mysql > /dev/null 2>&1`
                        [ -f /etc/init.d/mysql ]
                        isInstalled=$?

		elif [ "${dist}" == "centos" -o "${dist}" == "redhat" ]; then
			if [ "${redhatDist}" == "6" ]; then
				[ -f /etc/init.d/mysqld ]
				isInstalled=$?

			elif [ "${redhatDist}" == "7" ]; then
				#Add Oracle repos
				if [ ! -z "`rpm -q mysql-community-release | grep ' is not installed'`" ]; then
					${Echo} "Detected no MySQL, adding repos into /etc/yum.repos.d/ and updating them"
					mysqlOracleRepo="rpm -Uvh http://repo.mysql.com/mysql-community-release-el7.rpm"
					eval $mysqlOracleRepo >> ${statusFile} 2>&1
				else
					${Echo} "Dected MySQL Repo EXIST on this system."

				fi
				test=`rpm -q mysql-community-server > /dev/null 2>&1`
				isInstalled=$?

			fi
		fi

                if [ "${isInstalled}" -ne 0 ]; then
                        export DEBIAN_FRONTEND=noninteractive
                        eval ${distCmd5} >> ${statusFile} 2>&1

                        mysqldTest=`pgrep mysqld`
                        if [ -z "${mysqldTest}" ]; then
                                if [ ${dist} == "ubuntu" ]; then
                                        service mysql restart >> ${statusFile} 2>&1
                                elif [ "${dist}" == "sles" ]; then
					systemctl enable mysql
                                        service mysql restart >> ${statusFile} 2>&1
                                else
                                        service mysqld restart >> ${statusFile} 2>&1
                                fi
                        fi
                        # set mysql root password
                        tfile=`mktemp`
                        if [ ! -f "$tfile" ]; then
                                return 1
                        fi
                        cat << EOM > $tfile
USE mysql;
UPDATE user SET password=PASSWORD("${mysqlPass}") WHERE user='root';
FLUSH PRIVILEGES;
EOM

                        mysql --no-defaults -u root -h localhost <$tfile
                        retval=$?
                        # moved removal of MySQL command file to be in the if-then-else statement set below

                        if [ "${retval}" -ne 0 ]; then
                                ${Echo} "\n\n\nAn error has occurred in the configuration of the MySQL installation."
                                ${Echo} "Please correct the MySQL installation and make sure a root password is set and it is possible to log in using the 'mysql' command."
                                ${Echo} "When MySQL is working, re-run this script."
                                ${Echo} "The file being run in MySQL is ${tfile} and has not been deleted, please review and delete as necessary."
                                cleanBadInstall
                        else
                                rm -f $tfile
                        fi


			if [ "${dist}" == "centos" -o "${dist}" == "redhat" ]; then
                                /sbin/chkconfig mysqld on
                        fi
                fi

                fetchMysqlCon
                cd /opt
                tar zxf ${downloadPath}/mysql-connector-java-${mysqlConVer}.tar.gz -C /opt >> ${statusFile} 2>&1
                cp /opt/mysql-connector-java-${mysqlConVer}/mysql-connector-java-${mysqlConVer}-bin.jar /opt/shibboleth-idp/edit-webapp/WEB-INF/lib/
		/opt/shibboleth-idp/bin/build.sh -Didp.target.dir=/opt/shibboleth-idp

        fi



        }

installCasClientIfEnabled() {

if [ "${type}" = "cas" ]; then

	if [ ! -f "${downloadPath}/cas-client-${casVer}-release.zip" ]; then
		fetchCas
	fi
	unzip -qo ${downloadPath}/cas-client-${casVer}-release.zip -d /opt
	if [ ! -s "/opt/cas-client-${casVer}/modules/cas-client-core-${casVer}.jar" ]; then
		${Echo} "Unzip of cas-client failed, check zip file: ${downloadPath}/cas-client-${casVer}-release.zip"
		cleanBadInstall
	fi

	if [ -z "${idpurl}" ]; then
		idpurl=$(askString "IDP URL" "Please input the URL to this IDP (https://idp.xxx.yy)" "https://${FQDN}")
	fi

	if [ -z "${casurl}" ]; then
		casurl=$(askString "CAS URL" "Please input the URL to yourCAS server (https://cas.xxx.yy/cas)" "https://cas.${Dname}/cas")
	fi

	if [ -z "${caslogurl}" ]; then
		caslogurl=$(askString "CAS login URL" "Please input the Login URL to your CAS server (https://cas.xxx.yy/cas/login)" "${casurl}/login")
	fi

	cp /opt/cas-client-${casVer}/modules/cas-client-core-${casVer}.jar /opt/shibboleth-idp/edit-webapp/WEB-INF/lib/
	cp ${Spath}/downloads/shib-cas-authenticator-3.0.0.jar /opt/shibboleth-idp/edit-webapp/WEB-INF/lib/
	cp /opt/shibboleth-idp/webapp/WEB-INF/web.xml /opt/shibboleth-idp/edit-webapp/WEB-INF/
	mkdir -p /opt/shibboleth-idp/flows/authn/Shibcas
	cp ${Spath}/${prep}/shibcas-authn-beans.xml ${Spath}/${prep}/shibcas-authn-flow.xml /opt/shibboleth-idp/flows/authn/Shibcas

	patch /opt/shibboleth-idp/edit-webapp/WEB-INF/web.xml -i ${Spath}/${prep}/${shibDir}-web.xml.diff >> ${statusFile} 2>&1
	patch /opt/shibboleth-idp/conf/authn/general-authn.xml -i ${Spath}/${prep}/${shibDir}-general-authn.xml.diff >> ${statusFile} 2>&1

	/opt/shibboleth-idp/bin/build.sh -Didp.target.dir=/opt/shibboleth-idp

else
	${Echo} "Authentication type: ${type}, CAS Client Not Requested"


fi



}

fetchAndUnzipShibbolethIdP ()

{
	cd /opt

	if [ ! -f "${downloadPath}/${shibDir}-${shibVer}.tar.gz" ]; then
		${Echo} "Shibboleth not found, fetching from web"
		${fetchCmd} ${downloadPath}/${shibDir}-${shibVer}.tar.gz ${shibbURL}

		if [ ! -s ${downloadPath}/${shibDir}-${shibVer}.tar.gz ]; then
		${Echo} "Error while downloading Shibboleth, aborting."
		cleanBadInstall
		fi
	fi

# 	unzip all files
	${Echo} "Unzipping dependancies"

	tar xzf ${downloadPath}/${shibDir}-${shibVer}.tar.gz -C /opt
	chmod -R 755 /opt/${shibDir}-${shibVer}
	ln -s ${shibDir}-${shibVer} ${shibDir}
}



createCertificatePathAndHome ()

{

mkdir -p ${certpath}
	

}

fetchLDAPCertificates ()
{
	# Fetch ldap cert
	${Echo} "Fetching LDAP Certificates for ldap-server.crt used in idp.properties"
	for loopServer in ${ldapserver}; do
		${Echo} "QUIT" | openssl s_client -connect ${loopServer}:636 2>/dev/null | sed -ne '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' >> ${certpath}/ldap-server.crt
	done

}

installCertificates()

{

# change to certificate path whilst doing this part
cd ${certpath}
${Echo} "Fetching TCS CA chain from web"
        ${fetchCmd} ${certpath}/server.chain ${certificateChain}
        if [ ! -s "${certpath}/server.chain" ]; then
                ${Echo} "Can not get the certificate chain, aborting install."
                cleanBadInstall
        fi

        ${Echo} "Installing TCS CA chain in java cacert keystore"
        cnt=1
        for i in `cat ${certpath}server.chain | sed -re 's/\ /\*\*\*/g'`; do
                n=`${Echo} ${i} | sed -re 's/\*\*\*/\ /g'`
                ${Echo} ${n} >> ${certpath}${cnt}.root
                ltest=`${Echo} ${n} | grep "END CERTIFICATE"`
                if [ ! -z "${ltest}" ]; then
                        cnt=`expr ${cnt} + 1`
                fi
        done
        ccnt=1
        while [ ${ccnt} -lt ${cnt} ]; do
                md5finger=`${keytool} -printcert -file ${certpath}${ccnt}.root | grep MD5 | cut -d: -f2- | sed -re 's/\s+//g'`
                test=`${keytool} -list -keystore ${javaCAcerts} -storepass changeit | grep ${md5finger}`
                subject=`openssl x509 -subject -noout -in ${certpath}${ccnt}.root | awk -F= '{print $NF}'`
                if [ -z "${test}" ]; then
                        ${keytool} -import -noprompt -trustcacerts -alias "${subject}" -file ${certpath}${ccnt}.root -keystore ${javaCAcerts} -storepass changeit >> ${statusFile} 2>&1
                fi
                files="`${Echo} ${files}` ${certpath}${ccnt}.root"
                ccnt=`expr ${ccnt} + 1`
        done

}



askForConfigurationData() {
	if [ -z "${type}" ]; then
		tList=""
		tAccept=""
		tGo=0
		for i in `ls ${Spath}/prep | sed -re 's/\n/\ /g'`; do
			tDesc=`cat ${Spath}/prep/${i}/.desc`
			tList="`${Echo} ${tList}` \"${i}\" \"${tDesc}\""
			tAccept=`${Echo} ${tAccept} ${i}`
		done

		while [ ${tGo} -eq 0 ]; do
			type=$(askList "Authentication type" "Which authentication type do you want to use?" "${tList}")
			for i in ${tAccept}; do
				if [ "${i}" = "${type}" ]; then
					tGo=1
					break
				fi
			done
		done
	fi
	prep="prep/${type}"

	if [ -z "${google}" ]; then
		google=$(askYesNo "Attributes to Google" "Do you want to release attributes to google?\nSwamid, Swamid-test and testshib.org installed as standard" "no")
	fi

	if [ "${google}" != "n" -a -z "${googleDom}" ]; then
		googleDom=$(askString "Your Google domain name" "Please input your Google domain name (student.xxx.yy)." "student.${Dname}")
	fi

	if [ -z "${ntpserver}" ]; then
		ntpserver=$(askString "NTP server" "Please input your NTP server address." "ntp.${Dname}")
	fi

	if [ -z "${ldapserver}" ]; then
		ldapserver=$(askString "LDAP server" "Please input yout LDAP server(s) (ldap.xxx.yy).\n\nSeparate multiple servers with spaces.\nLDAPS is used by default." "ldap.${Dname}")
	fi

	if [ -z "${ldapbasedn}" ]; then
		ldapbasedn=$(askString "LDAP Base DN" "Please input your LDAP Base DN")
	fi

	if [ -z "${ldapbinddn}" ]; then
		ldapbinddn=$(askString "LDAP Bind DN" "Please input your LDAP Bind DN")
	fi

	if [ -z "${ldappass}" ]; then
		ldappass=$(askString "LDAP Password" "Please input your LDAP Password")
	fi

	if [ "${type}" = "ldap" -a -z "${subsearch}" ]; then
		subsearch=$(askYesNo "LDAP Subsearch" "Do you want to enable LDAP subtree search?")
		subsearch="false"
		if [ "${subsearchNum}" = "y" ]; then
			subsearch="true"
		fi
	fi

	if [ -z "${ninc}" ]; then
		ninc=$(askString "norEduPersonNIN" "Please specify LDAP attribute for norEduPersonNIN (YYYYMMDDnnnn)" "norEduPersonNIN")
	fi

	if [ -z "${idpurl}" ]; then
		idpurl=$(askString "IDP URL" "Please input the URL to this IDP (https://idp.xxx.yy)" "https://${FQDN}")
	fi

	if [ "${type}" = "cas" ]; then
		if [ -z "${casurl}" ]; then
			casurl=$(askString "CAS URL" "Please input the URL to yourCAS server (https://cas.xxx.yy/cas)" "https://cas.${Dname}/cas")
		fi

		if [ -z "${caslogurl}" ]; then
			caslogurl=$(askString "CAS login URL" "Please input the Login URL to your CAS server (https://cas.xxx.yy/cas/login)" "${casurl}/login")
		fi
	fi

	if [ -z "${certOrg}" ]; then
		certOrg=$(askString "Certificate organisation" "Please input organisation name string for certificate request")
	fi

	if [ -z "${certC}" ]; then
		certC=$(askString "Certificate country" "Please input country string for certificate request" "SE")
	fi

	if [ -z "${certAcro}" ]; then
		acro=""
		for i in ${certOrg}; do
			t=`${Echo} ${i} | cut -c1`
			acro="${acro}${t}"
		done

		certAcro=$(askString "Organisation acronym" "Please input organisation Acronym (eg. 'HiG')" "${acro}")
	fi

	if [ -z "${certLongC}" ]; then
		certLongC=$(askString "Country descriptor" "Please input country descriptor (eg. 'Sweden')" "Sweden")
	fi

	if [ -z "${fticks}" ]; then
		fticks=$(askYesNo "Send anonymous data" "Do you want to send anonymous usage data to ${my_ctl_federation}?\nThis is recommended")
	fi

	if [ -z "${eptid}" ]; then
		eptid=$(askYesNo "eduPersonTargetedID" "Do you want to install support for eduPersonTargetedID?\nThis is recommended")
	fi

	if [ "${eptid}" != "n" -a "${passw_input}" = "y" ]; then
		mysqlPass=$(askString "MySQL password" "MySQL is used for supporting the eduPersonTargetedId attribute.\n\n Please set the root password for MySQL.\nAn empty string generates a randomized new password" "" 1)
	fi

	if [ -z "${selfsigned}" ]; then
		selfsigned=$(askYesNo "Self signed certificate" "Create a self signed certificate for HTTPS?\n\nThis is NOT recommended for production systems! Only for testing purposes" "y")
	fi

	if [ "${passw_input}" = "y" ]; then
		pass=$(askString "IDP keystore password" "The IDP keystore is for the Shibboleth software itself and not the webserver. Please set your IDP keystore password.\nAn empty string generates a randomized new password" "" 1)
		httpspass=$(askString "HTTPS Keystore password" "The webserver uses a separate keystore for itself. Please input your Keystore password for the end user facing HTTPS.\n\nAn empty string generates a randomized new password" "" 1)
	fi

	if [ -z "${consentEnabled}" ]; then
		consentEnabled=$(askYesNo "User consent" "Do you want to enable user consent?")
	fi

	if [ -z "${ECPEnabled}" ]; then
		ECPEnabled=$(askYesNo "Enable ECP" "Do you want to enable SAML2 ECP?")
	fi


}


prepConfirmBox() {
	cat > ${downloadPath}/confirm.tx << EOM
Options passed to the installer:


Authentication type:       ${type}

Release to Google:         ${google}
Google domain name:        ${googleDom}

NTP server:                ${ntpserver}

LDAP server:               ${ldapserver}
LDAP Base DN:              ${ldapbasedn}
LDAP Bind DN:              ${ldapbinddn}
LDAP Subsearch:            ${subsearch}
norEduPersonNIN:           ${ninc}

IDP URL:                   ${idpurl}
CAS Login URL:             ${caslogurl}
CAS URL:                   ${casurl}

Cert org string:           ${certOrg}
Cert country string:       ${certC}
norEduOrgAcronym:          ${certAcro}
Country descriptor:        ${certLongC}

Usage data to ${my_ctl_federation}:      ${fticks}
EPTID support:             ${eptid}

Create self seigned cert:  ${selfsigned}
EOM
}

writeConfigFile() {
		cat > ${Spath}/config << EOM
type="${type}"
google="${google}"
googleDom="${googleDom}"
ntpserver="${ntpserver}"
ldapserver="${ldapserver}"
ldapbasedn="${ldapbasedn}"
ldapbinddn="${ldapbinddn}"
subsearch="${subsearch}"
idpurl="${idpurl}"
caslogurl="${caslogurl}"
casurl="${casurl}"
certOrg="${certOrg}"
certC="${certC}"
fticks="${fticks}"
eptid="${eptid}"
selfsigned="${selfsigned}"
ninc="${ninc}"
certAcro="${certAcro}"
certLongC="${certLongC}"
EOM
}

installMavenRC() {

maven2URL="http://mirror.its.dal.ca/apache/maven/maven-3/3.1.1/binaries/apache-maven-3.1.1-bin.tar.gz"
maven2File="${maven2URL##*/}"

maven2Path=`basename ${maven2File}  -bin.tar.gz`

	if [ -a "/opt/${maven2Path}/bin/mvn" ]
	then
		echo "Maven detected as installed"
	else
		echo "Fetching Maven from ${maven2URL}"

		${fetchCmd} ${downloadPath}/${maven2File} "{$maven2URL}"
		cd /opt
		tar zxf ${downloadPath}/${maven2File} >> ${statusFile} 2>&1

		
	fi
	export PATH=${PATH}:${maven2Path}/bin	


#	if [ ! -s "${downloadPath}/apache-maven-3.1.0-bin.tar.gz" ]; then
#		${fetchCmd} ${downloadPath}/apache-maven-3.1.0-bin.tar.gz http://mirrors.gigenet.com/apache/maven/maven-3/3.1.0/binaries/apache-maven-3.1.0-bin.tar.gz >> ${statusFile} 2>&1
#	fi

#	if [ ! -d "/opt/apache-maven-3.1.1/bin/" ]; then
#		tar -zxf ${downloadPath}/apache-maven-3.1.0-bin.tar.gz -C /opt
#	fi
	if [ ! -s "/etc/profile.d/maven-3.1.sh" ]; then
		cat > /etc/profile.d/maven-3.1.sh << EOM
export M2_HOME=/opt/apache-maven-3.1.1
export M2=\$M2_HOME/bin
PATH=\$M2:\$PATH
EOM
	fi
	if [ -z "${M2_HOME}" ]; then
		. /etc/profile.d/maven-3.1.sh
	fi
}

configShibbolethXMLAttributeResolverForLDAP ()
{
	# using ${my_ctl_federation} as the federation tag to pivot on regarding what to do.
	
	ldapServerStr=""
	for i in `${Echo} ${ldapserver}`; do
		ldapServerStr="`${Echo} ${ldapServerStr}` ldaps://${i}"
	done
	ldapServerStr=`${Echo} ${ldapServerStr} | sed -re 's/^\s+//'`
	orgTopDomain=`${Echo} ${certCN} | cut -d. -f2-`

	${Echo} "Processing Attribute-resolver.xml customizations"

	cat ${Spath}/xml/${my_ctl_federation}/attribute-resolver.xml.template \
		| sed -re "s/NiNcRePlAcE/${ninc}/;s/CeRtAcRoNyM/${certAcro}/;s/CeRtOrG/${certOrg}/;s/CeRtC/${certC}/;s/CeRtLoNgC/${certLongC}/" \
		| sed -re "s/SCHAC_HOME_ORG/${orgTopDomain}/;s/LdApUsErAtTr/${attr_filter}/g" \
		> ${Spath}/xml/${my_ctl_federation}/attribute-resolver.xml
	files="`${Echo} ${files}` ${Spath}/xml/${my_ctl_federation}/attribute-resolver.xml"

        cat ${Spath}/xml/${my_ctl_federation}/ldapconn.template \
                | sed -re "s/AtTrFiLtEr/${attr_filter}/" \
                > ${Spath}/xml/${my_ctl_federation}/ldapconn.txt
        files="`${Echo} ${files}` ${Spath}/xml/${my_ctl_federation}/ldapconn.txt"


}

runShibbolethInstaller ()

{
        #       run shibboleth installer
        cd /opt/${shibDir}
        ${Echo} "Running shiboleth installer"


	# Set some default values

        if [ -x ${ldap_type} ]; then
                ldap_type="ad"
        fi

	if [ -x ${ldapStartTLS} ]; then
		ldapStartTLS="true"
	fi

        if [ -x ${ldapSSL} ]; then
                ldapSSL="false"
	fi

        if [ -x ${user_field} ]; then
                user_field="samaccountname"
        fi

        if [ -x ${attr_filter} ]; then
                attr_filter="uid"
        fi

        if [ -x ${ldap_attr} ]; then
                ldap_attr=""
        fi

	# ActiveDirectory specific
	if [ "${ldap_type}" = "ad" ]; then

              #Set idp.authn.LDAP.authenticator
              ldapAuthenticator="adAuthenticator"
	      # Extract AD domain from baseDN
	      #ldapbasedn_tmp=$(echo ${ldapbasedn}  | tr '[:upper:]' '[:lower:]')
	      #ldapDomain=$(echo ${ldapbasedn_tmp#ou*dc=} | sed "s/,dc=/./g")
	      #ldapDnFormat="%s@${ldapDomain}"
	      ldapDnFormat="%s@${ldapdn}"	

	 # Other LDAP implementations
	 else
	       #Set idp.authn.LDAP.authenticator
               ldapAuthenticator="bindSearchAuthenticator"
	       ldapDnFormat="uid=%s,${ldapbasedn}"
	 fi

#  Establish which authentication flows we have to configure

idpAuthnFlowsDefault="Password"
idpAuthnFlows=""

if [ "${ECPEnabled}" = "y" -a "${type}" = "ldap" ]; then

	idpAuthnFlows="${idpAuthnFlowsDefault}|RemoteUserInternal"
	${Echo} "ECP Specific setting detected: idp.properties authn flows are now set to ldap and ECP: ${idpAuthnFlows}"

elif [ "${ECPEnabled}" = "y" -a "${type}" = "cas" ]; then

	idpAuthnFlows="Shibcas|RemoteUserInternal"
	${Echo} "ECP Specific setting detected: idp.properties authn flows are now set to CAS and ECP: ${idpAuthnFlows}"

else
	
	idpAuthnFlows="${idpAuthnFlowsDefault}"
	${Echo} "idp.properties authn flows are set to the default use of password : ${idpAuthnFlows}"

fi


#  Auth flows part 2: what do we need to set for the installation?

	if [ "${type}" = "ldap" ]; then

	       cat << EOM > idp.properties.tmp
idp.scope               =${idpScope}
idp.entityID            = https://${certCN}/idp/shibboleth
idp.sealer.storePassword= ${pass}
idp.sealer.keyPassword  = ${pass}
idp.authn.flows		= Password
EOM

	elif [ "${type}" = "cas" ]; then

                cat << EOM > idp.properties.tmp
idp.scope                  = ${idpScope}
idp.entityID               = https://${certCN}/idp/shibboleth
idp.sealer.storePassword   = ${pass}
idp.sealer.keyPassword     = ${pass}
idp.authn.flows            = Shibcas
shibcas.casServerUrlPrefix = ${casurl}
shibcas.casServerLoginUrl  = \${shibcas.casServerUrlPrefix}/login
shibcas.serverName         = https://${certCN}
EOM

	fi

	# Set LDAP configuration (needed for both cas and ldap)
        cat << EOM > ldap.properties.tmp
idp.authn.LDAP.authenticator                    = ${ldapAuthenticator}
idp.authn.LDAP.ldapURL                          = ${ldapurl}
idp.authn.LDAP.useStartTLS                      = ${ldapStartTLS}
idp.authn.LDAP.useSSL                           = ${ldapSSL}
idp.authn.LDAP.sslConfig                        = certificateTrust
idp.authn.LDAP.trustCertificates                = %{idp.home}/ssl/ldap-server.crt
idp.authn.LDAP.trustStore                       = %{idp.home}/credentials/ldap-server.truststore
idp.authn.LDAP.returnAttributes                 = ${ldap_attr}
idp.authn.LDAP.baseDN                           = ${ldapbasedn}
idp.authn.LDAP.subtreeSearch                    = true
idp.authn.LDAP.userFilter                       = (${attr_filter}={user})
idp.authn.LDAP.bindDN                           = ${ldapbinddn}
idp.authn.LDAP.bindDNCredential                 = ${ldappass}
idp.authn.LDAP.dnFormat                         = ${ldapDnFormat}
EOM

	# Run the installer
	JAVA_HOME=/usr/java/default sh bin/install.sh \
	-Didp.src.dir=./ \
	-Didp.target.dir=/opt/shibboleth-idp \
	-Didp.host.name="${certCN}" \
	-Didp.scope="${idpScope}" \
	-Didp.keystore.password="${pass}" \
	-Didp.sealer.password="${pass}" \
	-Dldap.merge.properties=./ldap.properties.tmp \
	-Didp.merge.properties=./idp.properties.tmp

}


enableStatusMonitoring() {

	${Echo} "enableStatusMonitoring: Processing started"

	# these are the defaults provided for Shibboleth
	defaultMonitoringIPs="127.0.0.1/32 ::1/128"

	# set the range to process but if empty, assign default range of localhost ipv4, ipv6
	rangeToProcess="${iprangesallowed-$defaultMonitoringIPs}"
	
	${Echo} "enableStatusMonitoring: Enabling Status Monitoring from the following IP ranges ${rangeToProcess}"
	declare -a myips=(${rangeToProcess})
	# take range as a bash array, and then join with a comma, suppressing the last one
	myRanges=`echo $(printf "'%s',"  "${myips[@]}")|sed 's/\(.*\),/\1/'`
	
	${Echo} "enableStatusMonitoring: Backing up original and applying our template to idp.home/conf/access-control.xml"

	# make backup
	cp /opt/shibboleth-idp/conf/access-control.xml /opt/shibboleth-idp/conf/access-control.xml.${fileBkpPostfix}
	# Overlay the template file 
	cp ${Spath}/prep/shibboleth/conf/access-control.xml.template /opt/shibboleth-idp/conf/access-control.xml

	# Apply the ranges to idp.properties
	${Echo} "enableStatusMonitoring: Appending Status Monitoring to idp.properties as idp.status.ipranges=${myRanges}"
	echo "idp.status.ipranges=${myRanges}" >> /opt/shibboleth-idp/conf/idp.properties
	
	${Echo} "enableStatusMonitoring: Processing completed"



}

enableECPUpdateIdPWebXML ()
{
		${Echo} "ECP Step: Update the web.xml of the idp and rebuild"
		${Echo} "ECP Step: make backup of web.xml"
		webXML="web.xml"
		webAppWEBINFOverride="/opt/shibboleth-idp/edit-webapp/WEB-INF"
		webAppWEBINF="/opt/shibboleth-idp/webapp/WEB-INF"
		# set to the overridden one provided it exists
		tgtFileToUpdate="${webAppWEBINFOverride}/${webXML}"
		tgtFileToUpdateBackup="${tgtFileToUpdate}.orig"

		# expected entry conditions of this if-then-else and subsequent logic block:
		# A. users and this code who touch web.xml will place file in Shibboleth edit-webapp location
		# B. syntactically the file will have the closing XML tag on the very last line (no extra spaces)
		# C. regardless of the use of CAS (which places the web.xml in the override location) we will pivot around overriding existing web.xml
		# D. the function enableECPUpdateIdPWebXML is executed after the detection and manipulation of the items for CAS
		# E.  the overriden web.xml is syntactically correct (we validate after processing but will not validate before)
		if [ -s "${tgtFileToUpdate}" ]; then
				${Echo} "ECP Step: CAS is your AuthN technique, web.xml being manipulated:${tgtFileToUpdate}"
		else				
				${Echo} "ECP Step: Regular Shibboleth AuthN detected, web.xml being cloned from webapp/WEB-INF into edit-webapp/WEB-INF"
				cp ${webAppWEBINF}/${webXML} ${webAppWEBINFOverride}
		fi

		# make the backup
		cp ${tgtFileToUpdate} ${tgtFileToUpdateBackup}


		${Echo} "ECP Step: modify web.xml to enable ECP features of jetty container"
			#  NOTE: The use of the greater than overwrites the file web.xml and we cat the fragment to complete it.
			#  this is intentional			
			head -n -1 ${tgtFileToUpdateBackup} > ${tgtFileToUpdate}
			cat ${Spath}/prep/jetty/web.xml.fragment.template >> ${tgtFileToUpdate}
		${Echo} "ECP Step: modifications done, attempting to validate web.xml as sane XML"

		mytest=`/usr/bin/xmllint ${tgtFileToUpdate} > /dev/null 2>&1`
		# $? is the most recent foreground pipeline exit status.  If it's ok, we did our job right.
		isWebXMLOK=$?

        if [ "${isWebXMLOK}" -ne 0 ]; then
			${Echo} "ECP Step: RUH-OH! web.xml failed to validate via xmllint. saving to web.xml.failed and reverting to original"
			cp ${tgtFileToUpdate} ${tgtFileToUpdate}.failed
			cp ${tgtFileToUpdateBackup} ${tgtFileToUpdate}
			${Echo} "ECP Step: RUH-OH! manual intervention required for ECP to work, but regular SSO operations should be ok."
				
        else
			${Echo} "ECP Step: web.xml validates via xmllint, good to proceed."
  
        fi
		${Echo} "ECP Step: Proceeding to rebuilding the war and deploying"
 		/opt/shibboleth-idp/bin/build.sh -Didp.target.dir=/opt/shibboleth-idp


}

enableECP ()

{

	# Based off of: https://wiki.shibboleth.net/confluence/display/IDP30/ECPConfiguration


	if [ "${ECPEnabled}" = "y" ]; then
	
		${Echo} "ECP Enabled is yes, processing ECP steps"


		${Echo} "ECP Step: Adding in JAAS connector in idp.home/conf/authn/jaas.config"
		jaasConfigFile="/opt/shibboleth-idp/conf/authn/jaas.config"
		
		ldapUserFilter="${attr_filter}={user}"

		cat ${Spath}/${prep}/jaas.config.template \
			| sed -re "s#LdApUrI#${ldapurl}#;s/LdApBaSeDn/${ldapbasedn}/;s/SuBsEaRcH/${subsearch}/;s/LdApCrEdS/${ldapbinddn}/;s/LdApPaSsWoRd/${ldappass}/;s/LdApUsErFiLtEr/${ldapUserFilter}/;s/LdApSsL/${ldapSSL}/;s/LdApTlS/${ldapStartTLS}/" \
			> ${jaasConfigFile}

		${Echo} "ECP Step: ensure jetty:jetty owns idp.home/conf/authn/jaas.config"
		chown jetty:jetty ${jaasConfigFile}


		enableECPUpdateIdPWebXML

	else
				${Echo} "ECP Enabled is disabled, skipping  idp.home/conf/authn/jaas.config processing"

	fi


}

configShibbolethSSLForLDAPJavaKeystore()

{

# 	Fetch certificates from LDAP servers
	lcnt=1
	capture=0
	ldapCert="ldapcert.pem"
	${Echo} 'Fetching and installing certificates from LDAP server(s)'
	for i in `${Echo} ${ldapserver}`; do
		#Get certificate info
		${Echo} "QUIT" | openssl s_client -showcerts -connect ${i}:636 > ${certpath}${i}.raw 2>&1
		files="`${Echo} ${files}` ${certpath}${i}.raw"

		for j in `cat ${certpath}${i}.raw | sed -re 's/\ /\*\*\*/g'`; do
			n=`${Echo} ${j} | sed -re 's/\*\*\*/\ /g'`
			if [ ! -z "`${Echo} ${n} | grep 'BEGIN CERTIFICATE'`" ]; then
				capture=1
				if [ -s "${certpath}${ldapCert}.${lcnt}" ]; then
					lcnt=`expr ${lcnt} + 1`
				fi
			fi
			if [ ${capture} = 1 ]; then
				${Echo} ${n} >> ${certpath}${ldapCert}.${lcnt}
			fi
			if [ ! -z "`${Echo} ${n} | grep 'END CERTIFICATE'`" ]; then
				capture=0
			fi
		done
	done

	numLDAPCertificateFiles=0
	minRequiredLDAPCertificateFiles=1

	for i in `ls ${certpath}${ldapCert}.*`; do

		numLDAPCertificateFiles=$[$numLDAPCertificateFiles +1]
		md5finger=`${keytool} -printcert -file ${i} | grep MD5 | cut -d: -f2- | sed -re 's/\s+//g'`
		test=`${keytool} -list -keystore ${javaCAcerts} -storepass changeit | grep ${md5finger}`
		subject=`openssl x509 -subject -noout -in ${i} | awk -F= '{print $NF}'`
		if [ -z "${test}" ]; then
			${keytool} -import -noprompt -alias "${subject}" -file ${i} -keystore ${javaCAcerts} -storepass changeit >> ${statusFile} 2>&1
		fi
		files="`${Echo} ${files}` ${i}"
	done

	# note the numerical comparison of 
	if [ "$numLDAPCertificateFiles" -ge "$minRequiredLDAPCertificateFiles" ]; then

		${Echo} "Successfully fetched LDAP SSL certificate(s) fetch from LDAP directory. Number loaded: ${numLDAPCertificateFiles} into this keystore ${javaCAcerts}"
		

	else
		${Echo} "***SEVERE ERROR*** \n\nAutomatic LDAP SSL certificate fetch from LDAP directory failed!"
		${Echo} " As a result, the Shibboleth IdP will not connect properly.\nPlease ensure the provided FQDN (NOT IP ADDRESS) is resolvable and pingable before starting again"
		${Echo} "\n\nCleaning up and exiting"
		
		cleanBadInstall
		exit
		# Note for dev: if this was called prior to MySQL installation, it may be possible to just run again without doing VM Image restore

	fi



}

configContainerSSLServerKey()

{

        #set up ssl store
        if [ ! -s "${certpath}server.key" ]; then
                ${Echo} "Generating SSL key and certificate request"
                openssl genrsa -out ${certpath}server.key 2048 2>/dev/null
                openssl req -new -key ${certpath}server.key -out ${certREQ} -config ${Spath}/files/openssl.cnf -subj "/CN=${certCN}/O=${certOrg}/C=${certC}"
        fi
        if [ "${selfsigned}" = "n" ]; then
                ${Echo} "Put the certificate from TCS in the file: ${certpath}server.crt" >> ${messages}
                ${Echo} "Run: openssl pkcs12 -export -in ${certpath}server.crt -inkey ${certpath}server.key -out ${httpsP12} -name container -passout pass:${httpspass}" >> ${messages}
        else
                openssl x509 -req -days 365 -in ${certREQ} -signkey ${certpath}server.key -out ${certpath}server.crt
                if [ ! -d "/opt/shibboleth-idp/credentials/" ]; then
                        mkdir /opt/shibboleth-idp/credentials/
                fi

                ${Echo} "Self-signed webserver cert/key generated and placed in PKCS12 format in ${httpsP12} for port 443 usage"
                openssl pkcs12 -export -in ${certpath}server.crt -inkey ${certpath}server.key -out ${httpsP12} -name container -passout pass:${httpspass}
        
    			${Echo} "Loading self-signed webserver cert: ${certpath}server.crt into ${javaCAcerts} to permit TLS port 443 connections"

				svrSubject=`openssl x509 -subject -noout -in ${certpath}server.crt | awk -F= '{print $NF}'`
                ${keytool} -import -noprompt -alias "${svrSubject}" -file ${certpath}server.crt -keystore ${javaCAcerts} -storepass changeit >> ${statusFile} 2>&1

        fi
}




configShibbolethFederationValidationKey ()

{

	${fetchCmd} ${idpPath}/credentials/md-signer.crt http://md.swamid.se/md/md-signer.crt
	cFinger=`openssl x509 -noout -fingerprint -sha1 -in ${idpPath}/credentials/md-signer.crt | cut -d\= -f2`
	cCnt=1
	while [ "${cFinger}" != "${mdSignerFinger}" -a "${cCnt}" -le 10 ]; do
		${fetchCmd} ${idpPath}/credentials/md-signer.crt http://md.swamid.se/md/md-signer.crt
		cFinger=`openssl x509 -noout -fingerprint -sha1 -in ${idpPath}/credentials/md-signer.crt | cut -d\= -f2`
		cCnt=`expr ${cCnt} + 1`
	done
	if [ "${cFinger}" != "${mdSignerFinger}" ]; then
		 ${Echo} "Fingerprint error on md-signer.crt!\nGet ther certificate from http://md.swamid.se/md/md-signer.crt and verify it, then place it in the file: ${idpPath}/credentials/md-signer.crt" >> ${messages}
	fi

}

updateMachineTime ()
{
	${Echo} "Updating time from: ${ntpserver}"
	/usr/sbin/ntpdate ${ntpserver} > /dev/null 2>&1

# 	add crontab entry for ntpdate
	test=`crontab -l 2>/dev/null | grep "${ntpserver}" | grep ntpdate`
	if [ -z "${test}" ]; then
		${Echo} "Adding crontab entry for ntpdate"
		CRONTAB=`crontab -l 2>/dev/null | sed -re 's/^$//'`
		if [ ! -z "${CRONTAB}" ]; then
			CRONTAB="${CRONTAB}\n"
		fi
		${Echo} "${CRONTAB}*/5 *  *   *   *     /usr/sbin/ntpdate ${ntpserver} > /dev/null 2>&1" | crontab
	fi
}

updateMachineHealthCrontab ()
{


${Echo} "Installing and adding daily crontab health checks"

	# make sure directory is in place
	${Echo} "Creating IdP Installer installation in ${idpInstallerBase}"
	idpInstallerBin="${idpInstallerBase}/bin"
	dailyTasks="${idpInstallerBin}/dailytasks.sh"
	

	${Echo} "adding dailytasks.sh to ${idpInstallerBin}"
	# note that this file is not federation specific, but generic 
	# 
	cp ${Spath}/files/dailytasks.sh.template ${dailyTasks}
	chmod ugo+rx ${dailyTasks}


	${Echo} "Preparing Crontab installation"
	
	test=`crontab -l 2>/dev/null | grep dailytasks`
	if [ -z "${test}" ]; then
		${Echo} "Adding crontab entry for dailytasks.sh "
		CRONTAB=`crontab -l 2>/dev/null | sed -re 's/^$//'`
		if [ ! -z "${CRONTAB}" ]; then
			CRONTAB="${CRONTAB}\n"
		fi
		${Echo} "${CRONTAB}0 23  *   *   *     ${dailyTasks} > /dev/null 2>&1" | crontab
	fi
		# fetch crontab again to show it
		CRONTAB=`crontab -l 2>/dev/null | sed -re 's/^$//'`
	
${Echo} "Crontab work complete, current crontab: ${CRONTAB} "

}


cleanupFilesRoutine ()
{

if [ "${cleanUp}" -eq 1 ]; then
# 	remove configs with templates
	for i in ${files}; do
		rm ${i}
	done
else
	${Echo} "Files created by script"
	for i in ${files}; do
		${Echo} ${i}
	done
fi

}
notifyUserBeforeExit()
{

	${Echo} "======================================"
	${Echo} "Install processing complete\n\n"

	if [ "${selfsigned}" = "n" ]; then
		cat ${certREQ}
		${Echo} "Looks like you have chosen to use use a commercial certificate for Shibboleth"
		${Echo} "Here is the certificate request you need to request a certificate from a commercial provider"
		${Echo} "Or replace the cert files in ${certpath}"
		${Echo} "\nNOTE!!! the keystore for https is a PKCS12 store\n"
	fi
	${Echo} ""
	${Echo} "If you installed Shibboleth, the default installation for Shibboleth is done.\n"
	${Echo} "To test it, register at testshib.org and register this idp and run a logon test."
	${Echo} "Certificate for idp metadata is in the file: /opt/shibboleth-idp/credentials/idp.crt"

if [ "${type}" = "ldap" ]; then
	${Echo} "\n"
	${Echo} "Looks like you have chosen to use ldap for Shibboleth single sign on."
	${Echo} "Please read this to customize the logon page: https://wiki.shibboleth.net/confluence/display/SHIB2/IdPAuthUserPassLoginPage"
fi

	${Echo} "Processing complete. You may want to reboot to ensure all services start up as expected.\nExiting.\n"


}



showAndCleanupMessagesFile ()

{

if [ -s "${messages}" ]; then
	cat ${messages}
	rm ${messages}
fi

}


askForSaveConfigToLocalDisk ()
{

cAns=$(askYesNo "Save config" "Do you want to save theese config values?\n\nIf you save theese values the current config file will be ovverwritten.\n NOTE: No passwords will be saved.")

	if [ "${cAns}" = "y" ]; then
		writeConfigFile
	fi

	if [ "${GUIen}" = "y" ]; then
		${whiptailBin} --backtitle "${my_ctl_federation} IDP Deployer" --title "Confirm" --scrolltext --clear --textbox ${downloadPath}/confirm.tx 20 75 3>&1 1>&2 2>&3
	else
		cat ${downloadPath}/confirm.tx
	fi
	cAns=$(askYesNo "Confirm" "Do you want to install this IDP with theese options?" "no")

	rm ${downloadPath}/confirm.tx
	if [ "${cAns}" = "n" ]; then
		exit
	fi

}

performStepsForShibbolethUpgradeIfRequired ()

{

if [ "${upgrade}" -eq 1 ]; then

${Echo} "Previous installation found, performing upgrade."

	eval ${distCmd1} &> >(tee -a ${statusFile})
	cd /opt
	currentShib=`ls -l /opt/${shibDir} | awk '{print $NF}'`
	currentVer=`${Echo} ${currentShib} | awk -F\- '{print $NF}'`
	if [ "${currentVer}" = "${shibVer}" ]; then
		mv ${currentShib} ${currentShib}.${ts}
	fi

	if [ ! -f "${downloadPath}/${shibDir}-${shibVer}.tar.gz" ]; then
		fetchAndUnzipShibbolethIdP
	fi
	tar xzf ${downloadPath}/${shibDir}-${shibVer}.tar.gz -C /opt
	chmod -R 755 /opt/${shibDir}-${shibVer}

	# Backup previous V2 environment
        #tar zcfP ${bupFile} --remove-files /opt/shibboleth-idp
        service tomcat6 stop

	if [ ! -d /opt/bak ]; then
		cp -ar /opt/shibboleth-idp /opt/bak 2>/dev/null
	fi

        rm -rf /opt/shibboleth-idp

	unlink /opt/${shibDir}
	ln -s /opt/${shibDir}-${shibVer} /opt/${shibDir}

	if [ -d "/opt/cas-client-${casVer}" ]; then
		installCasClientIfEnabled
	fi

	setJavaHome
else
	${Echo} "This is a fresh Shibboleth Install"


fi


}

jettySetupSetDefaults ()
{

 ${Echo} "jettySetup:jettySetupSetDefaults: Adding file /etc/default/jetty for java home and options"


        # ensure Jetty has proper startup environment for Java for all platforms
        jettyDefaults="/etc/default/jetty"
        jEnvString="export JAVA_HOME=${JAVA_HOME}"
 		jEnvPathString="export PATH=${PATH}:${JAVA_HOME}/bin"
 		jEnvJavaDefOpts='export JAVA_OPTIONS="-Didp.home=/opt/shibboleth-idp -Xmx1024M"'
 		# suppressed -XX:+PrintGCDetails because it was too noisy

		${Echo} "${jEnvString}" >> ${jettyDefaults}
       	${Echo} "${jEnvPathString}" >> ${jettyDefaults}
       	${Echo} "${jEnvJavaDefOpts}" >> ${jettyDefaults}
       	
        ${Echo} "jettySetup:jettySetupSetDefaults: Updated ${jettyDefaults} to add JAVA_HOME: ${JAVA_HOME} and java to PATH"
        ${Echo} "jettySetup:jettySetupSetDefaults: Done adding file /etc/default/jetty for java home and options"
 
}
jettySetupManageCiphers() {

      ${Echo} "jettySetup:jettySetupManageCiphers: Starting to fine tuning ciphers from /opt/jetty/jetty-base/etc/jetty.xml "


		removeCiphers="TLS_RSA_WITH_AES_128_GCM_SHA256 TLS_RSA_WITH_AES_128_CBC_SHA256 TLS_RSA_WITH_AES_128_CBC_SHA TLS_RSA_WITH_AES_256_CBC_SHA SSL_RSA_WITH_3DES_EDE_CBC_SHA"
	for cipher in $removeCiphers; do
		sed -i "/${cipher}/d" /opt/jetty/jetty-base/etc/jetty.xml
	done

	 ${Echo} "jettySetup:jettySetupManageCiphers: Ending fine tuning ciphers from /opt/jetty/jetty-base/etc/jetty.xml "


}

jettySetupPrepareBase()
{
	   ${Echo} "Preparing jetty-base from: ${jettyBasePath} to /opt/jetty/"

    	cp -r ${jettyBasePath} /opt/jetty/

    	# regardless of jetty version, ensure there's a log and tmp directory like there was in Shib 3.1.2
    	# if it is idp v3.1.2, these steps are redundant and the chown on the files will happen in the setup

        mkdir -p /opt/jetty/jetty-base/logs
        mkdir -p /opt/jetty/jetty-base/tmp
        
        
    

}

jettySetupEnableStartOnBoot ()
{

	${Echo} "$FUNCNAME: Enabling jetty startup on boot" >> ${statusFile} 2>&1

	idpInstallerBin="${idpInstallerBase}/bin"
	
	
	${Echo} "$FUNCNAME: Creating Jetty User " >> ${statusFile} 2>&1

	useradd -d /opt/jetty -s /bin/bash -U jetty

	${Echo} "$FUNCNAME: Creating symlink for legacy service start/stop  " >> ${statusFile} 2>&1
        ln -s /opt/jetty/bin/jetty.sh /etc/init.d/jetty

	${Echo} "$FUNCNAME: Enabling automatic Jetty Startup " >> ${statusFile} 2>&1

        if [ "${dist}" == "ubuntu" ]; then
		${Echo} "$FUNCNAME: Detected ubuntu service model, using update-rc.d to enable jetty" >> ${statusFile} 2>&1
                update-rc.d jetty defaults
	elif [ "${dist}" == "sles" ]; then
		${Echo} "$FUNCNAME: Detected suse service model, using chkconfig to enable jetty" >> ${statusFile} 2>&1
		chkconfig --add jetty
		chkconfig jetty on
	else
		if [ ${redhatDist} = "7"  ]; then

			${Echo} "$FUNCNAME: Detected newer service model, using systemd to enable jetty" >> ${statusFile} 2>&1
	
			${Echo} "$FUNCNAME: copying over systemd jetty.service file" >> ${statusFile} 2>&1
			cp "${filesPath}/jetty.service.template" "${idpInstallerBin}/${idpIFilejettySystemdService}"

			${Echo} "$FUNCNAME: copying IdP-Installer jetty.service file to systemd dir " >> ${statusFile} 2>&1
			cp  "${idpInstallerBin}/${idpIFilejettySystemdService}" "${systemdHome}/${idpIFilejettySystemdService}"

			systemctl daemon-reload
			systemctl enable jetty.service

		else
			${Echo} "$FUNCNAME: Detected classic service model, using chkconfig to enable jetty" >> ${statusFile} 2>&1
			chkconfig jetty on
			
		fi
        fi



}
jettySetup() {

        #Installing a specific version of Jetty

        # As of Aug 11, 2015, Jetty 9.3.x has not quieted down from having changes done.
        # to mitigate issues: ( https://bugs.eclipse.org/bugs/show_bug.cgi?id=473321 )
        #
        # This Jetty setup will use a specific Jetty version placed in the ~/downloads directory
        # Also be warned that the jetty site migrates links from the current jettyBaseURL to an archive
        # at random times.

		# Variable 'jetty9File' now originates from script.messages.sh to make it easier to 
		# manage versions
		
        #jetty9File='jetty-distribution-9.2.13.v20150730.tar.gz'

		# Ability to override version:
		# To override the downloads folder containing the binary: jetty-distribution-9.2.13.v20150730.tar.gz
        # uncomment the below variable assignment to dynamically fetch it instead:
        # jettyBaseURL is defined in script.messages.sh

        #jetty9File=`curl -s ${jettyBaseURL} | grep -oP "(?>)jetty-distribution.*tar.gz(?=&)"`
        
        ${Echo} "$FUNCNAME: Starting Jetty servlet container setup" >> ${statusFile} 2>&1 

		jetty9Path=`basename ${jetty9File}  .tar.gz`
		jetty9URL="${jettyBaseURL}${jetty9File}"

		${Echo} "Preparing to install Jetty webserver ${jetty9File}"

        if [ ! -s "${downloadPath}/${jetty9File}" ]; then
                ${Echo} "Fetching Jetty from ${jetty9URL}"
                ${fetchCmd} ${downloadPath}/${jetty9File} "{$jetty9URL}"
        else
        	${Echo} "Skipping Jetty download, it exists here: ${downloadPath}/${jetty9File}"
                	
        fi

 		${Echo} "$FUNCNAME: Manipulating Jetty config for our deployment" >> ${statusFile} 2>&1 
        cd /opt
        tar zxf ${downloadPath}/${jetty9File} >> ${statusFile} 2>&1
        
 		${Echo} "$FUNCNAME: adding symlink for /opt/jetty" >> ${statusFile} 2>&1 
        ln -s /opt/${jetty9Path} /opt/jetty

		jettySetupPrepareBase

 		${Echo} "$FUNCNAME: manipulating jetty.sh for proper settings" >> ${statusFile} 2>&1 

        sed -i 's/\# JETTY_HOME/JETTY_HOME=\/opt\/jetty/g' /opt/jetty/bin/jetty.sh
        sed -i 's/\# JETTY_USER/JETTY_USER=jetty/g' /opt/jetty/bin/jetty.sh
        sed -i 's/\# JETTY_BASE/JETTY_BASE=\/opt\/jetty\/jetty-base/g' /opt/jetty/bin/jetty.sh
        sed -i 's/TMPDIR:-\/tmp/TMPDIR:-\/opt\/jetty\/jetty-base\/tmp/g' /opt/jetty/bin/jetty.sh

 		${Echo} "$FUNCNAME: manipulating jetty idp.ini for passphrases in jetty/jetty-base" >> ${statusFile} 2>&1 
        cat ${filesPath}/idp.ini | sed -re "s#ShIbBKeyPaSs#${pass}#;s#HtTpSkEyPaSs#${httpspass}#" > /opt/jetty/jetty-base/start.d/idp.ini
        
        jettySetupEnableStartOnBoot


		${Echo} "$FUNCNAME: applying ownership on key directories" >> ${statusFile} 2>&1 
        chown -R jetty:jetty /opt/jetty/ 
        chown -R jetty:jetty /opt/shibboleth-idp/

        jettySetupSetDefaults
        
        jettySetupManageCiphers

      ${Echo} "jettySetup: Ending Jetty servlet container setup"


}

applyIptablesSettings ()

{
	${Echo} "$FUNCNAME: applying firewall rules and saving them to redirect 443 to 7443 " >> ${statusFile} 2>&1
        if [ "${dist}" == "sles" ]; then
		SuSEfirewall2 open EXT TCP 443 7443 8443

		slesRedir=`grep "^FW_REDIRECT=" /etc/sysconfig/SuSEfirewall2 | cut -d\" -f2 | sed s/\n//`
		slesStr="0/0,0/0,tcp,443,8443"
		if [ ! -z "${slesRedir}" ]; then
			slesRedir="${slesRedir} "
		fi
		if [ -z "`echo $slesRedir | grep ${slesStr}`" ]; then
			slesRedir="${slesRedir}${slesStr}"
			echo "FW_REDIRECT=\"${slesRedir}\"" >> /etc/sysconfig/SuSEfirewall2
		fi

		SuSEfirewall2
	else
		iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
		iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 7443 -j ACCEPT
		iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 8443 -j ACCEPT
		iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 7443
		iptables -t nat -I OUTPUT -p tcp -o lo --dport 443 -j REDIRECT --to-ports 7443
	fi

        if [ "${dist}" == "centos" -o "${dist}" == "redhat" ]; then
		iptables-save > /etc/sysconfig/iptables
		if [ ${redhatDist} = "7"  ]; then
			${Echo} "$FUNCNAME: ensuring iptables is started upon reboot " >> ${statusFile} 2>&1 

			systemctl enable iptables
		fi
	elif [ "${dist}" == "ubuntu" ]; then
	 	iptables-save > /etc/iptables/rules.v4
	fi

        if [ "${dist}" != "sles" ]; then
		service iptables restart
	fi

}

restartJettyService ()

{

	${Echo} "Restarting Jetty to ensure everything has taken effect"

	if [ -f /var/run/jetty.pid ]; then
		service jetty stop
	fi
	service jetty start

}

applyFTICKS ()
{
		# Logic:
		#		If there is a federation specific setting for the loghost, use it, otherwise overlay configuraiton files

	

	# A. create salt automatically
	if [ -z "${fticksSalt}" ]; then
		fticksSalt=`openssl rand -base64 36 2>/dev/null`
	fi

	# B. overlay new audit.xml, logback.xml so bean and technique is in place (make backup first)
	overlayFiles="audit.xml logback.xml"
	for i in ${overlayFiles}; do
		cp /opt/shibboleth-idp/conf/${i} /opt/shibboleth-idp/conf/${i}.${fileBkpPostfix}
		cp ${Spath}/files/${my_ctl_federation}/${i}.template /opt/shibboleth-idp/conf/${i}
	done

	# C. place 3 lines at end of idp.properties:
	# 		idp.fticks.federation=CAF
	# 		idp.fticks.salt=salt123salt
	# 		idp.fticks.loghost=localhost unless otherwise specified by existence of fticks-loghost.txt in Federation directory

	my_fticks_loghost_file="${Spath}/files/${my_ctl_federation}/fticks-loghost.txt"
	my_fticks_loghost_value="localhost"

	 if [ -s "${my_fticks_loghost_file}" ]; then
                ${Echo} "applyFTICKS detected a loghost file to use"
                my_fticks_loghost_value=`cat ${my_fticks_loghost_file}`

        else
				${Echo} "applyFTICKS did not detect an override to loghost"
        fi

				${Echo} "applyFTICKS loghost: ${my_fticks_loghost_value}"


	cp /opt/shibboleth-idp/conf/idp.properties /opt/shibboleth-idp/conf/idp.properties.${fileBkpPostfix}
	echo "idp.fticks.federation=${my_ctl_federation}" >> /opt/shibboleth-idp/conf/idp.properties
	echo "idp.fticks.salt=${fticksSalt}" >> /opt/shibboleth-idp/conf/idp.properties
	echo "idp.fticks.loghost=${my_fticks_loghost_value}" >> /opt/shibboleth-idp/conf/idp.properties

	${Echo} "applyFTICKS updates completed"
}


applyNameIDC14Settings ()

{

# https://wiki.shibboleth.net/confluence/display/IDP30/PersistentNameIDGenerationConfiguration
# C14= Canonicalization BTW :)
# Enables the saml-nameid.properties file for persistent identifiers and configures xml file for use
# 
	local failExt="proposedUpdate"
	local tgtFile="${idpConfPath}/saml-nameid.properties"
	local tgtFileBkp="${tgtFile}.${fileBkpPostfix}"
	${Echo} "Applying NameID settings to ${tgtFile}" >> ${statusFile} 2>&1

# Make a backup of our file
	cp "${tgtFile}" "${tgtFileBkp}"

# The following uncomments certain lines that ship with the file:
# lines 8,9 activate the generator 
${Echo} "Applying NameID settings:${tgtFile}: activate the nameID generator" >> ${statusFile} 2>&1

	sed -i  "/idp.nameid.saml2.legacyGenerator/s/^#//" "${tgtFile}"
	sed -i  "/idp.nameid.saml1.legacyGenerator/s/^#//" "${tgtFile}"

#lines 22 and 26 respectively which we'll adjust in a moment
${Echo} "Applying NameID settings:${tgtFile}: uncommenting sourceAttribute statement" >> ${statusFile} 2>&1

	sed -i  "/idp.persistentId.sourceAttribute/s/^#//" "${tgtFile}"

# this replaces the string for the attribute filter (uid/sAMAccountName) as the key element for the hash
${Echo} "Applying NameID settings:${tgtFile}: replaces the string for the attribute filter with ${attr_filter}" >> ${statusFile} 2>&1

	sed -i  "s/changethistosomethingreal/${attr_filter}/" "${tgtFile}"	

# lines 26: uncomment the salt and replace it with the right thing
# note that this is the same salt as the ePTId
${Echo} "Applying NameID settings:${tgtFile}: uncomment and set the salt for hashing the value" >> ${statusFile} 2>&1

	sed -i  "/idp.persistentId.salt/s/^#//" "${tgtFile}"
	sed -i  "s/changethistosomethingrandom/${esalt}/" "${tgtFile}"	

# line 31. Uncomment it to use the 'MyPersistentIdStore' it references elsewhere
${Echo} "Applying NameID settings:${tgtFile}: uncommenting use of MyPersistentIdStore for DB " >> ${statusFile} 2>&1

	sed -i  "/idp.persistentId.store/s/^#//" "${tgtFile}"

${Echo} "Applying NameID settings:${tgtFile}: appending to file settings using StoredPersistentIdGenerator so DB is used to generate IDs" >> ${statusFile} 2>&1

	${Echo} "# Appended by Idp-Installer to use the proper generator" >> "${tgtFile}"
	${Echo} "idp.persistentId.generator = shibboleth.StoredPersistentIdGenerator" >> "${tgtFile}"


	local tgtFilexml="${idpConfPath}/saml-nameid.xml"
	local tgtFilexmlBkp="${tgtFilexml}.${fileBkpPostfix}"

	local samlnameidTemplate="${Spath}/prep/shibboleth/conf/saml-nameid.xml.template"

${Echo} "Applying NameID settings:${tgtFilexml}: making backup of file" >> ${statusFile} 2>&1

# Make a backup of our file
	cp "${tgtFilexml}" "${tgtFilexmlBkp}"


# perform overlay of our template with necessary substitutions
${Echo} "Applying NameID settings:${tgtFilexml}: perform our overlay from template file onto ${tgtFilexml}" >> ${statusFile} 2>&1

	cat ${samlnameidTemplate} | sed -re "s#SqLpAsSwOrD#${epass}#" > "${tgtFilexml}"

${Echo} "Applying NameID settings:${tgtFilexml}: verify successfull update" >> ${statusFile} 2>&1

# verify that the updates proceeded at least to a non zero byte file result
if [[ -s "${tgtFile}" && -s "${tgtFilexml}" ]]; then
	${Echo} "${tgtFile} update complete" >> ${statusFile} 2>&1
else
	${Echo} "FAILED UPDATE: Issue detected with nameID files. The update to ${tgtFile} and ${tgtFilexml} are rolling back to originals" >> ${statusFile} 2>&1
	${Echo} "Proposed updates for saml-nameid will be saved in the same directory with a ${failExt} extension" >> ${statusFile} 2>&1

	# copy bad copies for latest investigation
	cp "${tgtFilexml}" "${tgtFilexml}.${failExt}"
	cp "${tgtFile}" "${tgtFile}.${failExt}"

	# revert back to original for both 
	cp "${tgtFilexmlBkp}" "${tgtFilexml}"
	cp "${tgtFileBkp}" "${tgtFile}"

	${Echo} "FAILED UPDATE: Files rolled back, installation will still proceed, but check installer status.log and IdP idp-process.log, idp-warn.log for issues post startup" >> ${statusFile} 2>&1

fi
${Echo} "Applying NameID settings:${tgtFilexml}: verify process complete" >> ${statusFile} 2>&1




${Echo} "Applying NameID settings complete" >> ${statusFile} 2>&1
	
}

prepareDatabase ()
{
	${Echo} "Preparing Mysql DB for storing identifiers"

	# relies upon epass from script.messages.sh for the sqlpassword for userid 'shibboleth'

	 	# grant sql access for shibboleth
		# esalt generation moved to script.messages.sh to be used in more locations than just here
		

	cat ${Spath}/xml/${my_ctl_federation}/eptid.sql.template | sed -re "s#SqLpAsSwOrD#${epass}#" > ${Spath}/xml/${my_ctl_federation}/eptid.sql
		files="`${Echo} ${files}` ${Spath}/xml/${my_ctl_federation}/eptid.sql"

		${Echo} "Create MySQL database and shibboleth user."
		mysql -uroot -p"${mysqlPass}" < ${Spath}/xml/${my_ctl_federation}/eptid.sql
		retval=$?
		if [ "${retval}" -ne 0 ]; then
			${Echo} "Failed to create EPTID database, take a look in the file '${Spath}/xml/${my_ctl_federation}/eptid.sql.template' and corect the issue." >> ${messages}
			${Echo} "Password for the database user can be found in: /opt/shibboleth-idp/conf/attribute-resolver.xml" >> ${messages}
		fi

}



applyGlobalXmlDbSettingsDependancies ()

{
	${Echo} "$FUNCNAME: adding libraries in edit-webapp/WEB-INF/lib supporting database connectivity" >> ${statusFile} 2>&1

	local commonsDbcp2Jar="commons-dbcp2-${commonsDbcp2Ver}.jar"
	local commonsPool2Jar="commons-pool2-${commonsPool2Ver}.jar"
	
	cp ${downloadPath}/${commonsDbcp2Jar} "${idpEditWebappLibDir}"
	cp ${downloadPath}/${commonsPool2Jar} "${idpEditWebappLibDir}"

	${Echo} "$FUNCNAME: applying jetty user and group ownership to  libraries in edit-webapp/WEB-INF/lib " >> ${statusFile} 2>&1
		
	chown -R jetty:jetty "${idpEditWebappLibDir}"

	${Echo} "$FUNCNAME: completed" >> ${statusFile} 2>&1

}

applyGlobalXmlDbSettings ()

{

	local failExt="proposedUpdate"
	local tgtFilexml="${idpConfPath}/global.xml"
	local tgtFilexmlBkp="${tgtFilexml}.${fileBkpPostfix}"

	local TemplateXml="${Spath}/prep/shibboleth/conf/global.xml.template"

${Echo} "$FUNCNAME:Working on ${tgtFilexml}: making backup of file" >> ${statusFile} 2>&1

# Make a backup of our file
	cp "${tgtFilexml}" "${tgtFilexmlBkp}"


# perform overlay of our template with necessary substitutions
${Echo} "Working on ${tgtFilexml}: perform our overlay from template file onto ${tgtFilexml}" >> ${statusFile} 2>&1

	cat ${TemplateXml} | sed -re "s#SqLpAsSwOrD#${epass}#" > "${tgtFilexml}"

${Echo} "Working on ${tgtFilexml}: verify successfull update" >> ${statusFile} 2>&1

# verify that the updates proceeded at least to a non zero byte file result
if [ -s "${tgtFilexml}" ]; then
	${Echo} "Working on ${tgtFilexml}: verification successful. Update completed." >> ${statusFile} 2>&1
else
	${Echo} "FAILED UPDATE: Issue detected with ${tgtFilexml} file. The update to ${tgtFilexml} are rolling back to originals" >> ${statusFile} 2>&1
	${Echo} "Proposed updates will be saved in the same directory with a ${failExt} extension" >> ${statusFile} 2>&1

	# copy bad copies for latest investigation
	cp "${tgtFilexml}" "${tgtFilexml}.${failExt}"

	# revert back to original for both 
	cp "${tgtFilexmlBkp}" "${tgtFilexml}"

	${Echo} "FAILED UPDATE: Files rolled back, installation will still proceed, but check installer status.log and IdP idp-process.log, idp-warn.log for issues post startup" >> ${statusFile} 2>&1

fi

${Echo} "Working on ${tgtFilexml}: verify process complete" >> ${statusFile} 2>&1

applyGlobalXmlDbSettingsDependancies


${Echo} "$FUNCNAME: Work on ${tgtFilexml} and related dependancies completed" >> ${statusFile} 2>&1


}


applyEptidSettings ()

{
	${Echo} "$FUNCNAME: Applying EPTID settings to attribute-resolver.xml" >> ${statusFile} 2>&1

	${Echo} "$FUNCNAME: Applying EPTID settings to attribute-resolver.xml" >> ${statusFile} 2>&1

	 	cat ${Spath}/xml/${my_ctl_federation}/eptid.add.attrCon.template \
        | sed -re "s#SqLpAsSwOrD#${epass}#;s#Large_Random_Salt_Value#${esalt}#" \
               > ${Spath}/xml/${my_ctl_federation}/eptid.add.attrCon
       files="`${Echo} ${files}` ${Spath}/xml/${my_ctl_federation}/eptid.add.attrCon"
       
      #REVIEW1 repStr='<!-- EPTID RESOLVER PLACEHOLDER -->'
      #REVIEW1 sed -i -e "/^${repStr}$/r ${Spath}/xml/${my_ctl_federation}/eptid.add.resolver" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-resolver.xml

       repStr='<!-- EPTID ATTRIBUTE CONNECTOR PLACEHOLDER -->'
       sed -i -e "/^${repStr}$/r ${Spath}/xml/${my_ctl_federation}/eptid.add.attrCon" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-resolver.xml

#REVIEW1       repStr='<!-- EPTID PRINCIPAL CONNECTOR PLACEHOLDER -->'
#REVIEW1       sed -i -e "/^${repStr}$/r ${Spath}/xml/${my_ctl_federation}/eptid.add.princCon" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-resolver.xml

	   repStr='<!-- EPTID FILTER PLACEHOLDER -->'
       sed -i -e "/^${repStr}$/r ${Spath}/xml/${my_ctl_federation}/eptid.add.filter" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-filter.xml
      
}
applyLDAPSettings ()
{
		${Echo} "Patching config files"


		repStr='<!-- LDAP CONNECTOR PLACEHOLDER -->'
        sed -i -e "/^${repStr}$/r ${Spath}/xml/${my_ctl_federation}/ldapconn.txt" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-resolver.xml


}

patchShibbolethConfigs ()

{

	# patch shibboleth config files
        ${Echo} "Patching config files"
        mv /opt/shibboleth-idp/conf/attribute-filter.xml /opt/shibboleth-idp/conf/attribute-filter.xml.dist

        ${Echo} "patchShibbolethConfigs:Overlaying attribute-filter.xml with federation defaults"

        cp ${Spath}/files/${my_ctl_federation}/attribute-filter.xml.template /opt/shibboleth-idp/conf/attribute-filter.xml
        chmod ugo+r /opt/shibboleth-idp/conf/attribute-filter.xml

        ${Echo} "patchShibbolethConfigs:Overlaying relying-filter.xml with federation trusts"
        cat ${Spath}/xml/${my_ctl_federation}/metadata-providers.xml > /opt/shibboleth-idp/conf/metadata-providers.xml
        cat ${Spath}/xml/${my_ctl_federation}/attribute-resolver.xml > /opt/shibboleth-idp/conf/attribute-resolver.xml
        cat ${Spath}/files/${my_ctl_federation}/relying-party.xml > /opt/shibboleth-idp/conf/relying-party.xml

	if [ "${consentEnabled}" = "n" ]; then
		sed -i 's#<bean parent="Shibboleth.SSO" p:postAuthenticationFlows="attribute-release" />#<bean parent="Shibboleth.SSO" />#;s#<bean parent="SAML2.SSO" p:postAuthenticationFlows="attribute-release" />#<bean parent="SAML2.SSO" />#' /opt/shibboleth-idp/conf/relying-party.xml
	fi

        if [ "${google}" != "n" ]; then
                repStr='<!-- PLACEHOLDER DO NOT REMOVE -->'
                sed -i -e "/^${repStr}$/r ${Spath}/xml/${my_ctl_federation}/google-filter.add" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-filter.xml
                cat ${Spath}/xml/${my_ctl_federation}/google-relay.diff.template | sed -re "s/IdPfQdN/${certCN}/" > ${Spath}/xml/${my_ctl_federation}/google-relay.diff
                files="`${Echo} ${files}` ${Spath}/xml/${my_ctl_federation}/google-relay.diff"
                patch /opt/shibboleth-idp/conf/relying-party.xml -i ${Spath}/xml/${my_ctl_federation}/google-relay.diff >> ${statusFile} 2>&1
                cat ${Spath}/xml/${my_ctl_federation}/google.xml | sed -re "s/GoOgLeDoMaIn/${googleDom}/" > /opt/shibboleth-idp/metadata/google.xml
        fi

        if [ "${fticks}" != "n" ]; then
              	# apply an enhanced application of the FTICKS functionality
				applyFTICKS
        fi

        	# This loads the necessary schema for the database to prepare for
        	#  eptid usage OR 
        	# applyingNameIDC14Settings

        	prepareDatabase

        	applyGlobalXmlDbSettings


        if [ "${eptid}" != "n" ]; then

        		applyEptidSettings
        fi

        applyLDAPSettings

        
	echo "applying chown "
	chmod o+r /opt/shibboleth-idp/conf/attribute-filter.xml

	applyNameIDC14Settings


}


performPostUpgradeSteps ()
{
        if [ "${upgrade}" -eq 1 ]; then
                cat /opt/bak/credentials/idp.crt > /opt/shibboleth-idp/credentials/idp-signing.crt
                cat /opt/bak/credentials/idp.key > /opt/shibboleth-idp/credentials/idp-signing.key
        fi

}

checkAndLoadBackupFile ()
{
	backFile=`ls ${Spath} | egrep "^idp-export-.+tar.gz"`
	if [ "x${backFile}" != "x" ]; then
		${Echo} "Found backup, extracting and load settings" >> ${statusFile} 2>&1
		mkdir ${Spath}/extract 2>/dev/null
		cd ${Spath}/extract
		tar zxf ${Spath}/${backFile}
		if [ -s "${Spath}/extract/opt/shibboleth-idp/conf/fticks-key.txt" ]; then
			fticksSalt=`cat ${Spath}/extract/opt/shibboleth-idp/conf/fticks-key.txt`
		fi
		. settingsToImport.sh
		cd ${Spath}
	else
		${Echo} "No backup found." >> ${statusFile} 2>&1
	fi
}


loadDatabaseDump ()
{
	if [ -s "${Spath}/extract/sql.dump" ]; then
		if [ "${ehost}" = "localhost" -o "${ehost}" = "127.0.0.1" ]; then
			if [ "${etype}" = "mysql" ]; then
				mysql -uroot -p"${mysqlPass}" -D ${eDB} < ${Spath}/extract/sql.dump
			fi
		else
			${Echo} "Database not on localhost, skipping database import." >> ${messages}
		fi
	fi
}


overwriteConfigFiles ()
{
# 	if [ -d "${Spath}/extract/opt/shibboleth-idp/conf" -a "x`ls ${Spath}/extract/opt/shibboleth-idp/conf`" != "x" ]; then
# 		for i in `ls ${Spath}/extract/opt/shibboleth-idp/conf/`; do
# 			mv ${Spath}/extract/opt/shibboleth-idp/conf/$i /opt/shibboleth-idp/conf
# 			chown jetty /opt/shibboleth-idp/conf/$i
# 		done
# 	fi
	if [ -d "${Spath}/extract/opt/shibboleth-idp/metadata" -a "x`ls ${Spath}/extract/opt/shibboleth-idp/metadata 2>/dev/null`" != "x" ]; then
		for i in `ls ${Spath}/extract/opt/shibboleth-idp/metadata/`; do
			mv ${Spath}/extract/opt/shibboleth-idp/metadata/$i /opt/shibboleth-idp/metadata
			chown jetty /opt/shibboleth-idp/metadata/$i
		done
	fi
}


overwriteKeystoreFiles ()
{
	if [ -d "${Spath}/extract/opt/shibboleth-idp/credentials" -a "x`ls ${Spath}/extract/opt/shibboleth-idp/credentials 2>/dev/null`" != "x" ]; then
		mv ${Spath}/extract/opt/shibboleth-idp/credentials/* /opt/shibboleth-idp/credentials
		chown jetty /opt/shibboleth-idp/credentials/*
	fi
	if [ -f "${Spath}/extract/${httpsP12}" ]; then
		mv ${Spath}/extract/${httpsP12} ${httpsP12}
		chown jetty ${httpsP12}
	fi
	if [ "x${keyFile}" != "x" -a -f "${Spath}/extract/${keyFile}" ]; then
		mv ${Spath}/extract/${keyFile} ${keyFile}
		chown jetty ${keyFile}
	fi
}

makeInstallerHome()

{
	${Echo} "$FUNCNAME: Creating IdP-Installer support directories in ${idpInstallerBase} " >> ${statusFile} 2>&1

	mkdir -p ${idpInstallerBase}
	mkdir -p ${idpInstallerBin}

}

invokeShibbolethInstallProcessJetty9 ()
{
	${Echo} "$FUNCNAME: Beginning core installation process " >> ${statusFile} 2>&1

    
	# check for installed IDP
	setVarUpgradeType

	setJavaHome

	makeInstallerHome

	# Override per federation
	performStepsForShibbolethUpgradeIfRequired

	# 	check for backup file and use it if available
	checkAndLoadBackupFile

	if [ "${installer_interactive}" = "y" ]
	then
		askForConfigurationData
		prepConfirmBox
		askForSaveConfigToLocalDisk
	fi

	notifyMessageDeployBeginning


	setVarPrepType
	setVarCertCN
	setVarIdPScope
	
	setJavaCACerts

	generatePasswordsForSubsystems

	patchFirewall

	

	[[ "${upgrade}" -ne 1 ]] && fetchAndUnzipShibbolethIdP

	configShibbolethXMLAttributeResolverForLDAP

	runShibbolethInstaller

        installEPTIDSupport

	installCasClientIfEnabled

	createCertificatePathAndHome

	# Override per federation
	installCertificates

	# process certificates for LDAP connections
	fetchLDAPCertificates
	configShibbolethSSLForLDAPJavaKeystore

	# Override per federation
	configContainerSSLServerKey

	# Override per federation
	configShibbolethFederationValidationKey

	jettySetup

	patchShibbolethConfigs

	performPostUpgradeSteps

	enableECP

	enableStatusMonitoring

	updateMachineTime

	updateMachineHealthCrontab

# 	install files from backup
	overwriteConfigFiles
	overwriteKeystoreFiles

# 	load the database dump if available
	loadDatabaseDump

	applyIptablesSettings

	restartJettyService

}


invokeShibbolethUpgradeProcess()
{
        if [ -a "/opt/${jetty9Path}/bin/jetty.sh" ]; then
                echo "Jetty detected as installed"
        else
                if [ ${dist} == "ubuntu" ]; then
                        apt-get -y remove --purge tomcat6 openjdk* default-jre java*
                elif [ ${dist} == "sles" ]; then
			zypper -n remove tomcat* openjdk* java*
                else
                        yum -y remove tomcat* java*
                fi
                cleanBadInstall "NotExit"
                fticks="y"
                eptid="n"
                invokeShibbolethInstallProcessJetty9
        fi
}

invokeShibbolethInstallProcess () ##Default
{

        invokeShibbolethInstallProcessJetty9

}

