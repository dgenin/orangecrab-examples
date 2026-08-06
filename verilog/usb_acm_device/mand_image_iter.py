#!/usr/bin/env python3
import serial
import struct
import time
import math

ser = serial.Serial('/dev/ttyACM0', timeout=1)
p = ser.read(100)
# print(list(map(hex, p)))

SCALE = int(2**13)

def image_iter(tl_r: float, tl_i: float, step: float, width: int):
    """
    tl_r, tl_i -- top left real and imaginary coordinates
    step -- grid step
    width -- number of pixels, i.e., grid size
    """
    # FIXME: width*width must be divisible by 6 to fit into the pipeline
    data = [int(tl_r*SCALE)&0xffff, int(tl_i*SCALE)&0xffff, int(step*SCALE)&0xffff, width&0xffff]
    out_data = struct.pack(">"+"HHHH", *data)
    # print("out_data=", list(map(hex, out_data)))    
    ser.write(out_data)
    p = bytes([])
    for i in range(0, width):
        print("row=%d"%(i))
        b = bytes([])
        for j in range(0, 2*width//48):
            # Drop the first two bytes see comment in mandelbrot_uut.v around L270
            b += ser.read(2+48)[2:]
        # print("in data=", list(map(hex, p)))
        # print(i, " ", len(b), " ", end=" | ")
        if len(b) != 2*width:
            break
        p += b
        # print(b)
    # print("len(p)=", len(p))
    res = struct.unpack(">"+"H"*(len(p)>>1), p)
    return res

def mandel_plot():
    plain_size = 1.0
    x_pixel_size = 800
    y_pixel_size = 800
    O_r = -2
    O_i = -2
    x_scale = plain_size/x_pixel_size
    y_scale = plain_size/y_pixel_size
    for y in range(0, y_pixel_size):
        for x in range(0, x_pixel_size):
            c_r = O_r + x*x_scale
            c_i = O_i + y*y_scale
            iter_count = mandel_iter_float(c_r, c_i)
            print("\x1b[%dm*"%(30 + iter_count%16), end="")
        print()

def mandel_plot_ppm():
    plain_size = .2
    x_pixel_size = 1080
    y_pixel_size = 1080
    O_r = -.6
    O_i = -.6
    # O_r = -2
    # O_i = -2
    f = open("mandel.ppm", "wb")
    # f.write(b"P6\n%d %d\n255\n"%(x_pixel_size, y_pixel_size))
    f.write(b"P6\n%d %d\n255\n"%(x_pixel_size+1, y_pixel_size))

    iter_count = image_iter(O_r, O_i, plain_size/x_pixel_size, x_pixel_size)
    # print(iter_count)
    # for i in range(0, x_pixel_size*y_pixel_size):
    for i in range(0, len(iter_count)):
        f.write(bytes([(iter_count[i]&1)<<7, iter_count[i]&0xFF, (255-iter_count[i])&0xFF]))
    f.close()
    for i in range(0, 35):
        print("%02d   %02x "%(i, iter_count[i]))

mandel_plot_ppm()
# mandel_iter(0.0, 0.0)