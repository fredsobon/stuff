#!/usr/bin/python -u
# -*- coding: utf-8 -*-
#
# check-oracle.py: Oracle check data exporter
#                  by Vincent Batoufflet <vbatoufflet@e-merchant.com>
#

# ChangeLog:
# 20150210: add custom freshness which overwrites the default one

import codecs
import getopt
import os
import snmp_passpersist as snmp
import sys
import time


CHECK_DATA = {
#   'xx_type': {
#       'xx_check_name': {
#           'xx_check_name': (bool: table flag, (type1, type2, ...)),
#           'xx_check_name.status': (bool: table flag, (type1, type2, ...)),
#       }
#   },
    '01_health': {
        '01_tablespace_usage': {
            '00_tablespace_usage': (True, ('str', 'str', 'int', 'int', 'int', 'int', 'int')),
            '01_tablespace_usage.status': (False, ('str', 'str'))
        },
        '02_invalid_object': {
            '00_invalid_object': (True, ('str',)),
            '01_invalid_object.status': (False, ('int', 'str'))
        },
        '03_blocking_session': {
            '00_blocking_session': (False, ('int',)),
            '01_blocking_session.status': (False, ('int', 'str'))
        },
        '04_nr_scheduler_running_job': {
            '00_nr_scheduler_running_job': (False, ('int',)),
            '01_nr_scheduler_running_job.status': (False, ('int', 'str'))
        },
        '05_active_session': {
            '00_active_session': (False, ('int',)),
            '01_active_session.status': (False, ('int', 'str'))
        },
        '06_blocked_session': {
            '00_blocked_session': (True, ('str',)),
            '01_blocked_session.status': (False, ('int', 'str'))
        },
        '08_no_refresh_mv': {
            '00_no_refresh_mv': (False, ('int',)),
            '01_no_refresh_mv.status': (False, ('int', 'str'))
        },
        '10_scheduler_job_status': {
            '00_scheduler_job_status': (True, ('str',)),
            '01_scheduler_job_status.status': (False, ('int', 'str'))
        },
        '11_invalid_job': {
            '00_invalid_job': (False, ('int',)),
            '01_invalid_job.status': (False, ('int', 'str'))
        },
        '12_invalid_index': {
            '00_invalid_index': (True, ('str',)),
            '01_invalid_index.status': (False, ('int', 'str'))
        },
        '13_check_open_mode': {
            '00_check_open_mode': (False, ('str',)),
            '01_check_open_mode.status': (False, ('int', 'str'))
        },
        '14_stats_dml_sql_queries': {
            '00_stats_dml_sql_queries': (True, ('int', 'str', 'int', 'int')),
            '01_stats_dml_sql_queries.status': (False, ('int', 'str'))
        },
        '16_mvlog_refresh_age': {
            '00_mvlog_refresh_age': (True, ('int', 'str')),
            '01_mvlog_refresh_age.status': (False, ('int', 'str'))
        },
        '17_stats_sessions_waits': {
            '00_stats_sessions_waits': (True, ('int', 'str')),
            '01_stats_sessions_waits.status': (False, ('int', 'str'))
        },
        '18_flashback_usage': {
            '00_flashback_usage': (True, ('str', 'int', 'int', 'int', 'int', 'int', 'int', 'int')),
            '01_flashback_usage.status': (False, ('int', 'str'))
        },
        '19_mvlog_not_used': {
            '00_mvlog_not_used': (True, ('str',)),
            '01_mvlog_not_used.status': (False, ('int', 'str'))
        },
        '20_scheduler_jobs_running_time': {
            '00_scheduler_jobs_running_time': (True, ('str',)),
            '01_scheduler_jobs_running_time.status': (False, ('int', 'str'))
        },
        '21_services_not_started': {
            '00_services_not_started': (True, ('str',)),
            '01_services_not_started.status': (False, ('int', 'str'))
        },
        '22_critical_mv_refresh_age': {
            '00_critical_mv_refresh_age': (True, ('str',)),
            '01_critical_mv_refresh_age.status': (False, ('int', 'str'))
        },
        '23_mv_refresh_age': {
            '00_mv_refresh_age': (True, ('str','str','str','int','str','str','str','str','str','int','int')),
            '01_mv_refresh_age.status': (False, ('int', 'str'))
        },
        '24_stats_sql_per_user': {
            '00_stats_sql_per_user': (True, ('str','str','int','int','int','int','int','int','int')),
            '01_stats_sql_per_user.status': (False, ('int', 'str'))
        },
        '25_global_hit_ratio': {
            '00_global_hit_ratio': (True, ('str',)),
            '01_global_hit_ratio.status': (False, ('int', 'str'))
        },
        '26_load_database': {
            '00_load_database': (True, ('int','int')),
            '01_load_database.status': (False, ('int', 'str'))
        },
        '27_archives_not_delete': {
            '00_archives_not_delete': (True, ('str',)),
            '01_archives_not_delete.status': (False, ('int', 'str'))
        },
        '29_mvlog_size': {
            '00_mvlog_size': (True, ('str',)),
            '01_mvlog_size.status': (False, ('int', 'str'))
        },
        '28_mvlog_orphan_mviews': {
            '00_mvlog_orphan_mviews': (True, ('str',)),
            '01_mvlog_orphan_mviews.status': (False, ('int', 'str'))
        },
        '30_tablespace_extents_allocation': {
            '00_tablespace_extents_allocation': (True, ('str',)),
            '01_tablespace_extents_allocation.status': (False, ('int', 'str'))
        },
        '31_no_future_histo_partitions': {
            '00_no_future_histo_partitions': (False, ('int',)),
            '01_no_future_histo_partitions.status': (False, ('int', 'str')),
            'freshness': 87000
         },
    },
    '02_asm': {
        '01_diskgroup_usage': {
            '00_diskgroup_usage': (True, ('str', 'int', 'int', 'int')),
            '01_diskgroup_usage.status': (False, ('int', 'str'))
        },
        '02_asm_check_lun': {
            '00_asm_check_lun': (True, ('str',)),
            '01_asm_check_lun.status': (False, ('int', 'str'))
        },
        '03_asm_iostat': {
            '00_asm_iostat': (True, ('str', 'int', 'int', 'int', 'int')),
            '01_asm_iostat.status': (False, ('int', 'str'))
        }
    },
    '03_rac': {
        '01_rac_services': {
            '00_rac_services': (True, ('str',)),
            '01_rac_services.status': (False, ('int', 'str'))
        },
        '02_rac_check_scan_listener': {
            '00_rac_check_scan_listener': (False, ('str',)),
            '01_rac_check_scan_listener.status': (False, ('int', 'str'))
        }
    },
    '04_dataguard': {
        '01_standby_apply_status': {
            '00_dg_standby_apply_status': (False, ('str', )),
            '01_dg_standby_apply_status.status': (False, ('int', 'str'))
        },
        '02_standby_receive_status': {
            '00_dg_standby_receive_status': (False, ('str', )),
            '01_dg_standby_receive_status.status': (False, ('int', 'str'))
        },
        '03_standby_apply_lag': {
            '00_dg_standby_apply_lag': (False, ('int', 'str')),
            '01_dg_standby_apply_lag.status': (False, ('int', 'str'))
        },
        '04_standby_transport_lag': {
            '00_dg_standby_transport_lag': (False, ('int', 'str')),
            '01_dg_standby_transport_lag.status': (False, ('int', 'str'))
        },
        '06_dg_rac_services': {
            '00_dg_rac_services': (True, ('str',)),
            '01_dg_rac_services.status': (False, ('int', 'str'))
        },
        '07_standby_apply_lag_sequence': {
            '00_dg_standby_apply_lag_sequence': (False, ('int',)),
            '01_dg_standby_apply_lag_sequence.status': (False, ('int', 'str'))
        },
        '08_standby_seq_gap': {
            '00_dg_standby_seq_gap':  (False, ('int',)),
            '01_dg_standby_seq_gap.status': (False, ('int', 'str'))
        },
        '09_dg_standby_apply_rate': {
            '00_dg_standby_apply_rate': (True, ('int', 'str')),
            '01_dg_standby_apply_rate.status': (False, ('int', 'str'))
        },
    },
    '05_applicative': {
        '01_check_appli_btools_fraudbuster': {
            '00_check_appli_btools_fraudbuster': (True, ('int', 'str', 'str')),
            '01_check_appli_btools_fraudbuster.status': (False, ('int', 'str'))
        },
        '02_check_appli_btools_fraudbuster_custom': {
            '00_check_appli_btools_fraudbuster_custom': (True, ('str',)),
            '01_check_appli_btools_fraudbuster_custom.status': (False, ('int', 'str'))
        }
    }
}


