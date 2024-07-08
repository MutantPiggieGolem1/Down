import sys
import re

DESCREGEX = re.compile(r"^Provided to YouTube by (?P<company>.+)\n\n(?P<title>.+?) · (?P<artist>.+)\n\n(?P<album>.*)\n\n℗(?: (?P<year>\d{4}))? (?P<record>.+)\n(?:\nReleased on: (?P<date>\d{4}-\d{2}-\d{2}))?\n\n?((?:.*\n)*)\nAuto-generated by YouTube\.$")
description = open(sys.argv[1], "r", encoding="utf8").read()

match = DESCREGEX.fullmatch(description)
if match is not None:
    matches = match.groupdict()
    b = "0000" if matches['year'] is None else match['year']
    a = f"{b}0000" if matches['date'] is None else matches['date']
    print(f"{a} {b}")