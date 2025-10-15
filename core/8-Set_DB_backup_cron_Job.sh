#!/bin/bash

echo 'Part 8: Set Up Database Backup Cron Job'

# Create MySQL backup script
sudo tee /usr/local/bin/backup-mysql.sh > /dev/null << 'EOF'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/var/lib/backup/mysql"
mkdir -p $BACKUP_DIR

# Hot backup using mysqldump
mysqldump --defaults-file=/etc/mysql/debian.cnf --all-databases --single-transaction | gzip > $BACKUP_DIR/all-databases-$TIMESTAMP.sql.gz

# Backup individual databases
for DB in nova keystone glance neutron cinder trove zun octavia designate kitti; do
  mysqldump --defaults-file=/etc/mysql/debian.cnf --single-transaction $DB | gzip > $BACKUP_DIR/$DB-$TIMESTAMP.sql.gz
done

# Remove backups older than 7 days
find $BACKUP_DIR -name "*.sql.gz" -type f -mtime +7 -delete
EOF

# Make script executable
sudo chmod +x /usr/local/bin/backup-mysql.sh

# Add to crontab to run daily at 3 AM
echo "0 3 * * * /usr/local/bin/backup-mysql.sh" | sudo tee -a /etc/crontab
