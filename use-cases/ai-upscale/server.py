from fastapi import FastAPI, UploadFile, File, BackgroundTasks
from fastapi.responses import FileResponse, JSONResponse
import uvicorn
import os
import uuid
import shutil
import torch
import asyncio
import cv2
from basicsr.archs.rrdbnet_arch import RRDBNet
from realesrgan import RealESRGANer
from basicsr.utils.download_util import load_file_from_url

app = FastAPI()

# --- Model Initialization ---
device = 'cuda' if torch.cuda.is_available() else 'cpu'

net = RRDBNet(
    num_in_ch=3, num_out_ch=3,
    num_feat=64, num_block=23,
    num_grow_ch=32, scale=4
)

WEIGHTS_DIR = 'weights'
MODEL_NAME = 'RealESRGAN_x4plus.pth'
MODEL_URL = f'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/{MODEL_NAME}'

os.makedirs(WEIGHTS_DIR, exist_ok=True)
local_model_path = os.path.join(WEIGHTS_DIR, MODEL_NAME)
if not os.path.isfile(local_model_path):
    load_file_from_url(url=MODEL_URL, model_dir=WEIGHTS_DIR, progress=True, file_name=None)
    model_path = os.path.join(WEIGHTS_DIR, MODEL_NAME)
else:
    model_path = local_model_path

tiler = RealESRGANer(
    scale=4,
    model_path=model_path,
    dni_weight=None,
    model=net,
    tile=0,            # set >0 if you need tiling for large images
    tile_pad=10,
    pre_pad=0,
    half=False,
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
            output, _ = tiler.enhance(img, outscale=4)
            cv2.imwrite(output_path, output)
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

    # Schedule cleanup
    background_tasks.add_task(cleanup_files, [input_path, output_path])

    return FileResponse(output_path, media_type='image/png', filename='upscaled.png')

@app.get("/")
def read_root():
    return {"message": "Real-ESRGAN Server Ready (using RealESRGANer)"}

async def cleanup_files(filepaths):
    for path in filepaths:
        try:
            os.remove(path)
        except FileNotFoundError:
            pass

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000, reload=True)
