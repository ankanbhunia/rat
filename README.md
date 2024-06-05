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


## Share internet via Proxy
```bash
echo -e 'export http_proxy=http://localhost:3128\nexport https_proxy=http://localhost:3128' >> ~/.bashrc && source ~/.bashrc
ssh -L 3128:localhost:3128 s2514643@vico02.inf.ed.ac.uk 'fuser -k 3128/tcp; python3 -m proxy --port 3128'
```

## CloudFlare Domain Setup
1. Register for a new domain.
2. Add a new website (the registered domain) to https://dash.cloudflare.com/.
3. Change Nameservers in the domain register site.
4. Create a cert.pem using ```cloudflare login```
5. Done!

## Sample DockerFile for cuda+conda setup

```DockerFile
FROM nvidia/cuda:12.1.0-devel-ubuntu22.04

# set bash as current shell
RUN chsh -s /bin/bash
SHELL ["/bin/bash", "-c"]

# install anaconda
RUN apt-get update
RUN apt-get install -y wget bzip2 ca-certificates libglib2.0-0 libxext6 libsm6 libxrender1 git mercurial subversion && \
        apt-get clean
RUN wget --quiet https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh -O ~/anaconda.sh && \
        /bin/bash ~/anaconda.sh -b -p /opt/conda && \
        rm ~/anaconda.sh && \
        ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
        echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
        find /opt/conda/ -follow -type f -name '*.a' -delete && \
        find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
        /opt/conda/bin/conda clean -afy

# set path to conda
ENV PATH /opt/conda/bin:$PATH
```
```
sudo docker build . -t ankan999/conda-cuda-12.1
sudo docker push conda-cuda-12.1
```

## Apptainer commands to build .sif from scratch
```
apptainer pull mltoolkit-cuda12.1_build.sif docker://ankan999/conda-cuda-12.1:latest
apptainer build --sandbox mltoolkit-cuda12.1_build mltoolkit-cuda12.1_build.sif
apptainer shell --nv --writable --fakeroot mltoolkit-cuda12.1_build
```

```
apt-get update
apt install wget
apt install -y nano
apt-get install -y git
apt install -y mesa-utils freeglut3-dev
```

```
conda create -n main python=3.8
conda activate main
pip3 install torch torchvision torchaudio
pip3 install -U xformers --index-url https://download.pytorch.org/whl/cu121
pip3 install ninja opencv-python wandb tqdm albumentations einops h5py kornia bounding_box matplotlib omegaconf trimesh[all] gdown roma connected-components-3d positional_encodings 
pip3 install --upgrade --no-cache-dir gdown
pip3 install pyrender
pip3 install "git+https://github.com/facebookresearch/pytorch3d.git"
pip3 install 'git+https://github.com/facebookresearch/detectron2.git'
```
```
apptainer build  mltoolkit-cuda12.1_build.sif mltoolkit-cuda12.1_build 
```

output file is ```mltoolkit-cuda12.1_build.sif``` 

Download link - [https://uoe-my.sharepoint.com/:u:/r/personal/s2514643_ed_ac_uk/Documents/Containers/mltoolkit-cuda12.1_build.sif?csf=1&web=1&e=rVDbcZ](https://uoe-my.sharepoint.com/:u:/r/personal/s2514643_ed_ac_uk/Documents/Containers/mltoolkit-cuda12.1_build.sif?csf=1&web=1&e=rVDbcZ)

## Usage of Apptainer .sif container

```bash
# create overlay image of 2GB
dd if=/dev/zero of=overlay.img bs=1M count=2000 && mkfs.ext3 overlay.img
```
```bash
# start the container with the persistent overlay image
apptainer shell --nv --overlay overlay.img --fakeroot --bind /disk/scratch/ mltoolkit-cuda12.1_build.sif
```

```
CONTAINER_PATH=/disk/scratch/s2514643/envs/
apptainer shell --nv --overlay $CONTAINER_PATH/overlay.img --fakeroot --bind /disk/scratch/ $CONTAINER_PATH/mltoolkit-cuda12.1_build.sif
bash ~/rat/vscode --jumpserver s2514643@vico02.inf.ed.ac.uk --port 4080
```



