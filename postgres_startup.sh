#!/bin/bash

clusterName=$1
amountZooKeepers=$2
amountPostgres=$3
myIndex=$4
adminUsername=$5
adminPassword=$6
hacfgFile=postgresha.cfg
patroniCfg=postgres.yml

export DEBIAN_FRONTEND=noninteractive
sudo touch /usr/local/startup.log
sudo chmod 666 /usr/local/startup.log
echo "Cluster name: $clusterName" >> /usr/local/startup.log
echo "Zookeepers: $amountZooKeepers" >> /usr/local/startup.log
echo "Postgres: $amountPostgres" >> /usr/local/startup.log
echo "Admin user: $adminUsername" >> /usr/local/startup.log
echo "Admin password: $adminPassword" >> /usr/local/startup.log
echo "MyIndex: $myIndex" >> /usr/local/startup.log
echo "" >> /usr/local/startup.log

# format and partition data disk(s)
# will be mounted at "/media/data(n)"
sudo chmod +x ./autopart.sh >> /usr/local/startup.log
sudo ./autopart.sh >> /usr/local/startup.log
sudo mkdir /media/data1/data
sudo chmod 777 /media/data1/data
echo "/media/data1/data partition created" >> /usr/local/startup.log
echo "" >> /usr/local/startup.log

# create RAID
#sudo apt-get --assume-yes -qq install mdadm
#sudo apt-get --assume-yes -qq install xfsprogs
#sudo chmod +x ./ebs_raid0.sh >> /usr/local/startup.log
#sudo ./ebs_raid0.sh /mnt/database >> /usr/local/startup.log
#sudo mkdir /mnt/database/data
#sudo chmod 777 /mnt/database/data

# update package lists for PostgreSQL 9.6
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -
sudo apt-get  --assume-yes -qq update
sudo apt-get  --assume-yes -qq upgrade
sudo apt-get  --assume-yes -qq install jq
echo "apt-get update exited with: $?"
echo "updated packages" >> /usr/local/startup.log
echo "" >> /usr/local/startup.log


# install python
sudo apt-get --assume-yes -qq install libpq-dev
echo "apt-get libpq-dev exited with: $?"
sudo apt-get --assume-yes -qq install python-dev
echo "apt-get python-dev exited with: $?"
sudo apt-get --assume-yes install python-pip
echo "apt-get python-pip exited with: $?"
sudo pip -q install boto
echo "pip boto exited with: $?"
sudo pip -q install psycopg2
echo "pip psycopg2 exited with: $?"
sudo pip -q install PyYAML --upgrade
echo "pip PyYAML exited with: $?"
sudo pip -q install requests --upgrade
echo "pip requests exited with: $?"
sudo pip -q install six --upgrade
echo "pip six exited with: $?"
sudo pip -q install kazoo
echo "pip kazoo exited with: $?"
sudo pip -q install python-etcd
echo "pip python-etcd exited with: $?"
sudo pip -q install python-consul
echo "pip python-consul exited with: $?"
sudo pip -q install click
echo "pip click exited with: $?"
sudo pip -q install prettytable --upgrade
echo "pip prettytable exited with: $?"
sudo pip -q install tzlocal
echo "pip tzlocal exited with: $?"
sudo pip -q install python-dateutil
echo "pip python-dateutil exited with: $?"
echo "installed python" >> /usr/local/startup.log
echo "" >> /usr/local/startup.log

# install postgres
# prevent postgres from autostart
#sudo touch /usr/sbin/policy-rc.d
#sudo chmod 777 /usr/sbin/policy-rc.d
#echo exit 101 > /usr/sbin/policy-rc.d
sudo apt-get --assume-yes --force-yes -qq install postgresql postgresql-contrib postgresql-server-dev-9.6
echo "apt-get postgresql postgresql-server-dev-9.6 postgresql-contrib exited with: $?"
export PATH=/usr/lib/postgresql/9.6/bin:$PATH
echo "installed postgres" >> /usr/local/startup.log
echo "" >> /usr/local/startup.log

#install plv8
wget https://github.com/plv8/plv8/archive/v2.0.0.tar.gz
tar -xvzf v2.0.0.tar.gz
cd plv8-2.0.0
make static
sudo cp plv8.so /usr/lib/postgresql/9.6/lib/
sudo cp plv8.control /usr/share/postgresql/9.6/extension/
sudo cp plv8--2.0.0.sql /usr/share/postgresql/9.6/extension/
echo "installed plv8" >> /usr/local/startup.log
echo "" >> /usr/local/startup.log

# download patroni
sudo apt-get --assume-yes -qq install unzip
echo "apt-get unzip exited with: $0"
cd /usr/local
sudo wget -O /usr/local/patroni-master.zip https://github.com/zalando/patroni/archive/master.zip
sudo unzip patroni-master.zip
cd patroni-master
echo "download patroni" >> /usr/local/startup.log
echo "" >> /usr/local/startup.log

