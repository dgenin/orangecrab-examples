#!/usr/bin/env python3
def mand(cr, ci):
    # res_r_sqr = (res_r*res_r)>>14;
    # res_i_sqr = (res_i*res_i)>>14;
    # // 1<<14 is 1 in fixed point
    # running = (res_r_sqr + res_i_sqr < (1<<14));
    # if (running) begin
    #     res_r <= res_r_sqr - res_i_sqr + cr;
    #     res_i <= 2*((res_r*res_i)>>14) + ci;
    #     iter_counter <= iter_counter - 1;
    res_r = 0
    res_i = 0
    iter_counter = 10
    while iter_counter > 0:
        if ((res_r*res_r + res_i*res_i) > 1):
            print("----------------------------------------------")
        new_res_r = res_r*res_r - res_i*res_i + cr
        new_res_i = 2*res_r*res_i + ci
        print("%2.10f, %2.10f : %08x %08x"%(res_r, res_i, int(res_r*(1<<14))&0xffffffff, int(res_i*(1<<14))&0xffffffff))
        res_r = new_res_r
        res_i = new_res_i
        iter_counter -= 1

# mand(-1,0)
mand(0, 0.5)