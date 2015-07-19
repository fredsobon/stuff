#!/usr/bin/env python

# very short script that reuses pysisinfo_fun2 code : see code in "/home/boogie/lab/python/misc" folder.
# here we import ONLY the space fonction from pysisinfo_fun2 : with "from ... import ..." notation.
from pysysinfo_fun2 import space

# classic import method 
import subprocess


# def new func for "/tmp"  space dir folder.
def tmp_space():
    tmp_usage = "du"
    tmp_arg = "-h"
    path = "/tmp"
    print "Space used in /tmp directory"
    subprocess.call([tmp_usage, tmp_arg, path])


# def main fonction that reusses "space" fonction imported  from our pysisinfo_fun2 module and the new created one : "tmp_space" 
def main():
    space()
    tmp_space()

# We then use the 'tips' to be able to run all of our main fonction in script.

if __name__ == "__main__":
    main()

