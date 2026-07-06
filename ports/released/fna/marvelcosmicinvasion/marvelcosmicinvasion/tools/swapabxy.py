#!/usr/bin/env python3
import sys

"""
    name: swapabxy tool
    description: swap a/b and x/y buttons in SDL_GAMECONTROLLERCONFIG mappings
    author: k-dog (auto mode: RHH)
"""

def button_index(value):
    if len(value) > 1 and value[0] == "b" and value[1:].isdigit():
        return int(value[1:])
    return None

def main():
    auto = "--auto" in sys.argv[1:]

    for line in sys.stdin:
        splitted_line = line.rstrip().split(',')
        (a_i, b_i, x_i, y_i) = (-1, -1, -1, -1)
        (a, b, x, y) = ("", "", "", "")

        for i, param in enumerate(splitted_line):
            splitted_param = param.split(":")

            if splitted_param[0] == "a":
                a = splitted_param[1]
                a_i = i
            elif splitted_param[0] == "b":
                b = splitted_param[1]
                b_i = i
            elif splitted_param[0] == "x":
                x = splitted_param[1]
                x_i = i
            elif splitted_param[0] == "y":
                y = splitted_param[1]
                y_i = i

        do_swap = True
        if auto:
            ai, bi = button_index(a), button_index(b)
            do_swap = ai is not None and bi is not None and ai > bi

        if do_swap:
            if a_i > -1 and b_i > -1:
                splitted_line[a_i] = f"a:{b}"
                splitted_line[b_i] = f"b:{a}"
            if x_i > -1 and y_i > -1:
                splitted_line[x_i] = f"x:{y}"
                splitted_line[y_i] = f"y:{x}"

        print(','.join(splitted_line))

if __name__ == '__main__':
    main()
