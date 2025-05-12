#!/bin/bash

echo 'Part 6: Configure MySQL for InnoDB'

# Configure MySQL for better performance
cat > mysql-tuning.yaml << 'EOF'
mysql:
  settings:
    innodb-buffer-pool-size: 4G
    innodb-log-file-size: 512M
    innodb-flush-log-at-trx-commit: 1
    innodb-lock-wait-timeout: 50
    max-connections: 1000
    query-cache-size: 64M
    query-cache-limit: 2M
    thread-cache-size: 8
    max-allowed-packet: 16M
    character-set-server: utf8
    collation-server: utf8_general_ci
EOF

# Apply MySQL tuning
juju config mysql --file=mysql-tuning.yaml


