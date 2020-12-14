#!/bin/bash
readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(readlink -m $(dirname $0))
readonly ARGS="$@"

BackTitle="IDP manager"
idpBaseDir="/opt/shibboleth-idp"
URL=0
GUIen="y"
whipSize="13 75"
whipSizeLarge="20 75"
whiptailBin=`which whiptail 2>/dev/null`
if [[ ! -x "${whiptailBin}" ]]; then
	GUIen="n"
fi

setEcho() {
	local Echo=""
	if [[ -x "/bin/echo" ]]; then
		Echo="/bin/echo -e"
	elif [[ -x "`which printf 2>/dev/null`" ]]; then
		Echo="`which printf` %b\n"
	else
		Echo="echo"
	fi
	
	echo ${Echo}
}

readonly Echo=$(setEcho)

getHostPort() {
	local hostPort=""
	if [[ -s "/opt/jetty/jetty-base/start.d/idp.ini" ]]; then
		hostPort="`grep \"^jetty.ssl.port=\" /opt/jetty/jetty-base/start.d/idp.ini | cut -d= -f2-`"

		if [[ -z "${hostPort}" ]]; then
			${Echo} "Couldn't get a port from the configuration and can't continue.\nPlease script help."
			exit 1
		fi
	else
		${Echo} "Can't find dependancies, aborting.\nPlease see script help."
		exit 1
	fi
	
	${Echo} ${hostPort}
}

cmdline() {
	local arg=""
	for arg; do
		local delim=""
		case "$arg" in
		#translate --gnu-long-options to -g (short options)
		--url)         args="${args}-u ";;
		--base)        args="${args}-b ";;
		--port)           args="${args}-p ";;
		--help)           args="${args}-h ";;
		#pass through anything else
		*) [[ "${arg:0:1}" == "-" ]] || delim="\""
			args="${args}${delim}${arg}${delim} ";;
		esac
	done

	eval set -- $args

	while getopts "uhb:p:" OPTION
	do
		case $OPTION in
		u)
			readonly printURL=1
		;;
		h)
			usage
			exit 0
		;;
		b)
			readonly idpBaseDir="${OPTARG}"
		;;
		p)
			readonly hostPort="${OPTARG}"
		;;
		esac
	done

	return 0
}

usage() {
	cat <<- EOM 1>&2
	usage: $PROGNAME options
	-h || --help		Print this message
	-b || --base <path>	Set the base path to the IDP, default is /opt/shibboleth-idp
	-p || --port <port>	Set the HTTPS port to the IDP
	-u || --url		Print the URL for the request, you can use this in your browser form a host which is allowed in the ACL
	
	EOM
}

askString() {
	local title=$1
	local text=$2
	local value=$3
	local null=$4
	local string=""

	while [[ -z "${string}" ]]; do
		if [ "${GUIen}" = "y" ]; then
			string=$(${whiptailBin} --backtitle "${BackTitle}" --title "${title}" --nocancel --inputbox --clear -- "${text}" ${whipSize} "${value}" 3>&1 1>&2 2>&3)
		else
			local show=${text}
			if [[ ! -z "${value}" ]]; then
				show="${show} [${value}]"
			fi
			${Echo} "${show}: " >&2
			read string
			${Echo} "" >&2
			if [[ ! -z "${value}" && -z "${string}" ]]; then
				string=${value}
			fi
		fi

		if [[ -z "${string}" && ! -z "${null}" ]]; then
			break
		fi
	done

	${Echo} "${string}"
}

askListLargeCancel() {
	local title=$1
	local text=$2
	local list=$3
	local noItem="--noitem"
	if [ ! -z "${4}" ]; then
		noItem=""
	fi
	local string=""

	if [[ "${GUIen}" = "y" ]]; then
		local WTcmd="${whiptailBin} --backtitle \"${BackTitle}\" --title \"${title}\" --menu ${noItem} --clear -- \"${text}\" ${whipSizeLarge} 12 ${list} 3>&1 1>&2 2>&3"
		string=$(eval ${WTcmd})
	else
		${Echo} ${text} >&2
		${Echo} "" >&2
		${Echo} ${list} | sed -re 's/\"([^"]+)\"\ *\"([^"]+)\"\ */\1\ \-\-\ \2\n/g' | sed -re "s/\ '\ '\ ?/\n/g" >&2
		read string
		${Echo} "" >&2
	fi

	${Echo} "${string}"
}

findCipher() {
	local port=$1
	local cipher=""
	for i in `openssl ciphers |sed 's/:/\ /g'`; do
		echo "QUIT" | openssl s_client -connect localhost:${port} -quiet -cipher ${i} >/dev/null 2>&1
		ret=$?
		if [[ ${ret} -eq 0 ]]; then
			cipher=${i}
			break
		fi
	done
	if [ "x${cipher}" == "x" ]; then
		${Echo} "No suitable cipher found, can't make request to server." 1>&2
		exit 1
	else
		${Echo} ${cipher}
	fi
}

