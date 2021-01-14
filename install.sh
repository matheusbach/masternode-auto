#!/bin/bash

TMP_FOLDER=$(mktemp -d)
NAME_COIN="ZCore"
GIT_REPO="https://github.com/zcore-coin/zcore-source.git"

FILE_BIN="zcore-2.0.2.2-x86_64-linux-gnu.tar.gz"
BIN_DOWN="https://github.com/zcore-coin/zcore-2.0/releases/download/v2.0.2.2/${FILE_BIN}"
#GIT_SENT="https://github.com/zcore-coin/sentinel.git"
FOLDER_BIN="zcore-2.0.2"


BINARY_FILE="zcored"
BINARY_CLI="/usr/local/bin/zcore-cli"
BINARY_CLI_FILE="zcore-cli"
BINARY_PATH="/usr/local/bin/${BINARY_FILE}"
DIR_COIN=".zcr"
CONFIG_FILE="zcore.conf"
DEFULT_PORT=17293

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function prepare_system() {

	echo -e "Prepare the system to install ${NAME_COIN} master node."
	apt-get update 
	DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade 
	apt install -y software-properties-common 
	echo -e "${GREEN}Adding bitcoin PPA repository"
	apt-add-repository -y ppa:bitcoin/bitcoin 
	echo -e "Installing required packages, it may take some time to finish.${NC}"
	apt-get update
	apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
	build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
	libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget pwgen curl libdb4.8-dev bsdmainutils \
	libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw fail2ban pwgen libzmq3-dev autotools-dev pkg-config libevent-dev libboost-all-dev python-virtualenv virtualenv
	clear
	if [ "$?" -gt "0" ];
	  then
	    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
	    echo "apt-get update"
	    echo "apt -y install software-properties-common"
	    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
	    echo "apt-get update"
	    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
	libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git pwgen curl libdb4.8-dev \
	bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw fail2ban pwgen libzmq3-dev autotools-dev pkg-config libevent-dev libboost-all-dev python-virtualenv virtualenv"
	 exit 1
	fi

	clear
	echo -e "Checking if swap space is needed."
	PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
	if [ "$PHYMEM" -lt "2" ];
	  then
	    echo -e "${GREEN}Server is running with less than 2G of RAM, creating 2G swap file.${NC}"
	    dd if=/dev/zero of=/swapfile bs=1024 count=2M
	    chmod 600 /swapfile
	    mkswap /swapfile
	    swapon -a /swapfile
	else
	  echo -e "${GREEN}Server running with at least 2G of RAM, no swap needed.${NC}"
	fi
	clear
}

function checks() {
	if [[ $(lsb_release -d) != *16.04* ]]; then
	  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
	  exit 1
	fi

	if [[ $EUID -ne 0 ]]; then
	   echo -e "${RED}$0 must be run as root.${NC}"
	   exit 1
	fi

	if [ -n "$(pidof ${BINARY_FILE})" ]; then
	  echo -e "${GREEN}\c"
	  read -e -p "${NAME_COIN} is already running. Do you want to add another MN? [Y/N]" ISNEW
	  echo -e "{NC}"
	  clear
	else
	  ISNEW="new"
	fi
}

function compile_server() {
  	echo -e "Clone git repo and compile it. This may take some time. Press a key to continue."
	
	wget $BIN_DOWN -P $TMP_FOLDER
	cd $TMP_FOLDER
	tar -xzvf $FILE_BIN
	cd $FOLDER_BIN
	cp * /usr/local/ -a

	#read -n 1 -s -r -p ""

	#git clone $GIT_REPO $TMP_FOLDER
	#cd $TMP_FOLDER

	#./autogen.sh
	#./configure
	#make

	#cp -a $TMP_FOLDER/src/$BINARY_FILE $BINARY_PATH
	#cp -a $TMP_FOLDER/src/$BINARY_CLI_FILE $BINARY_CLI
  clear
}

function ask_user() {
	  DEFAULT_USER="worker01"
	  read -p "${NAME_COIN} user: " -i $DEFAULT_USER -e WORKER
	  : ${WORKER:=$DEFAULT_USER}

	  if [ -z "$(getent passwd $WORKER)" ]; then
	    useradd -m $WORKER
	    USERPASS=$(pwgen -s 12 1)
	    echo "$WORKER:$USERPASS" | chpasswd

	    HOME_WORKER=$(sudo -H -u $WORKER bash -c 'echo $HOME')
	    DEFAULT_FOLDER="$HOME_WORKER/${DIR_COIN}"
	    read -p "Configuration folder: " -i $DEFAULT_FOLDER -e WORKER_FOLDER
	    : ${WORKER_FOLDER:=$DEFAULT_FOLDER}
	    mkdir -p $WORKER_FOLDER
	    chown -R $WORKER: $WORKER_FOLDER >/dev/null
	  else
	    clear
	    echo -e "${RED}User exits. Please enter another username: ${NC}"
	    ask_user
	  fi
}

