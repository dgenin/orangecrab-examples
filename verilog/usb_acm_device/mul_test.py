#!/usr/bin/env python3
import serial
import struct
import time
import math

ser = serial.Serial('/dev/ttyACM0', timeout=1)
p = ser.read(100)
print(list(map(hex, p)))

SCALE = int(2**13)

def mandel_iter_float(cr, ci):
    res_r = 0
    res_i = 0
    iter_counter = 100
    while iter_counter > 0:
        if ((res_r*res_r + res_i*res_i) > 4):
            return iter_counter
        new_res_r = res_r*res_r - res_i*res_i + cr
        new_res_i = 2*res_r*res_i + ci
        # print("%2.10f, %2.10f : %08x %08x"%(res_r, res_i, int(res_r*(1<<14))&0xffffffff, int(res_i*(1<<14))&0xffffffff))
        res_r = new_res_r
        res_i = new_res_i
        iter_counter -= 1
    return 0


def mandel_iter(cr: float, ci: float):
    a = int(cr*SCALE)&0xffffff
    if (a>>16) not in [0, 0xff]:
        print("a overflowed %x at cr %f"%(a, cr))
    a &= 0xffff
    b = int(ci*SCALE)&0xffff
    out_data = struct.pack(">HHHH", a, b, 0, 0)
    ser.write(out_data)
    p = ser.read(9)
    # print(list(map(hex, p)))
    res = struct.unpack(">HHHbbb", p)
    return res[2]&0xffffff

def mandel_plot():
    plain_size = 1.0
    x_pixel_size = 80
    y_pixel_size = 40
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
    plain_size = 0.5
    x_pixel_size = 800
    y_pixel_size = 800
    O_r = -1
    O_i = -0.75
    f = open("mandel.ppm", "wb")
    f.write(b"P6\n%d %d\n255\n"%(x_pixel_size, y_pixel_size))
    x_scale = plain_size/x_pixel_size
    y_scale = plain_size/y_pixel_size
    for x in range(0, x_pixel_size):
        for y in range(0, y_pixel_size):
            c_r = O_r + x*x_scale
            c_i = O_i + y*y_scale
            # iter_count = mandel_iter_float(c_r, c_i)
            iter_count = mandel_iter(c_r, c_i)
            # iter_count += (iter_count&1)*20
            iter_count &= 0xff
            f.write(bytes([(iter_count&1)<<7, iter_count, 255-iter_count]))
    f.close()

mandel_plot_ppm()