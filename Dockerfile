FROM nvidia/cuda:11.8.0-devel-ubuntu22.04
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/London

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
    htop \
    ffmpeg \
    software-properties-common \
    openssh-server \
    libgl1 \
    libglib2.0-0 \
    libgoogle-perftools-dev \
    dos2unix \
    ncdu \
    && mkdir /var/run/sshd \
    && ssh-keygen -A \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

# Install python3.10 * pip
RUN apt-get update && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get install -y --no-install-recommends \
    python3.10 \
    python3.10-distutils \
    python3.10-dev \
    python3.10-venv \
    python3.10-tk \
    python3-html5lib \
    python3-apt \
    python3-pip && \
    rm -rf /var/lib/apt/lists/* && \
    # Create a symlink for python3 to python
    update-alternatives --install /usr/bin/python python /usr/bin/python3 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 3 && \
    update-alternatives --set python3 /usr/bin/python3.10 && \
    update-alternatives --set cuda /usr/local/cuda-11.8 && \
    # add alias for quickly activating venv
    echo "alias venv='source venv/bin/activate'" >> /etc/bash.bashrc

# Replace pillow with pillow-simd
RUN apt-get update && \
    apt-get install libjpeg-dev -y && \
    python -m pip uninstall -y pillow && \
    CC="cc -mavx2" python -m pip install -U --force-reinstall pillow-simd

# Fix missing libnvinfer7
RUN ln -s /usr/lib/x86_64-linux-gnu/libnvinfer.so /usr/lib/x86_64-linux-gnu/libnvinfer.so.7 && \
    ln -s /usr/lib/x86_64-linux-gnu/libnvinfer_plugin.so /usr/lib/x86_64-linux-gnu/libnvinfer_plugin.so.7

# Download requirement files
RUN wget -O roop-requirements.txt https://raw.githubusercontent.com/C0untFloyd/roop-unleashed/main/requirements.txt && \
    wget -O automatic1111-requirements.txt https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/requirements.txt && \
    wget -O kohya-runpod-requirements.txt https://raw.githubusercontent.com/bmaltais/kohya_ss/master/requirements_runpod.txt && \
    wget -O kohya-requirements.txt https://raw.githubusercontent.com/bmaltais/kohya_ss/master/requirements.txt 

# Clean and move kohya-runpod-requirements
RUN sed -i '1d' /kohya-runpod-requirements.txt && \
    awk '{ for(i=1;i<=NF;i++) print $i }' /kohya-runpod-requirements.txt | grep -v '^-r\|requirements.txt' > /tmp/cleaned_requirements.txt && \
    mv /tmp/cleaned_requirements.txt /kohya-runpod-requirements.txt && \
    sed -i '$d' kohya-requirements.txt 

# Stage 1: Install requirements from roop-requirements.txt
RUN pip install --prefer-binary -r /roop-requirements.txt && \
    rm -rf /root/.cache/pip

# Stage 2: Install requirements from kohya-runpod-requirements.txt
RUN pip install --prefer-binary -r /kohya-runpod-requirements.txt && \
    rm -rf /root/.cache/pip

# Stage 3: Install requirements from kohya-requirements.txt
RUN pip install --prefer-binary -r /kohya-requirements.txt && \
    rm -rf /root/.cache/pip

# Stage 4: Install transformers and other packages
RUN transformers_version=$(grep "transformers==" automatic1111-requirements.txt | awk -F '==' '{print $2}') && \
    pip install "transformers==$transformers_version" \
    diffusers \
    invisible-watermark \
    requests \
    cloudflare \
    certipie \
    certifi \
    --prefer-binary && \
    rm -rf /root/.cache/pip

# Install additional package
RUN pip install git+https://github.com/crowsonkb/k-diffusion.git --prefer-binary && \
    rm -rf /root/.cache/pip

# Remove requirement files and clean cache
RUN rm /roop-requirements.txt /automatic1111-requirements.txt && \
    rm /kohya-runpod-requirements.txt /kohya-requirements.txt && \
    rm -rf /root/.cache/pip && \
    rm -rf /var/lib/apt/lists/* 

# Expose ports
EXPOSE 22 7860

# Copy scripts
COPY entrypoint.sh /entrypoint.sh
COPY idlecheck.sh /root/idlecheck.sh
COPY auto_tls.py /root/auto_tls.py
COPY random_banner.txt /tmp/random_banner.txt
COPY banner.sh /root/banner.sh

# Set proper permissions for the .ssh directory and authorized_keys file
RUN mkdir -p /root/.ssh \
    && chmod 700 /root/.ssh \
    && touch /root/.ssh/authorized_keys \
    && chmod 600 /root/.ssh/authorized_keys \
    && chown -R root:root /root/.ssh

# Make the scripts executable
RUN chmod +x /entrypoint.sh && chmod +x /root/idlecheck.sh

ENV LD_PRELOAD=libtcmalloc.so
ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
