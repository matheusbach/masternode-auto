# Auto Instalação Masternode ZCore
Shell Script para instalar um Masternode ZCore em um servidor Linux. Compátivel com Ubuntu 16.04 x64. 
* Use-o por sua conta e risco.
* Múltiplos MN no mesmo VPS não testado

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
2. Vá até **ENDEREÇOS DE RECEBIMENTO em ARQUIVO** e crie um novo endereço com o rótulo: **MasterNode01**
3. Envie **5000** **ZCR** para **MasterNode01** este endereço.
4. Aguarde 15 confirmações.
5. Vá até **Ferramentas -> "Debug console - Console"**
6. Execute o comando: **masternode genkey** . 
   Anote como masternodeprivkey
7. Execute o comando: **masternode outputs** . 
   Anote as ultimas entradas como tx e id
8. Vá até  **Ferramentas -> "Open Masternode Configuration File"**
9. Feche a carteira
10. Adicione a seguinte entrada:
```
apelido IP:17291 masternodeprivkey collateral_output_txid collateral_output_index
```
* Apelido: **MasterNode01** 
* IP: Endereço de IP da VPS
* masternodeprivkey: Gerado com o comando **masternode genkey** 
* collateral_output_txid: Gerado com o comando **masternodes outputs**. TX
* collateral_output_index:  Gerado com o comando **masternodes outputs**. ID

Exemplo:
```
mn1 127.0.0.2:17291 93HaYBVUCYjEMeeH1Y4sBGLALQZE1Yc1K64xiqgX37tGBDQL8Xg 2bcd3c84c84f87eaa86e4e56834c92927a07f9e18718810b92e0d0324456a67c 0
```

11. Salve e feche o arquivo.
12. Vá até a **Aba Masternodes**. Se não aparecer a aba, habilite em: **Configurações - Opções - Carteira - Mostrar Aba Masternodes**
13. Clique em **Update status** para atualizar os status do seu masternode.
14. Selecione o Masternode adicionado e clique em **Start Alias** para inicia-lo.
15. Caso não funcionar, abra o **Debug Console** e digite:
```
masternode start-alias MasterNode01
```
***

## Comandos:
Logue em seu masternode, e usando o cliente RPC:
```
zcore-cli mnsync status
zcore-cli getinfo
zcore-cli masternode status #Esse comando vai mostrar os status do seu masternode
```
Caso você também queira, verificar/iniciar/parar, execute um dos seguintes comandos usando **root**:
```
systemctl status USER.service #Para verificar se o service está rodando
systemctl start USER.service #Para iniciar o serviço
systemctl stop USER.service #Para parar o serviço
systemctl is-enabled USER.service #Para verificar se o serviço está no boot.
```
***
