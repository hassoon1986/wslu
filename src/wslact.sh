# shellcheck shell=bash
version="01"

help_short="wslact [flags] [command] ..."

function gen_startup {
	local help_short="wslact gen_startup [--name <NAME>] [-S <Service> | <Command> ]\n\nGenerate a WSL startup Task using Windows Task Schduler."
	isService=0
	wa_gs_commd=""
	wa_gs_name=""
	wa_gs_user="root"

	while [ "$1" != "" ]; do
		case "$1" in
			-u|--user) shift; wa_gs_user="$1"; shift;;
			-n|--name) shift; wa_gs_name="$1"; shift;;
			-S|--service) isService=1; shift;;
			-h|--help) help "wslact" "$help_short"; exit;;
			*) wa_gs_commd="$*";break;;
		esac
	done

	if [[ "$wa_gs_commd" != "" ]]; then
		tmp_location="$(wslvar -s TMP)"
		up_location=""
		tpath="$(double_dash_p "$tmp_location")" # Windows Temp, Win Double Sty.
		tpath_linux="$(wslpath "$tmp_location")" # Windows Temp, Linux WSL Sty.
		script_location_win="$(wslvar -s USERPROFILE)\\wslu" #  Windows wslu, Win Double Sty.
		script_location="$(wslpath "$script_location_win")" # Windows wslu, Linux WSL Sty.

		# Check presence of sudo.ps1 and 
		wslu_file_check "$script_location" "sudo.ps1"
		wslu_file_check "$script_location" "runHidden.vbs"

		# check if it is a service or a command
		if [[ $isService -eq 1 ]]; then
		# service
			# handling no name given case
			if [[ "$wa_gs_name" = "" ]]; then
				wa_gs_name="$wa_gs_commd"
			fi
			wa_gs_commd="wsl.exe -d $WSL_DISTRO_NAME -u $wa_gs_user service $wa_gs_commd start"
		else
		# command
			# handling no name given case
			if [[ "$wa_gs_name" = "" ]]; then
				wa_gs_name=$(basename "$(echo "$wa_gs_commd" | awk '{print $1}')")
			fi
			wa_gs_commd="wsl.exe -d $WSL_DISTRO_NAME -u $wa_gs_user $wa_gs_commd"
		fi

		# shellcheck disable=SC2028
		tee "$tpath_linux"/tmp.ps1 << EOF
Import-Module 'C:\\WINDOWS\\system32\\WindowsPowerShell\\v1.0\\Modules\\Microsoft.PowerShell.Utility\\Microsoft.PowerShell.Utility.psd1';\$action = New-ScheduledTaskAction -Execute 'C:\\Windows\\System32\\wscript.exe'  -Argument '$script_location_win\\runHidden.vbs $wa_gs_commd';
\$trigger =  New-ScheduledTaskTrigger -AtLogOn -User \$env:userdomain\\\$env:username; \$task = New-ScheduledTask -Action \$action -Trigger \$trigger -Description \"Start service $wa_gs_name from $WSL_DISTRO_NAME when computer start up; Generated By WSL Utilities\";
Register-ScheduledTask -InputObject \$task -TaskPath '\\' -TaskName 'WSLUtilities_Actions_Startup_$wa_gs_name';
EOF
		echo "${warn} WSL Utilities is adding \"${wa_gs_name}\" to Task Scheduler; A UAC Prompt will show up later. Allow it if you know what you are doing."
		if winps_exec "$script_location_win"\\sudo.ps1 "$tpath"\\tmp.ps1; then
			rm -rf "$tpath_linux/tmp.ps1"
			echo "${info} Startup \"${wa_gs_name}\" added."

		else
			rm -rf "$tpath_linux/tmp.ps1"
			echo "${error} Adding Startup \"${wa_gs_name}\" failed."
			exit 1
		fi
	else
		echo "${error} No input, aborting"
		exit 21
	fi

	unset name
}

function time_sync {
	if [ "$EUID" -ne 0 ]
		then echo "${error} \`wslact time-sync\` requires you to run as root. Aborted."
		exit 1
	fi
	while [ "$1" != "" ]; do
		case "$1" in
			-h|--help) help "wslact" "$help_short"; exit;;
			*) echo "${error} Invalid Input. Aborted."; exit 22;;
		esac
	done
	echo "${info} Before Sync: $(date +"%d %b %Y %T %Z")"
	if date -s "$(winps_exec "Get-Date -UFormat \"%d %b %Y %T %Z\"" | tr -d "\r")" >/dev/null; then
		echo "${info} After Sync: $(date +"%d %b %Y %T %Z")"
		echo "${info} Manual Time Sync Complete."
	else
		echo "${error} Time Sync failed."
		exit 1
	fi
}


while [ "$1" != "" ]; do
	case "$1" in
		gs|gen-startup) shift; gen_startup "$@"; exit;;
		ts|time-sync) time_sync "$@"; exit;;
		-h|--help) help "$0" "$help_short"; exit;;
		-v|--version) echo "wslu v$wslu_version; wslact v$version"; exit;;
		*) echo "${error} Invalid Input. Aborted."; exit 22;;
	esac
done