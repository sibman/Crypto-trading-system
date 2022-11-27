#!/bin/bash
sudo yum update -y
pip3 install boto3 python-binance pandas awswrangler websocket-client pandas_ta
cd /home/ec2-user/
sudo aws s3 cp s3://bucket-phrase-5/trading_bot.zip /home/ec2-user/trading_bot.zip 
sudo chmod u+x trading_bot.zip 
sudo unzip /home/ec2-user/trading_bot.zip
cd trading_bot && chmod +x __main__.py
sudo aws s3 cp s3://bucket-phrase-5/reboot_bash/per_boot.sh /var/lib/cloud/scripts/per-boot/per_boot.sh
cd /var/lib/cloud/scripts/per-boot/ 
sudo chmod u+x per_boot.sh