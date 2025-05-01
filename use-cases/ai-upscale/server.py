from fastapi import FastAPI, UploadFile, File, BackgroundTasks
from fastapi.responses import FileResponse, JSONResponse
import uvicorn
import os
import uuid
import shutil
import torch
import asyncio
import cv2
import warnings

warnings.filterwarnings(
    "ignore",
    category=UserWarning,
    message=".*torchvision\.transforms\.functional_tensor module is deprecated.*"
)
from basicsr.archs.rrdbnet_arch import RRDBNet
from realesrgan import RealESRGANer
from basicsr.utils.download_util import load_file_from_url

app = FastAPI()

# --- Model Initialization ---
device = 'cpu'
try:
    if torch.cuda.is_available():
        torch.zeros(1, device='cuda')
        device = 'cuda'
except Exception:
    device = 'cpu'
half = (device == 'cuda')

net = RRDBNet(
    num_in_ch=3, num_out_ch=3,
    num_feat=64, num_block=23,
    num_grow_ch=32, scale=4
)

WEIGHTS_DIR = 'weights'
MODEL_NAME = 'RealESRGAN_x4plus.pth'
MODEL_URL = f'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/{MODEL_NAME}'
os.makedirs(WEIGHTS_DIR, exist_ok=True)
local_wt = os.path.join(WEIGHTS_DIR, MODEL_NAME)
if not os.path.isfile(local_wt):
    load_file_from_url(url=MODEL_URL, model_dir=WEIGHTS_DIR, progress=True)

tile_size = 0
if device == 'cuda':
    try:
        total_vram = torch.cuda.get_device_properties(0).total_memory / 1e9  # GB
        # On smaller GPUs use more aggressive tiling
        if total_vram < 10:
            tile_size = 256
        else:
            tile_size = 0
    except Exception:
        tile_size = 0

model = RealESRGANer(
    scale=4,
    model_path=local_wt,
    dni_weight=None,
    model=net,
    tile=tile_size,
    tile_pad=10,
    pre_pad=0,
    half=half,
    device=device
)

model_lock = asyncio.Lock()

@app.post("/upscale")
async def upscale_image(
    file: UploadFile = File(...),
    background_tasks: BackgroundTasks = None
):
    input_path = f"/tmp/{uuid.uuid4()}.png"
    output_path = f"/tmp/{uuid.uuid4()}_out.png"
    with open(input_path, "wb") as f:
        shutil.copyfileobj(file.file, f)
    try:
        async with model_lock:
            img = cv2.imread(input_path, cv2.IMREAD_UNCHANGED)
            output, _ = model.enhance(img, outscale=4)
            cv2.imwrite(output_path, output)
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
    background_tasks.add_task(cleanup_files, [input_path, output_path])
    return FileResponse(output_path, media_type='image/png', filename='upscaled.png')

@app.get("/")
def read_root():
    return {"message": "Real-ESRGAN Server Ready (using RealESRGANer)", "device": device}

@app.on_event("startup")
async def on_startup():
    print(read_root())

async def cleanup_files(filepaths):
    for path in filepaths:
        try:
            os.remove(path)
        except FileNotFoundError:
            pass

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