DATA_DIR = '/var/lib/snmp-oracle/monitoring'

OID_BASE = '.1.3.6.1.4.1.38673.1.26'

ORATAB_FILE = '/etc/oratab'

POLLING_INTERVAL = 30


# Return SNMP OID, extracted from string (01_health => 1, 02_asm => 2, ...)
def extract_id(string):
    try:
        return int(string.split('_')[0])
    except:
        return False


# Return Oracle instances list, extracted from oratab file
def get_instances():
    instances = []

    fd = codecs.open(ORATAB_FILE, 'r', 'utf-8')

    for line in fd:
        line = line.strip()

        if line.startswith('#'):
            continue

        chunks = line.split(':', 1)

        if len(chunks) != 2:
            continue
        else:
            instances.append(chunks[0])

    fd.close()

    return instances


def poll():
    base_id = extract_id(opt_base)

    instances = get_instances()

    # Define instances count OID (.1) with value
    oid_chunks = [base_id, 1]
    snmp.add_int('.'.join([str(x) for x in oid_chunks]), len(instances))

    for instance_id, instance_name in enumerate(instances):
        base_dir = os.path.join(DATA_DIR, instance_name, opt_base)

        if not os.path.exists(base_dir):
            current_time = time.strftime('%d/%m/%Y %H:%M:%S', time.localtime())
            log.write("[%s] Warning: can't find `%s' monitoring data directory\n" % (current_time, instance_name))
            continue

        # Define instance entry (.2.1.1."instance")
        oid_chunks = [base_id, 2, 1, 1, len(instance_name)] + [ord(x) for x in instance_name]
        snmp.add_str('.'.join([str(x) for x in oid_chunks]), instance_name)

        if not os.path.exists(base_dir):
            current_time = time.strftime('%d/%m/%Y %H:%M:%S', time.localtime())
            log.write("[%s] Warning: can't find `%s'\n" % (current_time, base_dir))

        for check_name in os.listdir(base_dir):
            check_id = extract_id(check_name)
            out_of_date = None

            custom_freshness = opt_freshness
            try: 
                if CHECK_DATA[opt_base][check_name]['freshness']:
                    custom_freshness = CHECK_DATA[opt_base][check_name]['freshness']
            except:
                pass

            for entry_name in os.listdir(os.path.join(base_dir, check_name)):
                entry_id = extract_id(entry_name)

                # Get check data
                try:
                    data = CHECK_DATA[opt_base][check_name][entry_name]
                except:
                    current_time = time.strftime('%d/%m/%Y %H:%M:%S', time.localtime())
                    log.write("[%s] Warning: can't find `%s:%s:%s' definition\n" % (current_time, opt_base, check_name, entry_name))
                    continue

                file_path = os.path.join(base_dir, check_name, entry_name)

                # Check for file freshness
                if custom_freshness is not None and time.time() - os.path.getmtime(file_path) > custom_freshness:
                    out_of_date = file_path

                if out_of_date is not None:
                    if entry_name.endswith('.status'):
                        oid_chunks = [base_id, 2, 1, check_id + (entry_id + 1) * 100, len(instance_name)] + \
                            [ord(x) for x in instance_name]

                        getattr(snmp, 'add_int')('.'.join([str(x) for x in oid_chunks + [1]]), 1)

                        getattr(snmp, 'add_str')('.'.join([str(x) for x in oid_chunks + [2]]),
                            "`%s' file is out of date (%d sec) %s - %s" % (out_of_date[len(DATA_DIR)+1:], custom_freshness, opt_base, check_name))

                    continue

                fd = codecs.open(file_path, 'r', 'utf-8')

                count = 0

                for line in fd:
                    line = line.strip().encode('ascii', 'replace')

                    if line.startswith('#'):
                        continue

                    count += 1

                    for chunk_id, chunk in enumerate(line.split(None, len(data[1]) - 1)):
                        oid_chunks = [base_id, 2, 1, check_id + (entry_id + 1) * 100, len(instance_name)] + \
                            [ord(x) for x in instance_name] + [chunk_id + 1]

                        if data[0]:
                            oid_chunks.append(count)

                        # Define check entry according to its type (stored in data[1])
                        getattr(snmp, 'add_' + data[1][chunk_id])('.'.join([str(x) for x in oid_chunks]), chunk)

                    # Stop if non-table
                    if not data[0]:
                        break

                # Define check count entry
                if data[0]:
                    oid_chunks = [base_id, 2, 1, check_id + (entry_id + 1) * 100, len(instance_name)] + \
                        [ord(x) for x in instance_name] + [0]

                    getattr(snmp, 'add_int')('.'.join([str(x) for x in oid_chunks]), count)

                fd.close()