# write configuration
sudo touch $patroniCfg
sudo chmod 666 $patroniCfg
echo "scope: &scope $clusterName" >> $patroniCfg
echo "ttl: &ttl 30" >> $patroniCfg
echo "loop_wait: &loop_wait 10" >> $patroniCfg
if [ $myIndex -eq 0 ]
  then
    echo "name: postgres$myIndex" >> $patroniCfg
fi
echo "restapi:" >> $patroniCfg
echo "  listen: 10.0.101.$(($myIndex + 10)):8008" >> $patroniCfg
echo "  connect_address: 10.0.101.$(($myIndex + 10)):8008" >> $patroniCfg
echo "" >> $patroniCfg
echo "zookeeper:" >> $patroniCfg
echo "  scope: *scope" >> $patroniCfg
echo "  session_timeout: *ttl" >> $patroniCfg
echo "  reconnect_timeout: *loop_wait" >> $patroniCfg
echo "  hosts:" >> $patroniCfg
i=0
while [ $i -lt $amountZooKeepers ]
do
  echo "    - 10.0.100.$(($i + 10)):2181" >> $patroniCfg
  i=$(($i+1))
done
echo "" >> $patroniCfg
if [ $myIndex -eq 0 ]
  then
    echo "bootstrap:" >> $patroniCfg
    echo "  dcs:"  >> $patroniCfg
    echo "    ttl: *ttl" >> $patroniCfg
    echo "    loop_wait: *loop_wait" >> $patroniCfg
    echo "    retry_timeout: *loop_wait" >> $patroniCfg
    echo "    maximum_lag_on_failover: 1048576" >> $patroniCfg
    echo "    postgresql:" >> $patroniCfg
    echo "      use_pg_rewind: true" >> $patroniCfg
    echo "      use_slots: true" >> $patroniCfg
    echo "      parameters:" >> $patroniCfg
    echo "        archive_mode: \"on\"" >> $patroniCfg
    echo "        archive_timeout: 1800s" >> $patroniCfg
    echo "        archive_command: mkdir -p ../wal_archive && test ! -f ../wal_archive/%f && cp %p ../wal_archive/%f" >> $patroniCfg
    echo "      recovery_conf:" >> $patroniCfg
    echo "        restore_command: cp ../wal_archive/%f %p" >> $patroniCfg
    echo "  initdb:" >> $patroniCfg
    echo "  - encoding: UTF8" >> $patroniCfg
    echo "  - data-checksums" >> $patroniCfg
    echo "  pg_hba:" >> $patroniCfg
    echo "  - host replication all 0.0.0.0/0 md5" >> $patroniCfg
    echo "  - host all all 0.0.0.0/0 md5" >> $patroniCfg
    echo "  users:" >> $patroniCfg
    echo "    admin:" >> $patroniCfg
    echo "      password: \"$adminPassword\"" >> $patroniCfg
    echo "      options:" >> $patroniCfg
    echo "        - createrole" >> $patroniCfg
    echo "        - createdb" >> $patroniCfg
fi
echo "" >> $patroniCfg
echo "tags:" >> $patroniCfg
echo "  nofailover: false" >> $patroniCfg
echo "  noloadbalance: false" >> $patroniCfg
echo "  clonefrom: false" >> $patroniCfg
echo "" >> $patroniCfg
echo "postgresql:" >> $patroniCfg
if [ $myIndex -ne 0 ]
  then
    echo "  name: postgres$myIndex" >> $patroniCfg
