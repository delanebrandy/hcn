FROM nvidia/cuda:12.2.0-cudnn8-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.9 python3.9-distutils python3.9-venv wget git ffmpeg \
  && rm -rf /var/lib/apt/lists/*

RUN wget https://bootstrap.pypa.io/get-pip.py \
  && python3.9 get-pip.py \
  && rm get-pip.py

RUN python3.9 -m pip install --upgrade pip

RUN python3.9 -m pip install torch torchvision --extra-index-url https://download.pytorch.org/whl/cu122 \
    || python3.9 -m pip install torch torchvision

RUN python3.9 -m pip install \ 
    realesrgan basicsr opencv-python-headless psutil \
    fastapi uvicorn[standard] python-multipart requests tqdm

ENV WEIGHTS_DIR=/workspace/weights \
    MODEL_NAME=RealESRGAN_x4plus.pth \
    MODEL_URL=https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/${MODEL_NAME}
RUN mkdir -p ${WEIGHTS_DIR} \
  && if [ ! -f ${WEIGHTS_DIR}/${MODEL_NAME} ]; then \
       wget -qO ${WEIGHTS_DIR}/${MODEL_NAME} ${MODEL_URL}; \
     fi

WORKDIR /workspace

COPY server.py video_upscale_client.py ./

EXPOSE 5000
ENTRYPOINT ["python3.9", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "5000"]