main() {
	local url=""
	local taskList="aacli ' ' metadata ' ' reload ' '"
	local task=$(askListLargeCancel "Choose task" "Please choose a task." "${taskList}")

	if [[ -z "${task}" ]]; then
		${Echo} "Cancel"
		exit
	fi

	if [[ "${task}" = "aacli" ]]; then
		local princ=""
		local entID=""

		princ=$(askString "Enter principal" "Please enter your principal, ie. username." "" "1")
		if [[ -s "${idpBaseDir}/conf/services.xml" ]]; then
			ids=""
			for i in `sed -ne '/<util:list id ="shibboleth.AttributeFilterResources">/,/<\/util:list>/p' ${idpBaseDir}/conf/services.xml | grep value | awk '{print $(NF-2)}' FS='[><]' | sed "s&\%{idp.home}&${idpBaseDir}&g"`; do
				ids="${ids} `cat ${i} | awk 'in_comment&&/-->/{sub(/([^-]|-[^-])*--+>/,\"\");in_comment=0} in_comment{next} {gsub(/<!--+([^-]|-[^-])*--+>/,\"\"); in_comment=sub(/<!--+.*/,\"\"); print}' | grep 'xsi:type=\"Requester\"' | awk -F'value=' '{ print $2 }' | cut -d\\\" -f2`"
			done
		fi
		local idList=$(
			for i in ${ids}; do
				echo "${i} ' '"
			done
			echo "InputBox ' '"
		)
		entID=$(askListLargeCancel "Choose entityID" "Please choose a entityID or select 'InputBox' to enter another." "${idList}")
		if [[ "${entID}" = "InputBox" ]]; then
			entID=$(askString "Enter requestor entityID" "Please enter the requestor entityID." "" "1")
		fi

		if [[ -z "${princ}" || -z "${entID}" ]]; then
			${Echo} "Not enough data supplied"
			exit
		fi

		local extras="None '- No extra option' saml2 '- Display full saml2:Assertion' saml1 '- Display full saml1:Assertion'"
		local extra=$(askListLargeCancel "Extra options" "Do you want to add an extra option to the request?" "${extras}" " ")
		if [[ "${extra}" == "None" || "x${extra}" == "x" ]]; then
			extra=""
		else
			extra="&${extra}"
		fi

		url="/idp/profile/admin/resolvertest?requester=${entID}&principal=${princ}${extra}"
	elif [[ "${task}" = "metadata" ]]; then
		if [[ ! -s "${idpBaseDir}/conf/metadata-providers.xml" ]]; then
			${Echo} "Can't find the file metadata-providers.xml, aborting.\nPlease see script help."
			exit 1
		fi

		local provider=""
		local idList="`cat ${idpBaseDir}/conf/metadata-providers.xml | awk 'in_comment&&/-->/{sub(/([^-]|-[^-])*--+>/,\"\");in_comment=0} in_comment{next} {gsub(/<!--+([^-]|-[^-])*--+>/,\"\"); in_comment=sub(/<!--+.*/,\"\"); print}' | sed '/^[\ \t]*$/d' | grep '<MetadataProvider' | awk -F' id=' '{print $2}' | cut -d\\\" -f2 | tr '\n' ' '`"
		local provList=$(
			for i in ${idList}; do
				if [[ ${i} = "ShibbolethMetadata" ]]; then
					echo "${i} ' - All metadata'"
				else
					echo "${i} ' '"
				fi
			done
		)

		provider=$(askListLargeCancel "Reload IDP metadata" "Please choose which metadata feed id you want to reload." "${provList}" "1")
		if [[ -z "${provider}" ]]; then
			${Echo} "Cancel"
			exit
		fi

		url="/idp/profile/admin/reload-metadata?id=${provider}"
	elif [[ "${task}" = "reload" ]]; then
		if [[ ! -s "${idpBaseDir}/system/conf/services-system.xml" ]]; then
			${Echo} "Can't find the file services-system.xml, aborting.\nPlease see script help."
			exit 1
		fi

		local service=""
		local servList=$(
			for i in `grep 'class="net.shibboleth.ext.spring.service' ${idpBaseDir}/system/conf/services-system.xml | cut -d\" -f2 | grep "^shibboleth"`; do
				echo "${i} ' '"
			done
			echo "shibboleth.LoggingService ' '"
		)

		service=$(askListLargeCancel "Reload IDP component" "Please choose which IDP component you want to reload." "${servList}")
		if [[ -z "${service}" ]]; then
			${Echo} "Cancel"
			exit
		fi

		url="/idp/profile/admin/reload-service?id=${service}"
	fi

	local hostPort=$(getHostPort)
	local cipher=$(findCipher ${hostPort})
	${Echo} "GET ${url} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" | openssl s_client -connect localhost:${hostPort} -quiet -cipher ${cipher} 2>/dev/null | awk '{ if (/^\s*$/) x=1; if (x==1) print; }'

	if [[ "${task}" != "aacli" ]]; then
		${Echo} "\nPlease check ${idpBaseDir}/logs/idp-process.log for potential errors."
	fi
	if [[ "${printURL}" -eq 1 ]]; then
		${Echo} "\nRequest URL is: ${url}"
	fi
}

cmdline ${ARGS}
main
