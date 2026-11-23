"""Pose-extract every reference clip: clips/<action>/<id>.mp4 -> <id>_pose.mp4 (overlay, 3 largest people) + <id>_pose.json (all tracked people)."""
import glob, json, os, sys, cv2, numpy as np
import torch; torch.set_num_threads(2); cv2.setNumThreads(1)
from ultralytics import YOLO
ROOT = "E:/motion-reference/basketball/clips"
m = YOLO(os.path.join(os.path.dirname(__file__), "yolo11s-pose.pt"))
SK=[(5,7),(7,9),(6,8),(8,10),(5,6),(5,11),(6,12),(11,12),(11,13),(13,15),(12,14),(14,16),(0,5),(0,6)]
COL=[(0,230,255),(255,0,255),(0,255,0)]
clips = sorted(f for f in glob.glob(ROOT+"/*/*.mp4") if "_pose" not in os.path.basename(f))
for n, src in enumerate(clips):
    base = src[:-4]
    if os.path.exists(base+"_pose.json"): continue
    cap = cv2.VideoCapture(src); fps = cap.get(cv2.CAP_PROP_FPS) or 30
    W, H = int(cap.get(3)), int(cap.get(4)); step = 2 if fps > 45 else 1
    vw = cv2.VideoWriter(base+"_pose_tmp.mp4", cv2.VideoWriter_fourcc(*"mp4v"), fps/step, (W, H))
    frames = []; i = 0
    m.predictor = None
    while True:
        ok, f = cap.read()
        if not ok: break
        if i % step: i += 1; continue
        r = m.track(f, persist=True, verbose=False, conf=0.3)[0]; people = []
        if r.boxes is not None and len(r.boxes):
            bx = r.boxes.xyxy.cpu().numpy(); kp = r.keypoints.xy.cpu().numpy(); kc = r.keypoints.conf.cpu().numpy()
            ids = r.boxes.id.int().cpu().tolist() if r.boxes.id is not None else [-1]*len(bx)
            order = np.argsort(-(bx[:,2]-bx[:,0])*(bx[:,3]-bx[:,1]))
            for rank, j in enumerate(order):
                people.append({"id": ids[j], "box": bx[j].round(1).tolist(), "kp": [[round(float(x),1),round(float(y),1),round(float(c),2)] for (x,y),c in zip(kp[j],kc[j])]})
                if rank < 3:
                    for a,b in SK:
                        if kc[j][a]>0.4 and kc[j][b]>0.4: cv2.line(f,tuple(map(int,kp[j][a])),tuple(map(int,kp[j][b])),COL[rank],3,cv2.LINE_AA)
        frames.append({"frame": i, "t": round(i/fps,3), "people": people}); vw.write(f); i += 1
    vw.release()
    os.system(f'ffmpeg -v error -y -i "{base}_pose_tmp.mp4" -c:v libx264 -crf 23 -pix_fmt yuv420p "{base}_pose.mp4"'); os.remove(base+"_pose_tmp.mp4")
    json.dump({"source": src, "fps": fps/step, "keypoints": "COCO-17 [x,y,conf]", "frames": frames}, open(base+"_pose.json","w"))
    print(f"[{n+1}/{len(clips)}] {os.path.relpath(src, ROOT)} frames={len(frames)}", flush=True)
print("DONE")
