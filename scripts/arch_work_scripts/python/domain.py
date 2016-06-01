# -*- coding: utf-8 -*-

import dataxchg.filesystem as fs
import getpass
import sys

from __main__ import subparsers
from dataxchg.command import get_backend, get_base_path


backend = get_backend()


def domain_add(args):
    del args.func

    args.name = args.name.lower()

    if not backend.user_get_id(args.login):
        sys.stderr.write("Error: user `%s' does not exist\n" % args.login)
        return
    elif backend.domain_exists(args.login):
        sys.stderr.write("Error: domain already set for user `%s'\n" % args.login)
        return

    backend.domain_set(**vars(args))
    sys.stdout.write('OK\n')


def domain_delete(args):
    if not backend.user_get_id(args.login):
        sys.stderr.write("Error: user `%s' does not exist\n" % args.login)
        return

    if not args.force:
        sys.stdout.write("You are about to delete the domain from user `%s'. Are you sure? (y/N) " % args.login)

        if raw_input().lower().strip() not in ['y', 'yes']:
            return

    backend.domain_unset(args.login)
    sys.stdout.write('OK\n')


def domain_list(args):
    result = backend.domain_list()

    if not result:
        sys.stdout.write('No domain found.\n')
        return

    if not args.raw:
        result.insert(0, {'id': 'Id', 'login': 'Login', 'name': 'Name'})

    row_format = ''
    row_total = 0

    for key in ('id', 'login', 'name'):
        max_length = max([len(str(x[key])) for x in result])
        row_format += '%%(%s)-%ds  ' % (key, max_length)
        row_total += max_length

    for row in result:
        row = dict((x, y if y is not None else '-') for x, y in row.iteritems())
        sys.stdout.write(row_format % row + '\n')

        if not args.raw and row['id'] == 'Id':
            sys.stdout.write('-' * (row_total + 2 * (len(row.keys()) - 1)) + '\n')


def domain_modify(args):
    if not backend.user_exists(args.login):
        sys.stderr.write("Error: user %s does not exist\n" % args.login)
        return

    kwargs = {}

    if args.login:
        kwargs['login'] = args.login

    if args.name:
        kwargs['name'] = args.name

    backend.domain_set(modify=True, **kwargs)
    sys.stdout.write('OK\n')


subparser = subparsers.add_parser('domainadd', help='add a new domain')
subparser.set_defaults(func=domain_add)
subparser.add_argument('-l', '--login', help='user login', required=True)
subparser.add_argument('-n', '--name', help='domain name', required=True)

subparser = subparsers.add_parser('domaindel', help='delete an existing domain')
subparser.set_defaults(func=domain_delete)
subparser.add_argument('-f', '--force', action='store_true', help='do not prompt for confirmation')
subparser.add_argument('-l', '--login', help='user login', required=True)

subparser = subparsers.add_parser('domainlist', help='list existing domains')
subparser.set_defaults(func=domain_list)
subparser.add_argument('-r', '--raw', action='store_true', help='print list in raw format')

subparser = subparsers.add_parser('domainmod', help='modify an existing domain')
subparser.set_defaults(func=domain_modify)
subparser.add_argument('-l', '--login', help='user login', required=True)
subparser.add_argument('-n', '--name', help='domain name', required=True)
