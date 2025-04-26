FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip git wget ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --upgrade pip
RUN pip3 install torch torchvision --extra-index-url https://download.pytorch.org/whl/cu121

# Install Real-ESRGAN
RUN git clone https://github.com/xinntao/Real-ESRGAN.git /workspace/Real-ESRGAN
WORKDIR /workspace/Real-ESRGAN
RUN pip3 install -r requirements.txt
RUN python3 setup.py develop

# Install FastAPI and Uvicorn for API serving
RUN pip3 install fastapi uvicorn python-multipart pillow

# Copy server script
COPY server.py /workspace/server.py

EXPOSE 5000

ENTRYPOINT ["python3", "server.py"]
