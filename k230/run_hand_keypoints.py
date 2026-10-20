# Open this file in CanMV IDE, connect COM9, then click Run.
# Runs the verified official example already on the K230 SD card.
# Does not overwrite the board's main.py or the original contest backup.
print("Starting official hand keypoints: LCD + IDE output")
path = "/sdcard/k230_hand_keypoint_official.py"
with open(path) as source:
    code = source.read()
exec(compile(code, path, "exec"))
