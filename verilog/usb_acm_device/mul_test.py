#!/usr/bin/env python3
import serial
import struct
import time

ser = serial.Serial('/dev/ttyACM0', timeout=1)
p = ser.read(100)
print(list(map(hex, p)))

while True:
    a = int(input("> a="))
    b = int(input("> b="))
    out_data = struct.pack(">HHHH", a, b, 0, 0)
    ser.write(out_data)
    # for i in out_data:
    #     print(i)
    #     ser.write(bytes(i))
    p = ser.read(100)
    print(list(map(hex, p)))
    res = struct.unpack(">HHL", p)
    print(res[2]&0xffffff)