function check_port() {
	  declare -a PORTS
	  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
	  ask_port

	  while [[ ${PORTS[@]} =~ $PORT_COIN ]] || [[ ${PORTS[@]} =~ $[PORT_COIN+1] ]]; do
	    clear
	    echo -e "${RED}Port in use, please choose another port:${NF}"
	    ask_port
	  done
}


function ask_port() {
	read -p "${NAME_COIN} Port: " -i $DEFULT_PORT -e PORT_COIN
	: ${PORT_COIN:=$DEFULT_PORT}
}


function create_config() {
	RPCUSER=$(pwgen -s 8 1)
	RPCPASSWORD=$(pwgen -s 15 1)
cat << EOF > $WORKER_FOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$[PORT_COIN+1]
listen=1
server=1
daemon=1
port=$PORT_COIN
EOF
}

function create_key() {
	  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
	  read -e KEY_COIN
	  if [[ -z "$KEY_COIN" ]]; then
	  sudo -u $WORKER $BINARY_PATH -conf=$WORKER_FOLDER/$CONFIG_FILE -datadir=$WORKER_FOLDER
	  sleep 15
	  if [ -z "$(pidof ${BINARY_FILE})" ]; then
	   echo -e "${RED}${NAME_COIN} server couldn't start. Check /var/log/syslog for errors.{$NC}"
	   exit 1
	  fi
	  KEY_COIN=$(sudo -u $WORKER $BINARY_CLI -conf=$WORKER_FOLDER/$CONFIG_FILE -datadir=$WORKER_FOLDER masternode genkey)
	  sudo -u $WORKER $BINARY_CLI -conf=$WORKER_FOLDER/$CONFIG_FILE -datadir=$WORKER_FOLDER stop
	  fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $WORKER_FOLDER/$CONFIG_FILE
  NODEIP=$(curl -s4 icanhazip.com)
  cat << EOF >> $WORKER_FOLDER/$CONFIG_FILE
logtimestamps=1
maxconnections=256
masternode=1
externalip=$NODEIP:$PORT_COIN
masternodeprivkey=$KEY_COIN
addnode=[2001:19f0:ac01:116f:5400:3ff:fe14:78c5]:17293
addnode=[2001:41d0:800:1a6d:1c00::22]:17293
addnode=[2a01:4f9:4b:1a8a::242]:17293
addnode=[2a02:c205:2028:7943::2]:17293
addnode=[2a02:c207:2043:2116::19]:17293
addnode=135.181.114.181:50342
addnode=138.201.192.203:45826
addnode=144.91.124.2:40738
addnode=144.91.124.2:49826
addnode=144.91.64.31:17293
addnode=144.91.65.121:59798
addnode=144.91.65.131:59276
addnode=144.91.65.201:57652
addnode=144.91.66.140:50214
addnode=144.91.78.23:52870
addnode=144.91.78.24:39472
addnode=144.91.78.27:50498
addnode=161.97.125.4:33468
addnode=164.68.100.133:48694
addnode=164.68.100.208:38178
addnode=164.68.103.60:42710
addnode=164.68.105.184:54136
addnode=164.68.105.189:43942
addnode=164.68.107.91:53538
addnode=164.68.113.172:17293
addnode=164.68.114.64:34730
addnode=164.68.96.198:40528
addnode=164.68.98.146:56680
addnode=164.68.99.209:53480
addnode=164.68.99.211:48432
addnode=164.68.99.213:57790
addnode=164.68.99.214:39656
addnode=167.86.103.157:37598
addnode=167.86.103.158:56880
addnode=167.86.103.160:34468
addnode=167.86.103.162:55434
addnode=167.86.103.166:60204
addnode=167.86.103.167:32910
addnode=167.86.106.183:41286
addnode=167.86.106.183:57154
addnode=167.86.106.212:44058
addnode=167.86.106.244:38040
addnode=167.86.107.11:17293
addnode=167.86.107.226:41586
addnode=167.86.107.230:55170
addnode=167.86.107.9:40618
addnode=167.86.113.138:34400
addnode=167.86.113.200:48654
addnode=167.86.115.19:55612
addnode=167.86.115.202:56002
addnode=167.86.115.205:51406
addnode=167.86.115.206:46530
addnode=167.86.115.21:40318
addnode=167.86.120.125:44250
addnode=167.86.120.131:51808
addnode=167.86.120.132:40084
addnode=167.86.120.33:43384
addnode=167.86.123.170:35858
addnode=167.86.125.119:37092
addnode=167.86.125.167:45178
addnode=167.86.125.185:48526
addnode=167.86.125.242:44558
addnode=167.86.125.249:40524
addnode=167.86.125.80:47276
addnode=167.86.126.117:40010
addnode=167.86.127.215:49922
addnode=167.86.69.69:47032
addnode=167.86.76.239:60610
addnode=167.86.77.21:47444
addnode=167.86.96.134:60312
addnode=167.86.96.198:53842
addnode=167.86.96.200:52942
addnode=173.212.194.224:56028
addnode=173.212.196.224:60284
addnode=173.212.198.65:41124
addnode=173.212.201.15:37984
addnode=173.212.207.52:57086
addnode=173.212.208.102:46792
addnode=173.212.215.124:42942
addnode=173.212.215.150:58302
addnode=173.212.215.204:58896
addnode=173.212.217.124:47382
addnode=173.212.218.39:17293
addnode=173.212.226.248:55304
addnode=173.212.239.104:42132
addnode=173.212.240.125:34948
addnode=173.212.242.205:33850
addnode=173.249.10.201:46028
addnode=173.249.13.165:40022
addnode=173.249.14.174:39032
addnode=173.249.14.74:17293
addnode=173.249.19.104:44416
addnode=173.249.30.47:35730
addnode=173.249.33.133:52256
addnode=173.249.46.58:52108
addnode=177.103.138.249:64509
addnode=178.238.236.223:42940
addnode=178.238.236.223:57316
addnode=185.2.100.187:39202
addnode=185.2.100.187:56972
addnode=185.2.100.56:33228
addnode=185.2.103.59:17293
addnode=185.244.193.249:48772
addnode=207.148.24.193:56914
addnode=207.180.230.81:17293
addnode=45.77.220.117:38470
addnode=46.164.238.140:54956
addnode=5.189.162.120:51792
addnode=5.189.170.32:17293
addnode=62.171.141.130:39496
addnode=62.171.189.163:34598
addnode=78.47.228.146:60220
addnode=79.143.185.27:38214
addnode=79.143.186.4:36124
addnode=79.143.186.4:57206
addnode=8.6.193.216:17293
addnode=80.241.211.189:51928
addnode=80.241.211.189:59168
addnode=80.241.213.249:56080
addnode=80.241.213.26:40462
addnode=80.241.213.26:57812
addnode=80.241.214.206:44940
addnode=80.241.222.50:47538
addnode=80.241.223.81:17293
addnode=82.155.53.190:40050
addnode=82.99.131.218:61457
addnode=85.214.71.46:17293
addnode=86.57.164.166:44926
addnode=95.216.38.85:49778
addnode=95.217.145.114:39396
EOF
  chown -R $WORKER: $WORKER_FOLDER >/dev/null
}

