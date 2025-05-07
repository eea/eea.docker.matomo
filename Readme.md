
# MATOMO for rancher 1.6, based on bitnami/matomo



## How to upgrade

Check if entrypoint.sh was changed, as we are using it to add our code.

https://github.com/bitnami/containers/blame/main/bitnami/matomo/5/debian-12/rootfs/opt/bitnami/scripts/matomo/entrypoint.sh


### Small/version differences

No code updates, only version updates

1. Update the code with the small updates ( do not update any debian OS related version)
2. Fix the commit id in the `Readme.md` file

### Code upgrades

This repo was made from the bitnami repo, with the following differeces:

1. Added our scripts 

2. Update `./rootfs/opt/bitnami/scripts/matomo/entrypoint.sh`

    a. Update `if` line to support `run_` docker commands
    
    b. add `/use_matomo_in_rancher.sh`




### Patch

Until ` Avoid empty string values in serialized referrer cookie #22071 ` bug is fixed, you need to update the js files.

You need to fork matomo repository and rebase the branch `m21170` with the latest changes.

You should re-minify the js files to make sure they were rebased correctly:


  To install YUICompressor run:
 
  ```bash
  $ cd /path/to/piwik/js/
  $ wget https://github.com/yui/yuicompressor/releases/download/v2.4.8/yuicompressor-2.4.8.zip
  $ unzip yuicompressor-2.4.8.zip
  ```

  To compress the code containing the evil "eval", run:

  ```bash
  $ cd /path/to/piwik/js/
  $ sed '/<DEBUG>/,/<\/DEBUG>/d' < piwik.js | sed 's/eval/replacedEvilString/' | java -jar yuicompressor-2.4.8.jar --type js --line-break 1000 | sed 's/replacedEvilString/eval/' | sed 's/^[/][*]/\/*!/' > piwik.min.js && cp piwik.min.js ../piwik.js && cp piwik.min.js ../matomo.js
  ```

### Backup database with no visits/archives

  ```bash
    $ echo "show tables;" | mysql -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE | grep -v ^matomo_log_ | grep -v ^matomo_archive_ | grep -v ^Tables_in_eea | tr '\n' ' ' >  /var/lib/mysql/tablelist.txt
    $ echo "show tables;" | mysql -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE | grep -E '^matomo_log_|^matomo_archive_' | grep -v ^Tables_in_eea | tr '\n' ' ' >  /var/lib/mysql/tablelist-data.txt
    $ mysqldump -u root -p$MYSQL_ROOT_PASSWORD --add-drop-table $MYSQL_DATABASE $(cat /var/lib/mysql/tablelist.txt) > /var/lib/mysql/backup_$(date '+%F').sql
    $ mysqldump -u root -p$MYSQL_ROOT_PASSWORD --add-drop-table --no-data  $MYSQL_DATABASE $(cat /var/lib/mysql/tablelist-data.txt)  >> /var/lib/mysql/backup_$(date '+%F').sql

  ```




