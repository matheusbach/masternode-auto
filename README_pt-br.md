# Auto Instalação Masternode RDCToken
Shell Script para instalar um Masternode RDCToken em um servidor Linux. Compatível com Ubuntu 16.04 x64. 
* Use-o por sua conta e risco.
* Múltiplos MN no mesmo VPS não testado

***
## Instalação:
```
sudo curl -o- https://raw.githubusercontent.com/matheusbach/rdct-masternode-auto/master/install.sh | bash
```
***

Siga os passos e guarde a informação do resumo

## Configuração da Wallet Desktop

Depois que o MN RDCToken estiver em execução, você precisará configurar a carteira da área de trabalho. Aqui estão os passos para a RDCToken Wallet:
1. Abra a **RDCToken Desktop Wallet**.
2. Vá até **ENDEREÇOS DE RECEBIMENTO em ARQUIVO** e crie um novo endereço com o rótulo: **MasterNode01**
3. Envie **7500** **RDCT** para **MasterNode01** este endereço.
4. Aguarde pelo menos 6 confirmações.
5. Vá até **Ferramentas -> "Debug console - Console"**
6. Execute o comando: **masternode genkey** . 
   Anote como masternodeprivkey
7. Execute o comando: **masternode outputs** . 
   Anote as ultimas entradas como tx e id
8. Vá até  **Ferramentas -> "Open Masternode Configuration File"**
9. Feche a carteira
10. Adicione a seguinte entrada:
```
apelido ip masternodeprivkey collateral_output_txid collateral_output_index
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
rdct-cli mnsync status
rdct-cli getinfo
rdct-cli masternode status #Esse comando vai mostrar os status do seu masternode
```
Caso você também queira, verificar/iniciar/parar, execute um dos seguintes comandos usando **root**:
```
systemctl status USER.service #Para verificar se o service está rodando
systemctl start USER.service #Para iniciar o serviço
systemctl stop USER.service #Para parar o serviço
systemctl is-enabled USER.service #Para verificar se o serviço está no boot.
```
***