function enable_firewall() {
  echo -e "Installing ${GREEN}fail2ban${NC} and setting up firewall to allow ingress on port ${GREEN}$PORT_COIN${NC}"
  ufw allow $PORT_COIN/tcp comment "${NAME_COIN} MN port" >/dev/null
  ufw allow $[PORT_COIN+1]/tcp comment "${NAME_COIN} RPC port" >/dev/null
  ufw allow ssh >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl start fail2ban >/dev/null 2>&1
}

function systemd_up() {
  cat << EOF > /etc/systemd/system/$WORKER.service
[Unit]
Description=${NAME_COIN} service
After=network.target
[Service]
Type=forking
User=$WORKER
Group=$WORKER
WorkingDirectory=$WORKER_FOLDER
ExecStart=$BINARY_PATH -daemon
ExecStop=$BINARY_PATH stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
  
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $WORKER.service
  systemctl enable $WORKER.service >/dev/null 2>&1

  if [[ -z "$(pidof ${BINARY_FILE})" ]]; then
    echo -e "${RED}${NAME_COIN} is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo "systemctl start $WORKER.service"
    echo "systemctl status $WORKER.service"
    echo "less /var/log/syslog"
    exit 1
  fi
}

function install_sentinel() {
	runuser -l worker01 -c 'cd /home/worker01/'
	runuser -l worker01 -c "git clone ${GIT_SENT} /home/worker01/sentinel-zcr"
	runuser -l worker01 -c 'virtualenv /home/worker01/sentinel-zcr/venv'
	runuser -l worker01 -c '/home/worker01/sentinel-zcr/venv/bin/pip install -r /home/worker01/sentinel-zcr/requirements.txt'
	runuser -l worker01 -c 'crontab -l > mycron'
	runuser -l worker01 -c 'echo "* * * * * cd /home/worker01/sentinel-zcr && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" >> mycron'
	runuser -l worker01 -c 'crontab mycron'
	runuser -l worker01 -c 'rm mycron'
}


function resumen() {
 echo
 echo -e "================================================================================================================================"
 echo -e "${NAME_COIN} Masternode is up and running as user ${GREEN}$WORKER${NC} and it is listening on port ${GREEN}$PORT_COIN${NC}."
 echo -e "${GREEN}$WORKER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$WORKER_FOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $WORKER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $WORKER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$PORT_COIN${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$KEY_COIN${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
	ask_user
	check_port
	create_config
	create_key
	update_config
	enable_firewall
	#install_sentinel
	systemd_up
	resumen
}

######################################################
#                      Main Script                   #
######################################################

clear

checks
if [[ ("$ISNEW" == "y" || "$ISNEW" == "Y") ]]; then
  setup_node
  exit 0
elif [[ "$ISNEW" == "new" ]]; then
  prepare_system
  compile_server
  setup_node
else
  echo -e "${GREEN}${NAME_COIN} already running.${NC}"
  exit 0
fi
