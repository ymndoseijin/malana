from math import cos

with open("VSOP87C.ven") as f:
    text = f.read()
    l = text.split("\n")

    x0 = 0
    for line in l[1:1+685]:
        val = [float(i) for i in line.split()[-3:]]
        t = 0.012970568104
        x0 += val[0]*cos(val[1]+val[2]*t)
    print(x0)
