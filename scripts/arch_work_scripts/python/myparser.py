#!/usr/bin/env python2.6

import os, sys, getopt
import collections

# dlarquey @ Emerchant

def usage():
    prog = os.path.basename(os.path.realpath(sys.argv[0]))
    print "\nUsage:", prog, "--file FILE [--help] [--cat CATEGORIE] [--output OUTPUT_FORMAT_ID]"
    sys.exit(2)


# Categorie 1
(t_db_inst, t_inst_state, t_inst_host, t_state) = (dict(), dict(), dict(), dict())
(t_host, t_db) = (list(), list())
t_db_state = collections.defaultdict(dict)
t_db_inst_state = collections.defaultdict(dict)
t_db_host_state = collections.defaultdict(dict)
t_db_host_inst = collections.defaultdict(dict)
t_db_inst_host= collections.defaultdict(dict)

# collect & format
def collect_c1():
    for line in f:
        line = line.strip('\n').strip()
        if line.startswith('#') or line == '': continue

        tabline = line.split()
        (db, inst, host, state) = tabline
        try:
            t_db_inst[db].append(inst)
        except:
            t_db_inst[db] = [inst]
        #myDict.setdefault('r', []).append(newRecord)

        if host not in t_host: t_host.append(host)
        if db not in t_db: t_db.append(db)
        t_db_state[db][host] = state
        t_inst_state[inst] = state
        t_inst_host[inst] = host
        try:
            t_state[state].append(inst)
        except:
            t_state[state] = [inst]

        t_db_inst_state[db][inst] = state
        t_db_host_state[db][host] = state
        t_db_host_inst[db][host] = inst
        t_db_inst_host[db][inst] = host

    t_host.sort()
    t_db.sort()


# print
def print_c1():
    print t_host
    print t_db
    print t_db_inst
    print t_db_state
    print t_inst_state
    print t_inst_host
    print t_state
    print t_db_inst_state
    print t_db_host_state
    print t_db_host_inst
    print t_db_inst_host


# output
def output_c1():

    format = '%-18s'
    head = format % ''

    for host in t_host:
        head = head + format % host
    print head

    for db in t_db:
        line = format % db
        (line2, line3, line4) = (line, line, line)
        for host in t_host:
            try:
                t_db_host_state[db][host]
            except:
                line = line + format % 'N/A'
                continue
            state = t_db_host_state[db][host]
            inst = t_db_host_inst[db][host]
            id_inst = inst[-1]
            v_line3 = state+'('+id_inst+')'
            if state == 'up':
                v_line4 = state+'('+id_inst+')'
            else:
                v_line4 = '-'
            line = line + format % state
            line3 = line3 + format % v_line3
            line4 = line4 + format % v_line4

            try:
                t_db_host_inst[db][host]
            except:
                line2 = line2 + format % 'N/A'
                continue
            inst = t_db_host_inst[db][host]
            state = t_db_host_state[db][host]
            v_line2 = inst+'('+state+')'
            line2 = line2 + format % v_line2


        if int(arg_output_format) == 1:
            print line
        elif int(arg_output_format) == 2:
            print line2
        elif int(arg_output_format) == 3:
            print line3
        elif int(arg_output_format) == 4:
            print line4



############
### MAIN ###
############

arg_file = ""
arg_categorie = 0
arg_output_format = 1

if __name__ == "__main__":
    try:
        opts, args = getopt.getopt(sys.argv[1:], 'hf:c:o:', ['file=','cat=','output-format'])
    except getopt.GetoptError:
        usage()

    for opt, arg in opts:
        if opt in ('-f', '--file'):
            arg_file = arg
            arg_file = os.path.realpath(arg_file)
        elif opt in ('-h', '--help'):
            usage()
        elif opt in ('-c', '--cat'):
            arg_categorie = arg
        elif opt in ('-o', '--output'):
            arg_output_format = arg

    if (arg_file == "" or not os.path.isfile(arg_file)): usage()

    f = open(arg_file, 'r')
    if int(arg_categorie) == 1:
        collect_c1()
        output_c1()

