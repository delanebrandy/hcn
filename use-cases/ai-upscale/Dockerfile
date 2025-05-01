FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      software-properties-common wget git ffmpeg tzdata && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      python3.9 python3.9-distutils python3.9-venv && \
    ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

RUN wget -qO /tmp/get-pip.py https://bootstrap.pypa.io/get-pip.py && \
    python3.9 /tmp/get-pip.py && \
    rm /tmp/get-pip.py

RUN python3.9 -m pip install --no-cache-dir --upgrade pip

RUN python3.9 -m pip install \
      --extra-index-url https://download.pytorch.org/whl/cu118 \
      torch==2.0.1+cu118 \
      torchvision==0.15.2+cu118 \
      torchaudio==2.0.2+cu118


RUN python3.9 -m pip install --no-cache-dir \
      "numpy<2.0" \
      basicsr \
      realesrgan \
      opencv-python-headless \
      psutil

RUN python3.9 -m pip install --no-cache-dir \
      fastapi \
      "uvicorn[standard]" \
      python-multipart \
      requests \
      tqdm

WORKDIR /workspace
COPY server.py video_upscale_client.py ./

EXPOSE 5000
ENTRYPOINT ["python3.9", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "5000"]
