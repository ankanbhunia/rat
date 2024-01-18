# Install

```bash
CODE_SERVER_VERSION=4.14.1
sysx="linux"
git clone https://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@github.com/ankanbhunia/rats2.git
cd rats2
chmod +x vscode share cloudflare/tunnel cloudflare/tunnel.any
curl -fL https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server-$CODE_SERVER_VERSION-$sysx-amd64.tar.gz > code-server.tar.gz
tar -xvf code-server.tar.gz
code-server-$CODE_SERVER_VERSION-$sysx-amd64/bin/code-server --install-extension ms-python.python --force  --extensions-dir vscode-extensions_dir
```

# Commands

1. ```rats2/vscode```/```rats2/vscode <PORT>```

2. ```rats2/share <FILE/FOLDER_PATH>```
