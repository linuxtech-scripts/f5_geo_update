# f5_geo_update
F5 Geolocation database update script

This script will sign into downloads.f5.com (using existing credentials), 
and download the latest appropriate geolocation database for the BIG-IP release
and install the update.
This should work on all current supported BIG-IP releases.

Place the script in /etc/cron.weekly or /etc/cron.daily and ensure that it is executable.
It stores the name of the last update installed in /var/tmp/geo
and only downloads if a new file is available.

If you need to use a proxy to get to the download site, you can set a proxy options
variable.
As the credentials used to access downloads.f5.com are stored in the script, I recommend
creating a new set of credentials for this purpose, and only using those credentials for 
this purpose.

Set the variables
  downloads_user=""
  downloads_password=""
  downloads_from="USA - WEST COAST"
  proxy_opts=""

The script logs into /var/log/ltm when it runs, downloads and installs the database.
It also logs errors, such as login failure and database backup errors.

If the F5 Downloads site changes or restructures, the script will probably fail.
