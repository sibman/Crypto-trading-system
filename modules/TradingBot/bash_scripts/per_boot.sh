#!bin/bash
cd /home/ec2-user/trading_bot/
sudo aws s3 cp /home/ec2-user/trading_bot/info.log s3://bucket-phrase-5/logs/info.log
python3 __main__.py
