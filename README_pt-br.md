# Auto Instalação Masternode ZCore
Shell Script para instalar um ZCore MasterNode em um servidor Linux executando o Ubuntu 16.04 x64. Use-o por sua conta e risco.<br>
Múltiplos MN no mesmo VPS não testado<br>
Este script foi testado em VPS [www.vultr.com](https://www.vultr.com/?ref=7145379)

***
## Instalação:
```
sudo curl -o- https://raw.githubusercontent.com/zcore-coin/masternode-auto/master/install.sh | bash
```
***

Siga os passos e guarde a informação do resumo

## Configuração da Wallet Desktop

Depois que o MN ZCore estiver em execução, você precisará configurar a carteira da área de trabalho. Aqui estão os passos para a ZCore Wallet:
1. Abra a **ZCore Desktop Wallet**.
1. Vá até RECEBEER e crie um novo endereço com o rótulo: **MasterNode01**
1. Envie **5000** **ZCR** para **MasterNode01** este endereço.
1. Aguarde po 15 confirmações.
1. Vá até **Ferramentas -> "Debug console - Console"**
1. Execute o comando: **masternode outputs**
1. Vá até  **Ferramentas -> "Open Masternode Configuration File"**
1. Adicione a seguinte entrada:
```
alias IP:port masternodeprivkey collateral_output_txid collateral_output_index
```
* Alias: **MasterNode01** 
* Address: **VPS_IP:PORT** #see resumen masternode install script
* masternodeprivkey: **Masternode Private Key** #see resumen masternode install script
* collateral_output_txid: **First value from Step 6**
* collateral_output_index:  **Second value from Step 6**

Exemplo:
```
mn1 127.0.0.2:19999 93HaYBVUCYjEMeeH1Y4sBGLALQZE1Yc1K64xiqgX37tGBDQL8Xg 2bcd3c84c84f87eaa86e4e56834c92927a07f9e18718810b92e0d0324456a67c 0
```

1. Salve e feche o arquivo.
1. Vá até a **Aba Masternodes**. Se não aparecer a aba, habilite em: **Configurações - Opções - Carteira - Mostrar Aba Masternodes**
1. Click **Update status** to see your node. If it is not shown, close the wallet and start it again. 
1. Select your MN and click **Start Alias** to start it.
1. Alternatively, open **Debug Console** and type:
```
masternode start-alias MasterNode01
```
***

## Usage:
Login with MasterNode User set on install Script
```
zcore-cli mnsync status
zcore-cli getinfo
zcore-cli masternode status #This command will show your masternode status
```

Also, if you want to check/start/stop **zcore** , run one of the following commands as **root**:

```
systemctl status USER.service #To check the service is running.
systemctl start USER.service #To start zcore service.
systemctl stop USER.service #To stop zcore service.
systemctl is-enabled USER.service #To check whetether zcore service is enabled on boot or not.
```
***
