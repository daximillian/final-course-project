#!/usr/bin/env bash

curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.4.2-amd64.deb
sudo dpkg -i filebeat-6.4.2-amd64.deb

sudo mv /home/ubuntu/filebeat.yml /etc/filebeat/filebeat.yml
sudo mv /home/ubuntu/system.yml /etc/filebeat/modules.d/system.yml
sudo mv /home/ubuntu/mysql.yml /etc/filebeat/modules.d/mysql.yml

sudo systemctl enable filebeat.service
sudo systemctl start filebeat.service

sudo filebeat modules enable system mysql
