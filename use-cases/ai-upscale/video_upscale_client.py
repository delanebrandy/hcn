import os
import requests
import subprocess
import argparse
from tqdm import tqdm

#python3 video_upscale_client.py \
#    --input input_video.mp4 \
#    --output upscaled_video.mp4 \
#    --server http://10.0.0.5:5000


def extract_frames(video_path, frames_dir):
    os.makedirs(frames_dir, exist_ok=True)
    cmd = [
        'ffmpeg', '-i', video_path,
        os.path.join(frames_dir, 'frame_%06d.png')
    ]
    subprocess.run(cmd, check=True)

def upscale_frame(frame_path, output_path, server_url):
    with open(frame_path, 'rb') as f:
        files = {'file': f}
        response = requests.post(f'{server_url}/upscale', files=files)
        if response.status_code == 200:
            with open(output_path, 'wb') as out_file:
                out_file.write(response.content)
        else:
            raise Exception(f"Failed to upscale {frame_path}: {response.text}")

def reassemble_video(upscaled_frames_dir, output_video_path, fps=30):
    cmd = [
        'ffmpeg', '-r', str(fps), '-i',
        os.path.join(upscaled_frames_dir, 'frame_%06d.png'),
        '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
        output_video_path
    ]
    subprocess.run(cmd, check=True)

def main():
    parser = argparse.ArgumentParser(description="Distributed Video Upscaler (Real-ESRGAN)")
    parser.add_argument('--input', required=True, help='Input video path')
    parser.add_argument('--output', required=True, help='Output upscaled video path')
    parser.add_argument('--server', required=True, help='Real-ESRGAN server URL (e.g., http://10.0.0.5:5000)')
    parser.add_argument('--fps', type=int, default=30, help='Frames per second for output video')
    args = parser.parse_args()

    tmp_dir = 'tmp_frames'
    upscaled_dir = 'upscaled_frames'

    print(f"[INFO] Extracting frames from {args.input}...")
    extract_frames(args.input, tmp_dir)

    frame_files = sorted(os.listdir(tmp_dir))
    os.makedirs(upscaled_dir, exist_ok=True)

    print(f"[INFO] Upscaling {len(frame_files)} frames...")
    for frame in tqdm(frame_files, desc="Upscaling"):
        input_frame = os.path.join(tmp_dir, frame)
        output_frame = os.path.join(upscaled_dir, frame)
        upscale_frame(input_frame, output_frame, args.server)

    print(f"[INFO] Reassembling video to {args.output}...")
    reassemble_video(upscaled_dir, args.output, fps=args.fps)

    print("[INFO] Cleaning up temporary files...")
    subprocess.run(['rm', '-r', tmp_dir, upscaled_dir])

    print("[DONE] Upscaled video saved to", args.output)

if __name__ == "__main__":
    main()
