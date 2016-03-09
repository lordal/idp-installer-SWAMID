#!/bin/bash
if [ "${USERNAME}" != "root" -a "${USER}" != "root" ]; then
	echo "Run as root!"
	exit
fi

Spath="$(cd "$(dirname "$0")" && pwd)"
if [ ! -z "`echo ${Spath} | grep \"/bin$\"`" ]; then
	Spath=`dirname ${Spath}`
fi

#git pull

. ${Spath}/files/script.messages.sh
. ${Spath}/files/script.bootstrap.functions.sh
setEcho
. ${Spath}/files/script.functions.sh
curJava=`java -version 2>&1 | grep "^java\ version" | cut -d\" -f2`

cd ${Spath}

if [ -z "${1}" ]; then
	if [ "${curJava}" = "${javaVer}" ]; then
		${Echo} ""
		${Echo} "You are trying to upgrade java to the same verion that is already in use by the system."
		${Echo} "To upgrade to a newer version either download the newest version of the IDP installer or supply the new version as an argument to this script."
		${Echo} "$0 ${javaBuildName}"
	else
		ans=$(askYesNo "Upgrade java" "Do you want to upgrade java to version ${javaBuildName}?")
		if [ -z "`${Echo} ${ans} | grep -i Y`" ]; then
			exit
		fi
		installOracleJava
	fi
else
	if [ -z "`${Echo} ${1} | grep -P \"\du\d+-b\d+\"`" ]; then
		${Echo} ""
		${Echo} "Invalid version information."
		${Echo} "Please use the format: ${javaBuildName}"
		exit
	fi

	javaBuildName=${1}
	javaName=`${Echo} ${javaBuildName} | cut -d- -f1`
	javaMajorVersion=`${Echo} ${javaBuildName} | cut -c1`
	javaVer="1.${javaMajorVersion}.0_`${Echo} ${javaName} | cut -du -f2`"

	if [ "${curJava}" = "${javaVer}" ]; then
		${Echo} ""
		${Echo} "You are trying to upgrade java to the same verion that is already in use by the system."
		exit
	fi

	installOracleJava
fi
