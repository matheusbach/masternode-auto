#!/bin/bash

wget https://github.com/zcore-coin/zcore-source/releases/download/v1.6.3/zcore-1.6.3-x86_64-linux-gnu.tar.gz

service worker01 stop

tar -xzvf zcore-1.6.3-x86_64-linux-gnu.tar.gz
cd zcore-1.6.3/
cp * /usr/local/ -a
rm -rf /home/worker01/.zcore/peers.dat

service worker01 start
sleep 5

runuser -l worker01 -c 'zcore-cli getinfo'
