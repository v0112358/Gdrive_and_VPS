#!/bin/bash
# Backup source code and mysql database to Google Drive
# Date: 20/07/2016
# Author: vy.nt@vinahost.vn

GDRIVE="/usr/sbin/gdrive"
DES_DIR="ALL_BACKUP_VPS"
SRC_DIR="/home/vinahost/"
TODAY="$(date +"%Y-%m-%d")"
KEEP_BACKUP=2
# Available otions: COMPRESS and SYNC. SYNC does not support rotate backup
BACKUP_SOURCE_TYPE="COMPRESS"
BACKUP_LOG="/var/log/gdrive_backup.log"

[[ ! -e $GDRIVE ]] && echo "gdrive was not installed. Please install gdrive first !" | tee $BACKUP_LOG && exit
# Create new parent backup folder if not exist
$GDRIVE list | grep $DES_DIR || $GDRIVE mkdir $DES_DIR
PARENT_ID=$($GDRIVE list | grep $DES_DIR | awk '{print $1}')

#Rotate backup
REMOVE_FOLDER_NAME=$(date --date="$KEEP_BACKUP days ago" +%Y-%m-%d)
REMOVE_FOLDER_ID=$($GDRIVE list --absolute | awk '{print $1" " $2}' | egrep "$DES_DIR/$REMOVE_FOLDER_NAME$" | awk '{print $1}')
[[ ! -z $REMOVE_FOLDER_ID ]] && $GDRIVE delete -r $REMOVE_FOLDER_ID

#Create new backup folder
$GDRIVE list | awk '{print $2}' | grep $TODAY || $GDRIVE mkdir -p $PARENT_ID $TODAY
PARENT_ID_TODAY=$($GDRIVE list --absolute | awk '{print $1" "$2}' | egrep "$DES_DIR/$TODAY$" | awk '{print $1}')
$GDRIVE list --absolute | awk '{print $2}' | grep "$DES_DIR/$TODAY/SOURCE" || $GDRIVE mkdir -p $PARENT_ID_TODAY SOURCE
$GDRIVE list --absolute | awk '{print $2}' | grep "$DES_DIR/$TODAY/DATABASE" || $GDRIVE mkdir -p $PARENT_ID_TODAY DATABASE
SOURCE_ID=$($GDRIVE list --absolute | grep "$DES_DIR/$TODAY/SOURCE" | awk '{print $1}')
DATABASE_ID=$($GDRIVE list --absolute | grep "$DES_DIR/$TODAY/DATABASE" | awk '{print $1}')

#Backup source code to Google Drive
#COMPRESS method was recommended for folder size less than 2GB
#SYNC method was recommended for large folder size

echo "=====`date`: BEGIN BACKUP SOURCE CODE =====" >> $BACKUP_LOG
if [[ $BACKUP_SOURCE_TYPE == "COMPRESS" ]]; then
	[[ -d "$SRC_DIR" ]] && tar -zcPf /root/source-backup.$(date '+%Y-%m-%d').tar.gz $SRC_DIR && $GDRIVE upload -p $SOURCE_ID /root/source-backup.$(date '+%Y-%m-%d').tar.gz && echo "Upload backup file to Google drive is completed" >> $BACKUP_LOG
	rm -f /root/source-backup.$(date '+%Y-%m-%d').tar.gz && echo "Remove local backup file is completed" >> $BACKUP_LOG
else
	$GDRIVE sync upload $SRC_DIR $SOURCE_ID && echo "SYNC $SRC_DIR to Google drive is completed" >> $BACKUP_LOG
fi
echo "=====`date`: END BACKUP SOURCE CODE =====" >> $BACKUP_LOG

# Backup databse to Google Drive
echo "=====`date`: BEGIN BACKUP MySQL DATABASE =====" >> $BACKUP_LOG
DB_LIST=$(mysql --defaults-extra-file=/root/.my.cnf -Bse 'show databases' | grep -v eximstats)
for db in $DB_LIST; do
	[[ `cat /proc/loadavg | awk -F. {'print $1'}` -gt 16 ]] && sleep 300 && echo "Server hight load... sleep 300s " >> $BACKUP_LOG
	mysqldump --defaults-extra-file=/root/.my.cnf --single-transaction --routines --triggers $db  | gzip -9 > /root/$db.`date +"%Y-%m-%d"`.sql.gz && echo "MySQL backup is completed: $db - `date` " >> $BACKUP_LOG || echo "MySQL backup failed: $db - `date` " >> $BACKUP_LOG
	$GDRIVE upload -p $DATABASE_ID /root/$db.`date +"%Y-%m-%d"`.sql.gz && echo "Upload MySQL backup file to Google Drive is completed" >> $BACKUP_LOG
	rm -f /root/$db.`date +"%Y-%m-%d"`.sql.gz && echo "Remove local MySQL backup file is completed" >> $BACKUP_LOG
done
echo "=====`date`: END BACKUP MySQL DATABASE =====" >> $BACKUP_LOG
