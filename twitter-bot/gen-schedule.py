#!/usr/bin/env python3
import os
from datetime import date, timedelta
import random
import json


def get_gm_codes():
    return [os. path. splitext(os.path.basename(x))[0] for x in os.listdir(
        basedir) if os.path.isfile(os.path.join(basedir, x))]


basedir = "../atlas/maps/"
gm_codes = get_gm_codes()
today = date.today()
sdate = date(int(today.strftime("%Y")), int(today.strftime("%m")),
             int(today.strftime("%d")))   # start date
edate = date(int(today.strftime("%Y"))+1, 12, 31)   # end date

delta = edate - sdate       # as timedelta

days = []
for i in range(delta.days + 1):
    day = sdate + timedelta(days=i)
    days.append(day.strftime("%Y-%m-%d"))

result = {}
for day in days:
    if len(gm_codes) == 0:
        gm_codes = get_gm_codes()
    gm_code = random.choice(gm_codes)
    gm_codes.pop(gm_codes.index(gm_code))
    result[day] = gm_code

print(json.dumps(result, indent=4))
