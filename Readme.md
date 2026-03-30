
# MATOMO for rancher 1.6, based on matomo:fpm-alpine



## How to upgrade

* Prepare the new Docker image + Helm chart for the new version
* Backup
* Downscale the matomo deployment to 1
* Check that no archiving is running or scheduled (or disable archiving)
* Log in to Matomo UI and upgrade from the interface. The page will show "Matomo has been successfully updated!"
* Refresh the page to show the "Database Upgrade Required" message
* Upgrade the DB
* Upgrade the Rancher App using the Helm chart with the new image
* Scale up and re-enable archiving if disabled

**Things to note**:

Do not scale up until the Rancher App upgrade is finished; the instances that do not have the new image will show "Your Matomo codebase is running the old version 5.7.1 and we have detected that your Matomo Database has already been upgraded to the newer version 5.8.0". As one instance will be upgraded and the others will not, and the requests are load balanced, the UI will not work correctly even for the upgraded instance in this case.

The archiving will not work until the Rancher App upgrade is finalized; they will log Errors like "Got invalid response from API request: ?module=API&method=CoreAdminHome.archiveReports. Response was '{"result":"error","message":"Your Matomo codebase is running the old version 5.7.1 and we have detected that your Matomo Database has already been upgraded to the newer version 5.8.0" until the upgrade is finished

If you get any security-related messages from Matomo, make sure the matomo deployment is downscaled to 1 and refresh your browser.

### Code upgrades

This repo was made from the matomo:fpm-alpine repo, with the following differences:

1. Added our scripts (run_*, [matomo_entra_sync.php](matomo_entra_sync.php))
2. Added logos into /usr/src/matomo/misc/user/
3. Added the JS patch below and an automatic patch to config/manifest.inc.php with the new file size and sha256 hash 

### Patch

Until ` Avoid empty string values in serialized referrer cookie #22071 ` bug is fixed, you need to update the js files.

You need to fork matomo repository and rebase the branch `m21170` with the latest changes.

You should re-minify the js files to make sure they were rebased correctly:


  To install YUICompressor run:
 
  ```bash
  cd /path/to/piwik/js/
  wget https://github.com/yui/yuicompressor/releases/download/v2.4.8/yuicompressor-2.4.8.zip
  unzip yuicompressor-2.4.8.zip
  ```

  To compress the code containing the evil "eval", run:

  ```bash
  cd /path/to/piwik/js/
  sed '/<DEBUG>/,/<\/DEBUG>/d' < piwik.js | sed 's/eval/replacedEvilString/' | java -jar yuicompressor-2.4.8.jar --type js --line-break 1000 | sed 's/replacedEvilString/eval/' | sed 's/^[/][*]/\/*!/' > piwik.min.js && cp piwik.min.js ../piwik.js && cp piwik.min.js ../matomo.js
  ```

### Backup database with no visits/archives

  ```bash
    echo "show tables;" | mysql -p$MARIADB_ROOT_PASSWORD $MARIADB_DATABASE | grep -v ^matomo_log_ | grep -v ^matomo_archive_ | grep -v ^Tables_in_eea | tr '\n' ' ' >  /var/lib/mysql/tablelist.txt
    echo "show tables;" | mysql -p$MARIADB_ROOT_PASSWORD $MARIADB_DATABASE | grep -E '^matomo_log_|^matomo_archive_' | grep -v ^Tables_in_eea | tr '\n' ' ' >  /var/lib/mysql/tablelist-data.txt
    mysqldump -u root -p$MARIADB_ROOT_PASSWORD --add-drop-table $MARIADB_DATABASE $(cat /var/lib/mysql/tablelist.txt) > /var/lib/mysql/backup_$(date '+%F').sql
    mysqldump -u root -p$MARIADB_ROOT_PASSWORD --add-drop-table --no-data  $MARIADB_DATABASE $(cat /var/lib/mysql/tablelist-data.txt)  >> /var/lib/mysql/backup_$(date '+%F').sql

  ```

### Plugin upgrades

The plugin upgrades can be done from the Matomo UI. When installing a new Matomo version, the pligins will be upgraded automatically. 

## User synchronization with Entra ID

The image contains a scheduled task to synchronize the local users with the Entra ID users. The steps are
* Create in Matomo all the new users from Entra ID, without access rights
* Update in Matomo all the e-mails with different case
* For the users in the specified AZURE_VIEW_GROUP Entra group (and its subgroups), add view rights to all the Matomo sites. This applies also to newly added sites.
* Delete from Matomo all the users that are not in Entra anymore

The user identification is only possible via the e-mail field. 

The script [matomo_entra_sync.php](matomo_entra_sync.php) uses the following environment variables, that have to be configured in the orchestrator:

* AZURE_TENANT_ID - the tenant ID from Entra
* AZURE_CLIENT_ID - the client ID of the Entra application
* AZURE_CLIENT_SECRET - the secret of the Entra application
* AZURE_VIEW_GROUP - the Entra group of the users to be synchronized
* ADMIN_EMAIL - a user e-mail to be avoided when deleting users that are not in Entra (optional, for a local backup user)
* SYNC_DEBUG - enables verbose output (optional, true/false, default false)
The Entra ID application set up above needs to have read access to the Graph API to read users and groups.  

The other environment variables should be already set up for Matomo:
* MATOMO_DATABASE_HOST
* MATOMO_DATABASE_USERNAME
* MATOMO_DATABASE_PASSWORD
* MATOMO_DATABASE_DBNAME
* MATOMO_DATABASE_PORT - defaults to 3306

To schedule, the existing [run_ldapsync.sh](run_ldapsync.sh) script is modified to start the php script.
