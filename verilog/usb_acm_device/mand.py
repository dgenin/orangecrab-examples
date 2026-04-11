#!/usr/bin/env python3
import serial
import struct
import time
import math

ser = serial.Serial('/dev/ttyACM0', timeout=1)
p = ser.read(100)
# print(list(map(hex, p)))

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


def mandel_iter(cr: float, ci: list):
    # Remove when the stripe bug is fixed
    ci.append(0)
    batch_size = len(ci)
    data = [int(cr*SCALE)&0xffff]
    # if (a[0]>>16) not in [0, 0xff]:
    #     print("a overflowed %x at cr %f"%(a, cr))
    # a &= 0xffff
    for i in range(0, batch_size):
        data.append(int(ci[i]*SCALE)&0xffff)
    out_data = struct.pack(">"+"H"*(batch_size+1), *data)
    # print("out_data=", list(map(hex, out_data)))    
    ser.write(out_data)
    p = ser.read(batch_size*2)
    # print("in data=", list(map(hex, p)))
    res = struct.unpack(">"+"H"*batch_size, p)
    return (res[0:batch_size])

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
    batch_size = 4
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
        for y in range(0, y_pixel_size, batch_size):
            # print((x,y))
            c_r = O_r + x*x_scale
            # c_r = O_r
            c_i = []
            for i in range(0, batch_size):
                c_i.append(O_i + (y+i)*y_scale)
                # c_i.append(O_i)
            # iter_count = mandel_iter_float(c_r, c_i)
            iter_count = mandel_iter(c_r, c_i)
            # print(iter_count)
            for i in range(0, batch_size):
                f.write(bytes([(iter_count[i]&1)<<7, iter_count[i]&0xFF, (255-iter_count[i])&0xFF]))
    f.close()

mandel_plot_ppm()
# mandel_iter(0.0, 0.0)