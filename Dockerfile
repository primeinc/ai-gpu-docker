# Build stage for compiling FFmpeg
FROM nvidia/cuda:11.8.0-devel-ubuntu22.04 AS build-stage
# ... Install build tools, dependencies, etc ...
# Use bash instead of sh
SHELL ["/bin/bash", "-c"]
# Remove any third-party apt sources to avoid issues with expiring keys.
RUN rm -f /etc/apt/sources.list.d/*.list
# Install more requirements
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libnuma1 \
    libnuma-dev \
    libass-dev \
    libtool \
    libc6 \
    libc6-dev \
    unzip \
    wget \
    yasm \
    cmake \
    build-essential \
    curl \
    ca-certificates \
    sudo \
    git \
    bzip2 \
    libx11-6 \
    binutils \
    bash \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install CUDA
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A4B469963BF863CC && \
    dpkg -i cuda-keyring_1.0-1_all.deb && \
    rm cuda-keyring_1.0-1_all.deb && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64 /" > /etc/apt/sources.list.d/cuda.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        cuda-11-8 && \
    rm -rf /var/lib/apt/lists/*

# Download and install cuDNN libraries
# RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/libcudnn8_8.9.4.25-1+cuda11.8_amd64.deb && \
#     wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/libcudnn8-dev_8.9.4.25-1+cuda11.8_amd64.deb && \
#     dpkg -i libcudnn8_8.9.4.25-1+cuda11.8_amd64.deb && \
#     dpkg -i libcudnn8-dev_8.9.4.25-1+cuda11.8_amd64.deb && \
#     rm libcudnn8_8.9.4.25-1+cuda11.8_amd64.deb libcudnn8-dev_8.9.4.25-1+cuda11.8_amd64.deb

# Build ffmpeg
# Clone ffnvcodec
RUN git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git

# Install ffnvcodec
RUN cd nv-codec-headers && make install && cd -

# Clone FFmpeg's public GIT repository
RUN git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg/

# Configure FFmpeg with cuDNN support (modify flags as needed)
RUN cd ffmpeg && \
    ./configure --enable-nonfree --enable-cuda-nvcc --enable-libnpp --extra-cflags=-I/usr/local/cuda/include --extra-ldflags=-L/usr/local/cuda/lib64 --disable-static --enable-shared

# Compile
RUN cd ffmpeg && make -j 8 && make install

# Final stage to create the image
FROM nvidia/cuda:11.8.0-devel-ubuntu22.04
# Copy only the compiled FFmpeg from the build stage
COPY --from=build-stage /usr/local/bin/ffmpeg /usr/local/bin/
COPY --from=build-stage /usr/local/bin/ffprobe /usr/local/bin/
COPY --from=build-stage /usr/local/lib /usr/local/lib

ENV DEBIAN_FRONTEND=noninteractive

# Use bash instead of sh
SHELL ["/bin/bash", "-c"]

# Remove any third-party apt sources to avoid issues with expiring keys.
RUN rm -f /etc/apt/sources.list.d/*.list

# Install some basic utilities.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    sudo \
    git \
    bzip2 \
    libx11-6 \
    binutils \
    bash \
    unzip \
    wget \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# SSH server setup
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server \
    && mkdir /var/run/sshd \
    && rm -rf /var/lib/apt/lists/*

# Install python3.10 * pip
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3.10-distutils \
    python3.10-dev \
    python3.10-venv \
    python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    # Create a symlink for python3 to python
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
    # add alias for quickly activating venv
    && echo "alias venv='source venv/bin/activate'" >> /etc/bash.bashrc

COPY requirements.txt /requirements.txt

RUN pip3 install -r /requirements.txt 

# # Install pytorch nightly
# RUN pip3 install --pre torch \
#     torchvision torchaudio \
#     --index-url https://download.pytorch.org/whl/nightly/cu121

# Install pytorch 2.0.1
RUN pip3 install torch \
    torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu118

# install requirements of Stable Diffusion
RUN pip install transformers==4.19.2 diffusers invisible-watermark --prefer-binary

# install k-diffusion
RUN pip install git+https://github.com/crowsonkb/k-diffusion.git --prefer-binary

# (optional) install GFPGAN (face restoration)
RUN pip install git+https://github.com/TencentARC/GFPGAN.git --prefer-binary

# install StyleGAN2-ADA
RUN apt-get update && apt-get install libgl1 -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Cloudflare DDNS
RUN pip install requests cloudflare

# VeraCrypt
# RUN add-apt-repository ppa:unit193/encryption -y \
#  && apt-get update \
#  && apt-get install veracrypt -y --no-install-recommends

# Generate SSH host keys
RUN ssh-keygen -A

# Create a non-root user and set the working directory to /ai.
RUN adduser --disabled-password --gecos '' --shell /bin/bash user \
 && mkdir /ai \
 && chown -R user:user /ai
RUN echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-user

# All users can use /home/user as their home directory.
ENV HOME=/home/user
RUN mkdir $HOME/.cache $HOME/.config \
 && chmod -R 777 $HOME

# Add the authorized_keys file with the SSH public key
COPY authorized_keys /root/.ssh/

# Set proper permissions for the .ssh directory and authorized_keys file
RUN chmod 700 /root/.ssh \
    && chmod 600 /root/.ssh/authorized_keys \
    && chown -R root:root /root/.ssh

# Expose ports
EXPOSE 22
EXPOSE 7860

# Switch to the non-root user and set the working directory.
# USER user
# WORKDIR /ai

# Start SSH server and keep the container running with a long-running process.
# CMD ["/usr/sbin/sshd", "-D"]
# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Make the script executable
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
