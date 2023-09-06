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

# COPY ./wheelhouse /root/wheelhouse
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     libcairo2-dev \
#     python3.10-apt \
#     libgirepository1.0-dev \
#     libdbus-1-dev \
#     pkg-config \
#     apt-utils && \
#     pip_freeze_output=$(pip freeze) && \
#     cleaned_output=$(echo "$pip_freeze_output" | sed '/@ git+/!s/+\([^ ]\+\)//g') && \
#     cleaned_output=$(echo "$cleaned_output" | grep -v 'python-apt==2.4.0') && \
#     echo "$cleaned_output" > cleaned_requirements.txt && \
#     python -m pip wheel --wheel-dir=/root/wheelhouse -r cleaned_requirements.txt && \
#     pip config set global.find-links "file:///root/wheelhouse" && \
#     pip config list && \
#     rm cleaned_requirements.txt
# Download and install python requirements for common ai libraries
# remove first line from kohya-runpod-requirements.txt as its invalid and already installed, Replace spaces with newlines
# Move the cleaned file back
RUN wget -O roop-requirements.txt https://raw.githubusercontent.com/C0untFloyd/roop-unleashed/main/requirements.txt && \
    wget -O automatic1111-requirements.txt https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/requirements.txt && \
    wget -O kohya-runpod-requirements.txt https://raw.githubusercontent.com/bmaltais/kohya_ss/master/requirements_runpod.txt && \
    sed -i '1d' /kohya-runpod-requirements.txt && \ 
    awk '{ for(i=1;i<=NF;i++) print $i }' /kohya-runpod-requirements.txt | grep -v '^-r\|requirements.txt' > /tmp/cleaned_requirements.txt && \
    mv /tmp/cleaned_requirements.txt /kohya-runpod-requirements.txt && \
    wget -O kohya-requirements.txt https://raw.githubusercontent.com/bmaltais/kohya_ss/master/requirements.txt && \
    sed -i '$d' kohya-requirements.txt && \
    transformers_version=$(grep "transformers==" automatic1111-requirements.txt | awk -F '==' '{print $2}') && \
    pip install --prefer-binary -r /roop-requirements.txt  && \
    pip install --prefer-binary -r /kohya-runpod-requirements.txt  && \
    pip install --prefer-binary -r /kohya-requirements.txt  && \
    pip install "transformers==$transformers_version" \
        diffusers \
        invisible-watermark \
        requests \
        cloudflare \
        certipie \
        certifi \
        --prefer-binary && \
    pip install git+https://github.com/crowsonkb/k-diffusion.git --prefer-binary && \    
    rm /roop-requirements.txt /automatic1111-requirements.txt && \
    rm /kohya-runpod-requirements.txt /kohya-requirements.txt && \
    rm -rf /root/.cache/pip && \
    rm -rf /var/lib/apt/lists/* 

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
