FROM nvidia/cuda:12.9.1-cudnn-devel-ubuntu24.04

# set bash as current shell
RUN chsh -s /bin/bash
SHELL ["/bin/bash", "-c"]

# install necessary general Linux packages
RUN apt-get update && \
    apt-get install -y \
    wget \
    bzip2 \
    ca-certificates \
    libglib2.0-0 \
    libxext6 \
    libsm6 \
    libxrender1 \
    git \
    mercurial \
    subversion \
    nano \
    mesa-utils \
    freeglut3-dev \
    build-essential \
    curl \
    unzip \
    zip \
    tar \
    p7zip-full \
    xz-utils \
    vim \
    openssh-client \
    net-tools \
    iputils-ping \
    procps \
    rsync \
    htop \
    locales \
    tmux \
    screen && \
    apt-get clean

# install anaconda
RUN wget --quiet https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh -O ~/anaconda.sh && \
    /bin/bash ~/anaconda.sh -b -p /opt/conda && \
    rm ~/anaconda.sh && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    /opt/conda/bin/conda clean -afy

# Create and activate conda environment, then install packages
RUN /bin/bash -c "source /opt/conda/etc/profile.d/conda.sh && \
    conda create -n main python=3.8 -y && \
    conda activate main && \
    pip install torch torchvision torchaudio && \
    pip install -U xformers --index-url https://download.pytorch.org/whl/cu121 && \
    pip install ninja opencv-python wandb tqdm albumentations einops h5py kornia bounding_box matplotlib omegaconf 'trimesh[all]' gdown roma connected-components-3d positional_encodings && \
    pip install --upgrade --no-cache-dir gdown"

# install zellij
RUN wget --quiet https://github.com/zellij-org/zellij/releases/download/v0.40.0/zellij-x86_64-unknown-linux-musl.tar.gz -O /tmp/zellij.tar.gz && \
    tar -xzf /tmp/zellij.tar.gz -C /tmp && \
    mv /tmp/zellij /usr/local/bin && \
    rm /tmp/zellij.tar.gz

# set path to conda
ENV PATH /opt/conda/bin:$PATH
