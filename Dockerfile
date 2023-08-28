FROM nvidia/cuda:11.8.0-devel-ubuntu22.04
ENV DEBIAN_FRONTEND=noninteractive

# Use bash instead of sh
SHELL ["/bin/bash", "-c"]

# Install some basic utilities & ssh.
RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        sudo \
        git \
        bzip2 \
        binutils \
        bash \
        unzip \
        wget \
        grep \
        nano \
        mawk \
        ffmpeg \
        software-properties-common \
        openssh-server \
    && mkdir /var/run/sshd \
    && ssh-keygen -A \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

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

# Download and install python requirements for common ai libraries
RUN wget -O requirements.txt https://raw.githubusercontent.com/C0untFloyd/roop-unleashed/main/requirements.txt && \
    wget -O automatic1111-requirements.txt https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/requirements.txt && \
    transformers_version=$(grep "transformers==" automatic1111-requirements.txt | awk -F '==' '{print $2}') && \
    pip install --prefer-binary -r /requirements.txt  && \
    pip install "transformers==$transformers_version" \
        diffusers \
        invisible-watermark \
        requests \
        cloudflare \
        certipie \
        certifi \
        --prefer-binary && \
    pip install git+https://github.com/crowsonkb/k-diffusion.git --prefer-binary && \    
    rm /requirements.txt /automatic1111-requirements.txt && \
    rm -rf /root/.cache/pip

# Expose ports
EXPOSE 22 7860

# Copy scripts
COPY entrypoint.sh /entrypoint.sh
COPY idlecheck.sh /root/idlecheck.sh
COPY auto_tls.py /root/auto_tls.py

# Set proper permissions for the .ssh directory and authorized_keys file
RUN mkdir -p /root/.ssh \
    && chmod 700 /root/.ssh \
    && touch /root/.ssh/authorized_keys \
    && chmod 600 /root/.ssh/authorized_keys \
    && chown -R root:root /root/.ssh

# Make the scripts executable
RUN chmod +x /entrypoint.sh && chmod +x /root/idlecheck.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
