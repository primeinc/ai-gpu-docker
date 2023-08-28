### About This Docker Image

#### Overview

Built specifically for Runpod, this Docker image is a one-stop solution for AI and machine learning development, particularly in GPU-accelerated environments. It's based on `nvidia/cuda:11.8.0-devel-ubuntu22.04` and comes pre-configured with a range of utilities and Python libraries essential for machine learning and AI projects.

**Operable Beyond Runpod: When run outside of the Runpod environment, the idlecheck script is automatically deactivated.**

#### Key Features

- **Runpod-Optimized**: Includes an `idlecheck.sh` script configurable to auto-stop or terminate your Runpod pod based on idle time. Set `IDLE_KILL_HOURS` or `IDLE_STOP_HOURS` to customize.
  
- **Automatic Certificate Generation**: Generates self signed TLS certificates for https app deployment. Cert locations are exported as ENV vars `SERVER_KEY`, `SERVER_CERT`, and `SERVER_BUNDLE`.

- **Pre-configured Environment Variables**: Comes with environment variables like `SERVER_PUBLIC_IP`, `SERVER_NAME`, and `SERVER_PORT` set for you. The default `SERVER_PORT` is 7860 or the first requested 1:1 port map from Runpod.

- **CUDA 11.8.0 Support**: Leverages NVIDIA GPUs for high-performance machine learning.

- **SSH Enabled**: OpenSSH server pre-installed for secure remote access.

- **Python 3.10**: Equipped with Python 3.10 and pip for Python-based projects.

- **AI Libraries**: Pre-installed libraries from multiple sources for a wide range of AI tasks.

#### Utilities and Packages

Packed with utilities like `curl`, `git`, `wget`, `ffmpeg`, and more. Also includes development tools and Python development headers.

### Port Mapping in Runpod

For certain applications, asymmetrical port mappings may not be ideal. Runpod provides the feature of **Symmetrical Port Mapping** by letting you specify ports above `70000` in the TCP port field. Utilize this feature to avoid routing your data through Gradio's proxies, which is one of the reasons we include automatic certificate generation.

For more details, check out the [Runpod Documentation on Exposing Ports](https://docs.runpod.io/docs/expose-ports#through-tcp-public-ip).

#### Extensibility and Security

The image serves as a robust foundation for building advanced AI apps and ensures secure storage of SSH authorized keys by not storing any, pass them with ENV PUBLIC_KEY (Runpod does this for you)

#### GitHub Repository

For more details and to contribute, visit the [GitHub repository](https://github.com/primeinc/ai-gpu-docker).

#### Docker

[Docker Hub](https://hub.docker.com/repository/docker/prodigyprobably/ai-gpu)