fi
echo "  listen: '*:5433'" >> $patroniCfg
echo "  connect_address: 10.0.101.$(($myIndex + 10)):5433" >> $patroniCfg
echo "  data_dir: /media/data1/data/postgresql" >> $patroniCfg
echo "  bin_dir: /usr/lib/postgresql/9.6/bin" >> $patroniCfg
echo "  pgpass: /tmp/pgpass" >> $patroniCfg
if [ $myIndex -ne 0 ]
  then
    echo "  maximum_lag_on_failover: 1048576" >> $patroniCfg
    echo "  use_slots: true" >> $patroniCfg
    echo "  initdb:" >> $patroniCfg
    echo "    - encoding: UTF8" >> $patroniCfg
    echo "    - data-checksums" >> $patroniCfg
    echo "  pg_rewind:" >> $patroniCfg
    echo "    username: postgres" >> $patroniCfg
    echo "    password: \"$adminPassword\"" >> $patroniCfg
    echo "  pg_hba:" >> $patroniCfg
    echo "    - host replication all 0.0.0.0/0 md5" >> $patroniCfg
    echo "    - host all all 0.0.0.0/0 md5" >> $patroniCfg
    echo "  replication:" >> $patroniCfg
    echo "    username: replicator" >> $patroniCfg
    echo "    password: \"$adminPassword\"" >> $patroniCfg
    echo "  superuser:" >> $patroniCfg
    echo "    username: postgres" >> $patroniCfg
    echo "    password: \"$adminPassword\"" >> $patroniCfg
    echo "  admin:" >> $patroniCfg
    echo "    username: admin" >> $patroniCfg
    echo "    password: \"$adminPassword\"" >> $patroniCfg
    echo "  create_replica_method:" >> $patroniCfg
    echo "    - basebackup" >> $patroniCfg
    echo "  recovery_conf:" >> $patroniCfg
    echo "    restore_command: cp ../wal_archive/%f %p" >> $patroniCfg
    echo "  parameters:" >> $patroniCfg
    echo "    archive_mode: \"on\"" >> $patroniCfg
    echo "    wal_level: hot_standby" >> $patroniCfg
    echo "    archive_command: mkdir -r ../wal_archive && test ! -f ../wal_archive/%f && cp %cp ../wal_archive/%f" >> $patroniCfg
    echo "    max_wal_senders: 10" >> $patroniCfg
    echo "    wal_keep_segments: 8" >> $patroniCfg
    echo "    archive_timeout: 1800s" >> $patroniCfg
    echo "    max_replication_slots: 10" >> $patroniCfg
    echo "    hot_standby: \"on\"" >> $patroniCfg
    echo "    wal_log_hints: \"on\"" >> $patroniCfg
    echo "    unix_socket_directories: '.'" >> $patroniCfg
  else
    echo "  authentication:" >> $patroniCfg
    echo "    replication:" >> $patroniCfg
    echo "      username: replicator" >> $patroniCfg
    echo "      password: \"$adminPassword\"" >> $patroniCfg
    echo "    superuser:" >> $patroniCfg
    echo "      username: postgres" >> $patroniCfg
    echo "      password: \"$adminPassword\"" >> $patroniCfg
    echo "  parameters:" >> $patroniCfg
    echo "    unix_socket_directories: '.'" >> $patroniCfg
fi
echo "setup patroni configuration" >> /usr/local/startup.log
echo "" >> /usr/local/startup.log


# install HA PROXY
sudo apt-get --assume-yes install haproxy
# write configuration
sudo touch $hacfgFile
sudo chmod 666 $hacfgFile
echo "global" >> $hacfgFile
echo "    maxconn 100" >> $hacfgFile
echo "" >> $hacfgFile
echo "defaults" >> $hacfgFile
echo "    log     global" >> $hacfgFile
echo "    mode    tcp" >> $hacfgFile
echo "    retries 2" >> $hacfgFile
echo "    timeout client 30m" >> $hacfgFile
echo "    timeout connect 4s" >> $hacfgFile
echo "    timeout server 30m" >> $hacfgFile
echo "    timeout check 5s" >> $hacfgFile
echo "" >> $hacfgFile
echo "frontend ft_postgresql" >> $hacfgFile
echo "    bind *:5000" >> $hacfgFile
echo "    default_backend bk_db" >> $hacfgFile
echo "" >> $hacfgFile
echo "backend bk_db" >> $hacfgFile
echo "    option httpchk" >> $hacfgFile
echo "" >> $hacfgFile
i=0
while [ $i -lt $amountPostgres ]
do
  echo "  server Postgres$i 10.0.101.$(($i + 10)):5433 maxconn 100 check port 8008" >> $hacfgFile
  i=$(($i+1))
done
echo "installed haproxy" >> /usr/local/startup.log
echo "" >> /usr/local/startup.log

# start ha as deamon
sudo haproxy -D -f $hacfgFile
echo "started haproxy" >> /usr/local/startup.log
echo "" >> /usr/local/startup.log

# prepare patroni to restart after reboot
sudo touch /etc/systemd/system/patroni.service
sudo chmod 777 /etc/systemd/system/patroni.service
echo "[Unit]" > /etc/systemd/system/patroni.service
echo "Description=patroni script" >> /etc/systemd/system/patroni.service
echo "" >> /etc/systemd/system/patroni.service
echo "[Service]" >> /etc/systemd/system/patroni.service
echo "User=$adminUsername" >> /etc/systemd/system/patroni.service
echo "WorkingDirectory=usr/local/patroni-master" >> /etc/systemd/system/patroni.service
echo "ExecStart=/usr/bin/python /usr/local/patroni-master/patroni.py /usr/local/patroni-master/postgres.yml >> /usr/local/startup.log" >> /etc/systemd/system/patroni.service
echo "Restart=always" >> /etc/systemd/system/patroni.service
echo "" >> /etc/systemd/system/patroni.service
echo "[Install]" >> /etc/systemd/system/patroni.service
echo "WantedBy=multi-user.target" >> /etc/systemd/system/patroni.service
sudo systemctl enable patroni.service
echo "setup reboot script for patroni" >> /usr/local/startup.log
echo "" >> /usr/local/startup.log

# start patroni
sudo systemctl start patroni.service
echo "started patroni" >> /usr/local/startup.log
echo "" >> /usr/local/startup.log