def print_usage(output=sys.stdout):
    output.write('''Usage: %(program)s -b BASE
       %(program)s -l

Options:
  -b  specify check base
  -f  maximum file freshness
  -h  display this help and exit
  -l  list available check bases
''' % {'program': os.path.basename(sys.argv[0])})


if __name__ == '__main__':
    opt_base = None
    opt_freshness = None
    opt_list = False

    # Parse command-line arguments
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'b:f:hl')
    except getopt.GetoptError, e:
        sys.stderr.write('Error: %s\n' % e)
        print_usage(output=sys.stderr)
        sys.exit(1)

    for opt, arg in opts:
        if opt == '-b':
            opt_base = arg
        elif opt == '-f':
            try:
                opt_freshness = int(arg)
            except ValueError:
                sys.stderr.write('Error: freshness value must be an integer\n')
                print_usage(output=sys.stderr)
                sys.exit(1)
        elif opt == '-h':
            print_usage()
            sys.exit(0)
        elif opt == '-l':
            opt_list = True

    if opt_list:
        sys.stdout.write('List of available check bases:\n%s\n' %
            '\n'.join(['  - ' + x for x in CHECK_DATA.keys()]))
        sys.exit(0)
    elif not opt_base:
        sys.stderr.write('Error: you must specify check base\n')
        print_usage(output=sys.stderr)
        sys.exit(1)
    elif opt_base not in CHECK_DATA:
        sys.stderr.write('Error: unknown check base\n')
        sys.exit(1)

    log = codecs.open('/tmp/%s.err' %
        os.path.splitext(os.path.basename(sys.argv[0]))[0], 'w', 'utf-8')

    try:
        snmp = snmp.PassPersist(OID_BASE)
        snmp.start(poll, POLLING_INTERVAL)

        log.close()
    except KeyboardInterrupt, SystemExit:
        log.close()
        sys.exit(0)
    except:
        import traceback
        traceback.print_exc(file=log)

        log.close()
        sys.exit(1)

# vim: ts=4 sw=4 et
