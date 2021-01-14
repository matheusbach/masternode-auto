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
addnode=178.238.230.211:17293
addnode=94.177.173.41:17293
addnode=178.238.226.11:17293
addnode=167.86.125.205:17293
addnode=5.189.141.44:17293
addnode=167.86.115.208:17293
addnode=93.186.253.109:17293
addnode=79.143.177.101:17293
addnode=91.205.173.115:17293
addnode=89.46.74.202:17293
addnode=167.86.125.185:17293
addnode=79.143.190.139:17293
addnode=212.237.13.253:17293
addnode=5.189.159.86:17293
addnode=164.68.113.168:17293
addnode=167.86.107.228:17293
addnode=79.143.183.76:17293
addnode=173.212.215.168:17293
addnode=164.68.103.125:17293
addnode=173.249.14.93:17293
addnode=80.211.232.85:17293
addnode=80.211.39.126:17293
addnode=80.211.165.209:17293
addnode=80.211.82.126:17293
addnode=212.237.34.51:17293
addnode=94.177.207.161:17293
addnode=194.182.68.213:17293
addnode=173.212.234.218:17293
addnode=164.68.107.77:17293
addnode=144.91.65.38:17293
addnode=80.211.109.91:17293
addnode=79.143.185.27:17293
addnode=173.212.241.150:17293
addnode=80.241.222.186:17293
addnode=212.237.58.25:17293
addnode=5.249.147.119:17293
addnode=5.189.132.77:17293
addnode=164.68.105.188:17293
addnode=194.182.87.166:17293
addnode=194.182.80.119:17293
addnode=80.211.195.29:17293
addnode=207.180.229.109:17293
addnode=173.249.31.232:17293
addnode=167.86.120.33:17293
addnode=173.249.10.199:17293
addnode=5.189.131.40:17293
addnode=85.255.1.226:17293
addnode=195.181.212.200:17293
addnode=217.61.110.121:17293
addnode=167.86.127.216:17293
addnode=94.177.224.40:17293
addnode=217.61.110.199:17293
addnode=217.61.110.123:17293
addnode=217.61.110.143:17293
addnode=217.61.110.92:17293
addnode=217.61.110.253:17293
addnode=217.61.110.170:17293
addnode=217.61.110.51:17293
addnode=217.61.110.31:17293
addnode=217.61.110.231:17293
addnode=217.61.110.84:17293
addnode=217.61.110.17:17293
addnode=5.189.183.56:17293
addnode=80.211.117.219:17293
addnode=80.211.117.19:17293
addnode=80.211.54.89:17293
addnode=80.211.117.102:17293
addnode=80.211.117.18:17293
addnode=80.211.17.76:17293
addnode=80.211.13.10:17293
addnode=80.211.5.213:17293
addnode=80.211.24.144:17293
addnode=5.189.129.214:17293
addnode=80.211.87.92:17293
addnode=217.61.15.94:17293
addnode=144.91.78.26:17293
addnode=89.40.112.137:17293
addnode=94.177.241.12:17293
addnode=94.177.233.9:17293
addnode=94.177.234.17:17293
addnode=144.91.64.30:17293
addnode=80.211.137.132:17293
addnode=5.189.134.148:17293
addnode=80.211.189.11:17293
addnode=80.211.148.231:17293
addnode=89.46.79.161:17293
addnode=217.61.14.71:17293
addnode=80.211.167.115:17293
addnode=217.61.124.82:17293
addnode=217.61.125.16:17293
addnode=89.46.78.40:17293
addnode=94.177.179.64:17293
addnode=94.177.180.47:17293
addnode=167.86.115.202:17293
addnode=89.46.78.237:17293
addnode=167.86.125.167:17293
addnode=178.238.234.226:17293
addnode=164.68.108.204:17293
addnode=164.68.109.253:17293
addnode=207.180.244.17:17293
addnode=167.86.103.164:17293
addnode=167.86.103.159:17293
addnode=173.212.239.134:17293
addnode=167.86.105.182:17293
addnode=89.46.73.115:17293
addnode=89.46.78.240:17293
addnode=185.2.100.187:17293
addnode=164.68.103.60:17293
addnode=217.61.125.211:17293
addnode=80.211.90.128:17293
addnode=89.46.75.215:17293
addnode=217.61.124.143:17293
addnode=217.61.125.36:17293
addnode=94.177.179.185:17293
addnode=94.177.180.242:17293
addnode=80.241.212.249:17293
addnode=94.177.180.16:17293
addnode=173.212.198.137:17293
addnode=80.211.182.215:17293
addnode=93.104.214.200:17293
addnode=178.238.235.136:17293
addnode=212.237.30.59:17293
addnode=167.86.125.80:17293
addnode=213.136.86.223:17293
addnode=94.177.179.54:17293
addnode=89.46.78.176:17293
addnode=164.68.123.175:17293
addnode=178.238.228.23:17293
addnode=173.212.233.240:17293
addnode=195.181.212.119:17293
addnode=164.68.103.58:17293
addnode=164.68.103.61:17293
addnode=5.189.155.83:17293
addnode=213.136.92.168:17293
addnode=89.46.73.214:17293
addnode=89.46.74.141:17293
addnode=89.46.75.118:17293
addnode=217.61.120.91:17293
addnode=217.61.121.216:17293
addnode=89.46.79.23:17293
addnode=217.61.124.22:17293
addnode=217.61.125.195:17293
addnode=89.46.78.31:17293
addnode=217.61.15.82:17293
addnode=5.249.154.224:17293
addnode=5.249.155.195:17293
addnode=5.249.159.7:17293
addnode=89.46.73.127:17293
addnode=80.241.212.3:17293
addnode=164.68.100.208:17293
addnode=80.241.214.36:17293
addnode=178.238.232.158:17293
addnode=89.46.75.157:17293
addnode=5.249.154.27:17293
addnode=173.249.8.149:17293
addnode=164.68.105.182:17293
addnode=164.68.99.13:17293
addnode=167.86.115.200:17293
addnode=167.86.124.32:17293
addnode=173.249.28.200:17293
addnode=80.241.221.62:17293
addnode=80.241.208.211:17293
addnode=144.91.64.33:17293
addnode=167.86.122.166:17293
addnode=173.212.230.40:17293
addnode=212.237.32.251:17293
addnode=217.61.15.81:17293
addnode=89.46.75.58:17293
addnode=89.36.214.104:17293
addnode=89.40.114.237:17293
addnode=89.46.75.227:17293
addnode=89.46.78.65:17293
addnode=89.46.79.133:17293
addnode=217.61.97.235:17293
addnode=217.61.98.132:17293
addnode=217.61.97.61:17293
addnode=5.249.151.199:17293
addnode=89.46.75.160:17293
addnode=89.46.75.94:17293
addnode=89.46.75.84:17293
addnode=89.46.75.183:17293
addnode=89.46.75.190:17293
addnode=89.46.79.89:17293
addnode=94.177.179.32:17293
addnode=94.177.179.240:17293
addnode=93.186.251.126:17293
addnode=94.177.179.60:17293
addnode=94.177.179.242:17293
addnode=94.177.234.241:17293
addnode=144.91.65.131:17293
addnode=3.83.189.205:17293
addnode=213.136.92.19:17293
addnode=173.212.240.125:17293
addnode=54.162.78.113:17293
addnode=167.86.120.31:17293
addnode=18.207.206.170:17293
addnode=94.177.217.81:17293
addnode=173.249.18.2:17293
addnode=79.143.185.136:17293
addnode=54.175.236.239:17293
addnode=167.86.123.169:17293
addnode=144.91.65.235:17293
addnode=144.91.78.27:17293
addnode=173.249.57.83:17293
addnode=94.177.224.93:17293
addnode=164.68.107.75:17293
addnode=164.68.98.146:17293
addnode=93.104.213.102:17293
addnode=167.86.107.11:17293
addnode=164.68.113.175:17293
addnode=173.212.215.209:17293
addnode=173.212.215.150:17293
addnode=79.143.190.144:17293
addnode=178.238.224.135:17293
addnode=173.212.226.199:17293
addnode=167.86.122.194:17293
addnode=207.180.253.212:17293
addnode=217.61.106.91:17293
addnode=173.212.226.248:17293
addnode=173.249.10.202:17293
addnode=91.194.91.46:17293
addnode=207.180.244.67:17293
addnode=178.238.234.4:17293
addnode=173.212.196.224:17293
addnode=164.68.100.133:17293
addnode=167.86.120.131:17293
addnode=207.180.228.250:17293
addnode=173.249.24.209:17293
addnode=5.189.150.193:17293
addnode=173.249.13.94:17293
addnode=173.249.55.173:17293
addnode=5.189.180.31:17293
addnode=178.238.226.29:17293
addnode=173.212.235.35:17293
addnode=178.238.236.223:17293
addnode=173.212.199.71:17293
addnode=207.180.232.91:17293
addnode=167.86.103.168:17293
addnode=164.68.107.91:17293
addnode=80.211.136.157:17293
addnode=173.212.211.53:17293
addnode=167.86.113.138:17293
addnode=167.86.69.69:17293
addnode=173.249.21.112:17293
addnode=217.61.120.171:17293
addnode=167.86.107.227:17293
addnode=5.189.191.37:17293
addnode=167.86.107.9:17293
addnode=167.86.108.93:17293
addnode=167.86.123.171:17293
addnode=5.189.162.247:17293
addnode=79.143.187.228:17293
addnode=18.223.196.241:17293
addnode=173.249.14.74:17293
addnode=178.238.236.8:17293
addnode=185.28.100.83:17293
addnode=173.212.213.87:17293
addnode=173.249.32.223:17293
addnode=173.249.56.191:17293
addnode=167.86.127.214:17293
addnode=80.211.82.132:17293
addnode=167.86.106.237:17293
addnode=173.249.43.4:17293
addnode=173.212.215.204:17293
addnode=167.86.120.30:17293
addnode=173.212.213.3:17293
addnode=80.211.188.53:17293
addnode=93.104.211.198:17293
addnode=5.189.146.150:17293
addnode=167.86.115.20:17293
addnode=167.86.113.143:17293
addnode=80.211.112.159:17293
addnode=80.211.84.85:17293
addnode=79.143.181.145:17293
addnode=217.61.124.158:17293
addnode=80.211.112.93:17293
addnode=173.249.37.160:17293
addnode=217.61.110.52:17293
addnode=167.86.127.213:17293
addnode=93.104.213.220:17293
addnode=85.255.9.177:17293
addnode=167.86.119.73:17293
addnode=167.86.125.136:17293
addnode=5.189.181.188:17293
addnode=164.68.109.254:17293
addnode=167.86.76.238:17293
addnode=207.180.243.83:17293
addnode=164.68.100.129:17293
addnode=167.86.88.125:17293
addnode=217.61.108.192:17293
addnode=178.238.225.156:17293
addnode=80.241.212.199:17293
addnode=80.211.70.236:17293
addnode=144.91.65.78:17293
addnode=173.212.213.80:17293
addnode=167.86.115.18:17293
addnode=164.68.103.59:17293
addnode=80.241.222.127:17293
addnode=5.189.172.76:17293
addnode=207.180.232.222:17293
addnode=80.211.11.45:17293
addnode=173.249.42.184:17293
addnode=79.143.188.113:17293
addnode=54.214.199.240:17293
addnode=167.86.99.115:17293
addnode=164.68.103.63:17293
addnode=80.211.142.60:17293
addnode=173.249.44.82:17293
addnode=35.165.69.229:17293
addnode=173.249.44.148:17293
addnode=217.61.14.248:17293
addnode=217.61.108.132:17293
addnode=167.86.127.210:17293
addnode=193.164.133.242:17293
addnode=91.205.172.109:17293
addnode=173.249.25.3:17293
addnode=173.212.194.224:17293
addnode=54.71.220.73:17293
addnode=167.86.107.226:17293
addnode=144.91.78.24:17293
addnode=217.61.107.126:17293
addnode=80.241.221.168:17293
addnode=18.207.244.1:17293
addnode=167.86.103.167:17293
addnode=167.86.103.162:17293
addnode=167.86.125.242:17293
addnode=80.211.111.70:17293
addnode=167.86.90.137:17293
addnode=173.249.13.186:17293
addnode=81.2.243.131:17293
addnode=193.34.144.199:17293
addnode=167.86.120.126:17293
addnode=54.191.161.221:17293
addnode=80.241.209.59:17293
addnode=167.86.112.51:17293
addnode=79.143.189.82:17293
addnode=207.180.232.93:17293
addnode=167.86.84.216:17293
addnode=167.86.80.115:17293
addnode=167.86.103.163:17293
addnode=164.68.100.83:17293
addnode=164.68.100.155:17293
addnode=144.91.65.197:17293
addnode=167.86.120.124:17293
addnode=173.249.45.150:17293
addnode=34.210.212.158:17293
addnode=173.212.198.65:17293
addnode=167.86.91.67:17293
addnode=173.249.40.19:17293
addnode=167.86.125.249:17293
addnode=5.189.169.137:17293
addnode=167.86.123.170:17293
addnode=164.68.113.172:17293
addnode=79.143.186.4:17293
addnode=207.180.245.28:17293
addnode=173.249.31.242:17293
addnode=207.180.230.81:17293
addnode=167.86.103.161:17293
addnode=185.2.103.59:17293
addnode=167.86.122.164:17293
addnode=178.238.239.110:17293
addnode=5.189.170.32:17293
addnode=18.236.249.1:17293
addnode=167.86.125.243:17293
addnode=79.143.188.190:17293
addnode=173.212.211.59:17293
addnode=213.136.86.26:17293
addnode=178.238.236.232:17293
addnode=167.86.120.150:17293
addnode=91.205.173.27:17293
addnode=91.205.173.143:17293
addnode=167.86.120.128:17293
addnode=178.238.228.106:17293
addnode=5.249.154.136:17293
addnode=79.143.188.38:17293
addnode=173.249.27.254:17293
addnode=178.238.228.48:17293
addnode=167.86.96.200:17293
addnode=79.143.187.183:17293
addnode=144.91.64.31:17293
addnode=80.241.209.225:17293
addnode=167.86.96.198:17293
addnode=167.86.107.224:17293
addnode=79.143.185.203:17293
addnode=79.143.177.229:17293
addnode=217.61.108.42:17293
addnode=173.249.44.212:17293
addnode=173.249.12.166:17293
addnode=173.212.237.96:17293
addnode=173.212.248.48:17293
addnode=164.68.96.198:17293
addnode=167.86.106.183:17293
addnode=173.212.203.16:17293
addnode=167.86.106.212:17293
addnode=164.68.105.184:17293
addnode=173.249.33.193:17293
addnode=167.86.103.158:17293
addnode=178.238.235.116:17293
addnode=93.104.208.163:17293
addnode=173.212.222.9:17293
addnode=167.86.126.117:17293
addnode=164.68.110.4:17293
addnode=167.86.120.132:17293
addnode=167.86.123.167:17293
addnode=80.211.179.184:17293
addnode=167.86.103.157:17293
addnode=167.86.88.41:17293
addnode=5.189.173.36:17293
addnode=80.211.88.191:17293
addnode=79.143.188.176:17293
addnode=167.86.125.149:17293
addnode=173.249.13.165:17293
addnode=80.241.211.189:17293
addnode=91.205.173.181:17293
addnode=167.86.93.42:17293
addnode=93.104.210.136:17293
addnode=164.68.103.62:17293
addnode=212.237.9.65:17293
addnode=89.46.75.197:17293
addnode=89.46.79.239:17293
addnode=194.182.77.22:17293
addnode=94.177.236.229:17293
addnode=167.86.127.215:17293
addnode=89.38.149.81:17293
addnode=173.212.228.63:17293
addnode=167.86.115.19:17293
addnode=167.86.83.186:17293
addnode=80.241.217.122:17293
addnode=80.241.222.50:17293
addnode=173.249.45.26:17293
addnode=207.180.220.147:17293
addnode=80.241.223.10:17293
addnode=167.86.102.218:17293
addnode=80.211.48.56:17293
addnode=79.143.182.218:17293
addnode=217.61.120.56:17293
addnode=178.238.225.252:17293
addnode=173.212.230.151:17293
addnode=164.68.109.251:17293
addnode=5.249.144.252:17293
addnode=167.86.107.229:17293
addnode=178.238.238.181:17293
addnode=164.68.113.171:17293
addnode=94.177.180.250:17293
addnode=80.211.3.114:17293
addnode=173.249.49.85:17293
addnode=167.86.77.218:17293
addnode=173.212.226.175:17293
addnode=173.249.46.102:17293
addnode=167.86.75.246:17293
addnode=5.189.128.38:17293
addnode=173.212.223.33:17293
addnode=185.2.100.170:17293
addnode=178.238.236.32:17293
addnode=158.69.62.55:17293
addnode=80.211.59.42:17293
addnode=167.86.105.208:17293
addnode=5.189.166.128:17293
addnode=5.189.169.235:17293
addnode=178.238.229.88:17293
addnode=167.86.79.164:17293
addnode=5.189.162.120:17293
addnode=173.249.38.207:17293
addnode=167.86.107.231:17293
addnode=79.143.189.53:17293
addnode=167.86.113.142:17293
addnode=79.143.189.137:17293
addnode=79.143.181.82:17293
addnode=80.241.220.23:17293
addnode=167.86.98.140:17293
addnode=167.86.115.207:17293
addnode=167.86.113.200:17293
addnode=164.68.98.160:17293
addnode=144.91.78.23:17293
addnode=173.212.219.14:17293
addnode=207.180.232.92:17293
addnode=80.211.169.206:17293
addnode=89.46.73.15:17293
addnode=173.249.29.36:17293
addnode=173.212.253.224:17293
addnode=35.181.52.124:17293
addnode=144.91.64.32:17293
addnode=217.61.107.50:17293
addnode=173.249.18.236:17293
addnode=164.68.103.57:17293
addnode=173.249.42.127:17293
addnode=164.68.113.174:17293
addnode=207.180.253.210:17293
addnode=164.68.113.170:17293
addnode=173.212.222.167:17293
addnode=79.143.189.144:17293
addnode=173.249.10.201:17293
addnode=173.212.219.200:17293
addnode=178.238.233.131:17293
addnode=167.86.96.111:17293
addnode=164.68.105.187:17293
addnode=167.86.76.239:17293
addnode=167.86.125.148:17293
addnode=185.2.100.56:17293
addnode=164.68.105.190:17293
addnode=5.249.154.212:17293
addnode=167.86.84.234:17293
addnode=5.189.181.108:17293
addnode=164.68.105.185:17293
addnode=164.68.105.186:17293
addnode=167.86.125.119:17293
addnode=80.241.213.102:17293
addnode=173.212.201.15:17293
addnode=167.86.123.168:17293
addnode=167.86.115.206:17293
addnode=79.143.190.135:17293
addnode=167.86.115.21:17293
addnode=144.91.65.192:17293
addnode=173.212.227.191:17293
addnode=80.211.91.232:17293
addnode=79.143.190.148:17293
addnode=193.200.241.135:17293
addnode=80.241.212.53:17293
addnode=167.86.125.93:17293
addnode=79.143.187.95:17293
addnode=173.249.38.203:17293
addnode=167.86.120.125:17293
addnode=80.211.186.198:17293
addnode=5.189.160.150:17293
addnode=167.86.115.204:17293
addnode=173.212.213.229:17293
addnode=167.86.115.198:17293
addnode=173.212.249.234:17293
addnode=173.249.33.14:17293
addnode=167.86.103.165:17293
addnode=173.249.8.225:17293
addnode=167.86.107.230:17293
addnode=5.189.182.101:17293
addnode=173.212.246.89:17293
addnode=217.61.14.116:17293
addnode=144.91.78.29:17293
addnode=164.68.99.211:17293
addnode=207.180.213.45:17293
addnode=173.249.40.212:17293
addnode=89.46.74.193:17293
addnode=164.68.99.209:17293
addnode=173.249.54.127:17293
addnode=207.180.243.153:17293
addnode=164.68.113.173:17293
addnode=178.238.238.114:17293
addnode=80.241.220.2:17293
addnode=80.211.230.146:17293
addnode=80.241.209.216:17293
addnode=173.212.208.102:17293
addnode=185.58.193.95:17293
addnode=173.212.217.124:17293
addnode=144.91.64.29:17293
addnode=173.249.44.25:17293
addnode=217.61.110.173:17293
addnode=167.86.96.134:17293
addnode=80.241.213.105:17293
addnode=217.61.124.167:17293
addnode=93.104.211.62:17293
addnode=167.86.77.21:17293
addnode=173.212.253.68:17293
addnode=80.241.212.56:17293
addnode=173.249.45.171:17293
addnode=173.249.5.13:17293
addnode=173.249.54.40:17293
addnode=173.249.46.247:17293
addnode=173.212.209.64:17293
addnode=217.61.121.168:17293
addnode=167.86.115.201:17293
addnode=93.104.215.25:17293
addnode=167.86.125.223:17293
addnode=217.61.120.204:17293
addnode=207.180.232.90:17293
addnode=167.86.122.165:17293
addnode=167.86.115.205:17293
addnode=173.249.46.58:17293
addnode=167.86.120.130:17293
addnode=167.86.125.182:17293
addnode=164.68.99.210:17293
addnode=80.241.214.206:17293
addnode=80.241.220.49:17293
addnode=167.86.120.127:17293
addnode=164.68.99.213:17293
addnode=79.143.189.132:17293
addnode=164.68.99.212:17293
addnode=173.212.209.45:17293
addnode=79.143.189.27:17293
addnode=80.241.220.234:17293
addnode=173.249.55.174:17293
addnode=178.238.224.27:17293
addnode=207.180.253.213:17293
addnode=173.212.222.56:17293
addnode=164.68.98.161:17293
addnode=164.68.99.214:17293
addnode=164.68.103.64:17293
addnode=80.241.213.31:17293
addnode=89.46.73.202:17293
addnode=5.189.170.158:17293
addnode=173.249.34.37:17293
addnode=217.61.15.253:17293
addnode=173.212.215.134:17293
addnode=173.249.34.23:17293
addnode=80.241.221.122:17293
addnode=173.212.215.165:17293
addnode=167.86.106.244:17293
addnode=80.241.212.20:17293
addnode=173.212.217.191:17293
addnode=178.238.229.148:17293
addnode=207.180.243.178:17293
addnode=164.68.105.189:17293
addnode=167.86.125.150:17293
addnode=185.2.100.44:17293
addnode=173.212.239.54:17293
addnode=80.211.167.19:17293
addnode=193.34.144.58:17293
addnode=178.238.224.151:17293
addnode=167.86.120.32:17293
addnode=167.86.127.211:17293
addnode=173.212.207.52:17293
addnode=80.241.209.135:17293
addnode=164.68.96.219:17293
addnode=79.143.190.182:17293
addnode=207.180.220.146:17293
addnode=185.2.101.231:17293
addnode=207.180.241.205:17293
addnode=144.91.76.207:17293
addnode=5.189.180.93:17293
addnode=5.189.154.243:17293
addnode=5.189.167.97:17293
addnode=207.180.253.211:17293
addnode=173.212.214.166:17293
addnode=164.68.107.76:17293
addnode=5.189.130.59:17293
addnode=164.68.99.207:17293
addnode=79.143.189.26:17293
addnode=79.143.189.146:17293
addnode=173.212.223.64:17293
addnode=79.143.189.79:17293
addnode=91.205.173.166:17293
addnode=194.182.76.37:17293
addnode=80.211.184.153:17293
addnode=89.36.215.153:17293
addnode=173.212.222.13:17293
addnode=89.38.151.90:17293
addnode=89.36.212.30:17293
addnode=167.86.105.216:17293
addnode=89.46.75.143:17293
addnode=217.61.124.187:17293
addnode=5.189.184.189:17293
addnode=213.136.86.227:17293
addnode=178.238.229.13:17293
addnode=80.211.114.149:17293
addnode=173.212.208.137:17293
addnode=80.241.214.89:17293
addnode=173.249.49.72:17293
addnode=144.91.65.99:17293
addnode=173.212.242.205:17293
addnode=144.91.65.201:17293
addnode=173.249.32.221:17293
addnode=173.212.222.100:17293
addnode=167.86.87.16:17293
addnode=144.91.65.121:17293
addnode=207.180.230.140:17293
addnode=173.212.228.121:17293
addnode=213.136.90.90:17293
addnode=167.86.103.156:17293
addnode=173.212.205.110:17293
addnode=173.212.237.66:17293
addnode=173.212.193.109:17293
addnode=173.212.239.104:17293
addnode=80.241.209.125:17293
addnode=5.189.158.71:17293
addnode=207.180.214.29:17293
addnode=164.68.123.174:17293
addnode=167.86.115.199:17293
addnode=167.86.127.212:17293
addnode=173.249.14.174:17293
addnode=80.211.176.68:17293
addnode=80.211.71.97:17293
addnode=167.86.115.17:17293
addnode=79.143.179.243:17293
addnode=80.241.213.77:17293
addnode=173.212.218.39:17293
addnode=164.68.103.55:17293
addnode=207.180.244.236:17293
addnode=167.86.103.160:17293
addnode=79.143.181.85:17293
addnode=5.249.159.34:17293
addnode=164.68.99.241:17293
addnode=89.46.75.91:17293
addnode=167.86.120.129:17293
addnode=173.249.55.172:17293
addnode=173.249.6.200:17293
addnode=79.143.180.234:17293
addnode=79.143.181.95:17293
addnode=79.143.187.141:17293
addnode=80.241.209.175:17293
addnode=80.241.209.34:17293
addnode=80.241.212.132:17293
addnode=80.211.82.83:17293
addnode=217.61.14.55:17293
addnode=91.194.90.234:17293
addnode=91.205.174.116:17293
addnode=93.104.215.170:17293
addnode=164.68.106.92:17293
addnode=167.86.107.225:17293
addnode=167.86.115.203:17293
addnode=167.86.125.106:17293
addnode=167.86.125.241:17293
addnode=173.212.217.181:17293
addnode=173.212.215.124:17293
addnode=54.39.99.215:17293
addnode=173.212.215.233:17293
addnode=80.211.137.69:17293
addnode=173.249.27.213:17293
addnode=173.249.19.104:17293
addnode=5.189.191.77:17293
addnode=167.86.120.29:17293
addnode=173.249.29.150:17293
addnode=144.91.78.30:17293
addnode=173.249.32.222:17293
addnode=173.249.33.133:17293
addnode=173.249.33.55:17293
addnode=173.249.4.246:17293
addnode=178.238.238.28:17293
addnode=178.238.226.124:17293
addnode=173.249.9.38:17293
addnode=217.61.14.217:17293
addnode=185.2.101.183:17293
addnode=193.164.132.154:17293
addnode=193.164.132.231:17293
addnode=193.37.152.48:17293
addnode=213.136.71.151:17293
addnode=5.189.133.78:17293
addnode=5.189.145.170:17293
addnode=5.189.159.246:17293
addnode=5.189.165.82:17293
addnode=5.189.179.167:17293
addnode=5.189.189.217:17293
addnode=79.143.177.202:17293
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
