## Install @rat (and vscode)
```bash
CODE_SERVER_VERSION=4.20.0
sysx="linux"
git clone https://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@github.com/ankanbhunia/rat.git
chmod -R +x rat
cd rat
curl -fL https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server-$CODE_SERVER_VERSION-$sysx-amd64.tar.gz > code-server.tar.gz
tar -xvf code-server.tar.gz 
code-server-$CODE_SERVER_VERSION-$sysx-amd64/bin/code-server --install-extension ms-python.python --force  --extensions-dir vscode-extensions_dir
```


## Install @rat
```bash
git clone https://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@github.com/ankanbhunia/rat.git
chmod -R +x rat
```

## Start a vscode instance

```bash
rat/vscode [--port <PORT>] [--JumpServer <user@host>] [--domain <domain>]
```  

1. Get a public cloudflare URL:
   
```bash
rat/vscode
```
3. Get a fixed domain:
   
```bash
rat/vscode --domain desktop.runs.space
```
4. Using a JumpServer:
```bash
rat/vscode --JumpServer root@217.160.147.188
rat/vscode --JumpServer s2514643@daisy2.inf.ed.ac.uk
```

## Share a Folder/File

```bash
rat/share --path <FILE/FOLDER_PATH>
```

## Tunnel a Port

```bash
rat/tunnel --port <PORT> [--domain <DOMAIN>] [--subpage_path <PATH>] [--protocol <http/ssh>]
```

## Download a file or git clone using a jumphost

```bash
rat/wget --url <DOWLOAD_URL/GITHUB_REPO_URL> [--JumpServer <user@host>]
```

## Make any linux-machine ssh-accessible

1 (server-side). Requirements: install openssh-server
```bash
sudo apt install openssh-server
sudo systemctl start ssh
sudo systemctl enable ssh
```
2 (server-side). Start ssh-tunneling -
```bash
rat/tunnel --port 22 --domain my-home-network.runs.space --protocol ssh
```
   Add this to ```crontab -e``` --> add ```@reboot sleep 60 && <rat/tunnel ... >```

3 (client-side). Requirements: install cloudflared (https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-local-tunnel/).

4 (client-side). Add the following lines to  ```./ssh/config```
```bash
Host my-home-network.runs.space
         ProxyCommand cloudflared access ssh --hostname %h
```
5 (client-side). Connect via ssh:
```bash
ssh ankan@my-home-network.runs.space
```
Alternatively, in one line -
```bash
ssh -o ProxyCommand='cloudflared access ssh --hostname %h' ankan@my-home-network.runs.space
```


## Use any linux-machine as VPN

Save this code in a file i.e., ```home_network.sh``` and run ```bash home_network.sh``` to start the VPN. 

```bash
sshuttle  -e "ssh -q -o ProxyCommand='cloudflared access ssh --hostname %h'"\
 -r ankan@my-home-network.runs.space -x my-home-network.runs.space --no-latency-control 0/0
```

## CloudFlare Domain Setup
1. Register for a new domain.
2. Add a new website (the registered domain) to https://dash.cloudflare.com/.
3. Change Nameservers in the domain register site.
4. Create a cert.pem using ```cloudflare login```
5. Done!



