"""Review-only boot entry example. NOT installed on the K230 SD card."""
with open('/sdcard/usb_gesture_sender_standalone.py') as source_file:
    source=source_file.read()
exec(compile(source,'/sdcard/usb_gesture_sender_standalone.py','exec'),{'__name__':'__main__'})
