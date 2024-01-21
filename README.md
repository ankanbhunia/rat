### Install @rat (and vscode)
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


### Install @rat
```bash
git clone https://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@github.com/ankanbhunia/rat.git
chmod -R +x rat
```

### Start a vscode instance

```bash
rat/vscode [--port <PORT>] [--JumpServer <user@host>] [--domain <domain>]
```  

1. Get a public cloudflare URL:
   
```bash
rat/vscode
```
3. Get a fixed domain:
   
```bash
rat/vscode --domain desktop.lonelycoder.live
```
4. Using a JumpServer:
```bash
rat/vscode --JumpServer root@217.160.147.188
rat/vscode --JumpServer s2514643@daisy2.inf.ed.ac.uk
```

### Share a Folder/File

```bash
rat/share --path <FILE/FOLDER_PATH>
```

### Tunnel a Port

```bash
rat/tunnel --port <PORT> [--domain <DOMAIN>] [--subpage_path <PATH>]
```

### CloudFlare Domain Setup
1. Register for a new domain.
2. Add a new website (the registered domain) to https://dash.cloudflare.com/.
3. Change Nameservers in the domain register site.
4. Create a cert.pem using ```cloudflare login```
5. Done!



