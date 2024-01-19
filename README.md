### Install vscode+cloudflare
```bash
CODE_SERVER_VERSION=4.14.1
sysx="linux"
git clone https://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@github.com/ankanbhunia/rats-client.git
cd rats-client
chmod +x rats
curl -fL https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server-$CODE_SERVER_VERSION-$sysx-amd64.tar.gz > code-server.tar.gz
tar -xvf code-server.tar.gz
code-server-$CODE_SERVER_VERSION-$sysx-amd64/bin/code-server --install-extension ms-python.python --force  --extensions-dir vscode-extensions_dir
```

```bash
echo "export PATH=\$PATH:$(pwd)" >> ~/.bashrc
source ~/.bashrc
```

### Install cloudflare
```bash
git clone https://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@github.com/ankanbhunia/rats-client.git
cd rats-client
chmod +x rats
```

### Start a vscode instance

```bash
./vscode --port <PORT> --JumpServer <user@host>
```  

1. Get a public cloudflare URL: ```./vscode```
2. Use JumpServer:
```bash
./vscode --JumpServer root@217.160.147.188
```
or
```bash
./vscode --JumpServer s2514643@daisy2.inf.ed.ac.uk
```
### Share a Folder/File

```bash
./share <FILE/FOLDER_PATH>
```
