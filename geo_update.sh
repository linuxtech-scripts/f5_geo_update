#! /bin/bash
# f5 geolocation updater
# linuxtech@mail.com
# free for use 
logger -p local0.notice "Geolocation update file check - checking for updates"
base_dir="/var/tmp/geo"
if [[ ! -e $base_dir ]]; then
    mkdir -p $base_dir
fi
cd $base_dir
if [[ -e "$base_dir/geo_cookies.txt" ]]; then
  /bin/rm -f "$base_dir/geo_cookies.txt"
fi
fullversion=$(tmsh show sys version | grep " Version" | awk '{ print $2 }')
# echo $fullversion
baseversion=$(echo $fullversion | awk -F. '{ print $1 }')
# echo $baseversion
containerversion=$(echo $fullversion | awk -F. '{ print $1"."$2"."$3 }')
# backup the current Geolocation database
dir="/shared/GeoIP_backup"
if [[ ! -e $dir ]]; then
    mkdir -p $dir
elif [[ ! -d $dir ]]; then
	logger -p local0.err "Geolocation update file check - error backing up Geolocation database: $dir already exists but is not a directory"
	exit
fi
if [ $baseversion -ge 15 ]; then
  /bin/cp -R /shared/GeoIP/* /shared/GeoIP_backup/
else
  /bin/cp -R /usr/share/GeoIP/* /shared/GeoIP_backup/
fi 
# echo $containerversion
container="sw=BIG-IP&pro=big-ip_v$baseversion.x&ver=$containerversion&container=GeoLocationUpdates"
# echo $container
downloads_user=""
downloads_password=""
downloads_from="USA - WEST COAST"
# specify any curl proxy options as required
# eg --proxy http://user:password@host:port/
# or
# "" for direct connect
proxy_opts=""
# get the login page
loginpage=$(curl -m 10 --connect-timeout 2 --no-keepalive -kLb $base_dir/geo_cookies.txt -c $base_dir/geo_cookies.txt $proxy_opts --silent https://downloads.f5.com/esd/ecc.sv?$container 2>&1 | grep "action=" | awk -F'[=\"|\">]' '{ print $3 }' )
# echo $loginpage
# submit the credentials
afterlogin=$(curl -m 10 --connect-timeout 2 --no-keepalive -kLb $base_dir/geo_cookies.txt -c $base_dir/geo_cookies.txt $proxy_opts --silent $loginpage -X POST --data-urlencode "userid=$downloads_user" --data-urlencode "passwd=$downloads_password" 2>&1 | grep "F5 - My Account" | awk -F'[="|">]' '{ print $6 }' )
# echo $afterlogin
if [[ $afterlogin == "" ]]; then
  logger -p local0.err "Geolocation update file check - login failure"
  /bin/rm -f "$base_dir/geo_cookies.txt"
  exit
fi
# back to the geolocation container
target_container="https://downloads.f5.com/esd/ecc.sv?$container"
# echo $target_container
mycontainer=$(curl -m 10 --connect-timeout 2 --no-keepalive -kLb $base_dir/geo_cookies.txt -c $base_dir/geo_cookies.txt $proxy_opts --silent $target_container 2>&1 )
# send the EULA accept
eula_path="https://downloads.f5.com/esd/eula.sv?$container&path=&file=&B1=I+Accept"
# echo $eula_path
servedownload=$(curl -m 10 --connect-timeout 2 --no-keepalive -kvLb $base_dir/geo_cookies.txt -c $base_dir/geo_cookies.txt $proxy_opts --silent --ignore-content-length "$eula_path" 2>&1 | grep -e "href\=.*zip\'" | awk -F"[<|>]" '{print $2}' | awk -F'=' '{ st = index($0,"="); print substr($0,st+1) }' | awk -F"'" '{ print $2 }' )
# echo $servedownload
# get the AWS zip location
target_zip="https://downloads.f5.com/esd/$servedownload"
# echo $target_zip
selected_zip=$(curl -m 10 --connect-timeout 2 --no-keepalive -kLb $base_dir/geo_cookies.txt -c $base_dir/geo_cookies.txt $proxy_opts --silent "$target_zip" 2>&1 | grep -e "href.*${downloads_from}" | awk -F'[<|>]' '{ print $6 } ' | awk -F'=' '{ st = index($0,"="); print substr($0,st+1) }' | awk -F'"' '{ print $2 }' )
# echo $selected_zip
zip_file_name=$( echo $selected_zip | awk -F'[?]' '{ print $1 }' | awk -F'[/]' '{ print $NF }' )
# echo $zip_file_name
if [[ ! -e $zip_file_name ]]; then
	logger -p local0.notice "Geolocation update file check - downloading update $zip_file_name"
	curl -m 30 --connect-timeout 2 --no-keepalive -kLb $base_dir/geo_cookies.txt -c $base_dir/geo_cookies.txt $proxy_opts --silent -o "$base_dir/$zip_file_name" "$selected_zip" 2>&1
	md5servedownload=$(curl -m 5 --connect-timeout 2 --no-keepalive -kvLb $base_dir/geo_cookies.txt -c $base_dir/geo_cookies.txt $proxy_opts --silent --ignore-content-length "$eula_path" 2>&1 | grep -e "href\=.*zip.md5\'" | awk -F"[<|>]" '{print $2}' | awk -F'=' '{ st = index($0,"="); print substr($0,st+1) }' | awk -F"'" '{ print $2 }' )
	target_md5="https://downloads.f5.com/esd/$md5servedownload"
	selected_md5=$(curl -m 5 --connect-timeout 2 --no-keepalive -kLb $base_dir/geo_cookies.txt -c $base_dir/geo_cookies.txt $proxy_opts --silent "$target_md5" 2>&1 | grep -e "href.*${downloads_from}" | awk -F'[<|>]' '{ print $6 } ' | awk -F'=' '{ st = index($0,"="); print substr($0,st+1) }' | awk -F'"' '{ print $2 }' )
	md5_file_name=$( echo $selected_md5 | awk -F'[?]' '{ print $1 }' | awk -F'[/]' '{ print $NF }' )
	# echo $md5_file_name
	curl -m 30 --connect-timeout 2 --no-keepalive -kLb $base_dir/geo_cookies.txt -c $base_dir/geo_cookies.txt $proxy_opts --silent -o "$base_dir/$md5_file_name" "$selected_md5" 2>&1
	if md5sum --status -c $md5_file_name; then
	  logger -p local0.notice "Geolocation update file check - installing update $zip_file_name"
	  unzip -qq "$base_dir/$zip_file_name" 2>&1 > /dev/null
	  for rpm in *.rpm
	  do
		# echo $rpm
		geoip_update_data -l -f $rpm 2>&1 > /dev/null
		/bin/rm -f $rpm
	  done
	  /bin/rm -f "$base_dir/geo_cookies.txt"
	  /bin/rm -f "$base_dir/README.txt"
	  /bin/rm -f "$base_dir/$zip_file_name"
	  /bin/rm -f "$base_dir/$md5_file_name"
	  for last_zip in "*.zip"
	  do
		rm -f $last_zip
	  done
	  touch "$base_dir/$zip_file_name"
	else
		logger -p local0.err "Geolocation update file check - download failed verification"
		/bin/rm -f "$base_dir/geo_cookies.txt"
	    /bin/rm -f "$base_dir/$zip_file_name"
	    /bin/rm -f "$base_dir/$md5_file_name"
	fi
else
	logger -p local0.notice "Geolocation update file check - latest database currently installed"
    /bin/rm -f "$base_dir/geo_cookies.txt"
fi
