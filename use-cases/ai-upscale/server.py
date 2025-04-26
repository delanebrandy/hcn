from fastapi import FastAPI, UploadFile, File
from starlette.responses import FileResponse
import uvicorn
import os
import uuid
import shutil

from realesrgan import RealESRGANer
import torch

app = FastAPI()

# Load model at startup
model = RealESRGANer(
    scale=4,
    model_path='weights/RealESRGAN_x4plus.pth',  # Default model
    dni_weight=None,
    tile=0,
    tile_pad=10,
    pre_pad=0,
    half=True if torch.cuda.is_available() else False,
    device='cuda' if torch.cuda.is_available() else 'cpu'
)

@app.post("/upscale")
async def upscale_image(file: UploadFile = File(...)):
    input_filename = f"/tmp/{uuid.uuid4()}.png"
    output_filename = f"/tmp/{uuid.uuid4()}_out.png"

    with open(input_filename, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # Run Real-ESRGAN
    output, _ = model.enhance(input_filename, outscale=4)
    output.save(output_filename)

    return FileResponse(output_filename, media_type='image/png', filename='upscaled.png')

@app.get("/")
def read_root():
    return {"message": "Real-ESRGAN Server Ready"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
