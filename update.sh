#!/bin/bash

wget https://github.com/zcore-coin/zcore-2.0/releases/download/v2.0.1/zcore-2.0.1-x86_64-linux-gnu.tar.gz

service worker01 stop

tar -xzvf zcore-2.0.1-x86_64-linux-gnu.tar.gz
cd zcore-2.0.1/
cp * /usr/local/ -a
rm -rf /home/worker01/.zcore/peers.dat

service worker01 start
sleep 5

runuser -l worker01 -c 'zcore-cli getinfo'
