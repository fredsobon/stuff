# -*- coding: utf-8 -*-

import dataxchg.filesystem as fs
import getpass
import sys

from __main__ import subparsers
from dataxchg.command import get_backend, get_base_path


backend = get_backend()
base_path = get_base_path()


def ask_pass():
    passwd = getpass.getpass('Password: ')
    passwd_repeat = getpass.getpass('Repeat password: ')

    if passwd != passwd_repeat:
        sys.stderr.write("Error: passwords do not match\n")
        return False
    else:
        return passwd


def user_add(args):
    args.login = args.login.lower()

    del args.func

    if not backend.user_exists(args.login):
        if not args.password:
            args.password = ask_pass()

        if not args.password:
            sys.stdout.write('Fail\n')
            return

        backend.user_set(**vars(args))
        fs.user_mkdir(base_path, args.login)

        sys.stdout.write('OK\n')
    else:
        sys.stderr.write("Error: user `%s' already exists\n" % args.login)


def user_delete(args):
    args.login = args.login.lower()

    user_id = backend.user_get_id(args.login)

    if user_id:
        if not args.force:
            sys.stdout.write("You are about to delete `%s' user account. Are you sure? (y/N) " % args.login)

            if raw_input().lower().strip() not in ['y', 'yes']:
                return

        shares = backend.share_list(user_id)

        for share in shares:
            fs.share_unset(base_path, share['share_path'], user_id)

        backend.user_unset(login=args.login)
        fs.user_rmdir(base_path, args.login)

        sys.stdout.write('OK\n')
    else:
        sys.stderr.write("Error: user `%s' does not exist\n" % args.LOGIN)


def user_list(args):
    result = backend.user_list()

    if not result:
        sys.stdout.write('No user found.\n')
        return

    if not args.raw:
        result.insert(0, {'id': 'Id', 'login': 'Login', 'allow_ftp': 'FTP', 'allow_sftp': 'SFTP',
            'expires': 'Expires', 'accessed': 'Last access', 'name': 'Client', 'issue_ref': 'Issue',
            'gid': 'Optional GID'})

    row_format = ''
    row_total = 0

    for key in ('id', 'login', 'allow_ftp', 'allow_sftp', 'expires', 'accessed', 'name', 'issue_ref', 'gid'):
        max_length = max([len(str(x[key])) for x in result])
        row_format += '%%(%s)-%ds  ' % (key, max_length)
        row_total += max_length

    for row in result:
        row = dict((x, y if y is not None else '-') for x, y in row.iteritems())
        sys.stdout.write(row_format % row + '\n')

        if not args.raw and row['id'] == 'Id':
            sys.stdout.write('-' * (row_total + 2 * (len(row.keys()) - 1)) + '\n')


def user_modify(args):
    args.login = args.login.lower()

    if backend.user_exists(args.login):
        kwargs = {}

        if args.expires:
            kwargs['expires'] = args.expires

        if args.issue:
            kwargs['issue'] = args.issue

        if args.password:
            kwargs['password'] = None

            while not kwargs['password']:
                kwargs['password'] = ask_pass()

        if args.protocols:
            kwargs['protocols'] = args.protocols

        if args.gid:
            kwargs['gid'] = args.gid

        backend.user_set(modify=True, login=args.login, **kwargs)

        sys.stdout.write('OK\n')
    else:
        sys.stderr.write("Error: user %s does not exist\n" % args.LOGIN)


subparser = subparsers.add_parser('useradd', help='add a new account')
subparser.set_defaults(func=user_add)
subparser.add_argument('-c', '--client', help='account client tag', required=True)
subparser.add_argument('-e', '--expires', help='account expiration date')
subparser.add_argument('-f', '--force', action='store_true', help='do not prompt for confirmation')
subparser.add_argument('-i', '--issue', help='issue ticket number', required=True)
subparser.add_argument('-P', '--protocols', help='account allowed protocols')
subparser.add_argument('-p', '--password', help='account password')
subparser.add_argument('-g', '--gid', help='optional group ID')
subparser.add_argument('login', metavar='LOGIN', help='account login name')

subparser = subparsers.add_parser('userdel', help='delete an existing account')
subparser.set_defaults(func=user_delete)
subparser.add_argument('-f', '--force', action='store_true', help='do not prompt for confirmation')
subparser.add_argument('login', metavar='LOGIN', help='account login name')

subparser = subparsers.add_parser('userlist', help='list existing accounts')
subparser.set_defaults(func=user_list)
subparser.add_argument('-r', '--raw', action='store_true', help='print list in raw format')

subparser = subparsers.add_parser('usermod', help='modify an existing account')
subparser.set_defaults(func=user_modify)
subparser.add_argument('-e', '--expires', help='account expiration date')
subparser.add_argument('-f', '--force', action='store_true', help='do not prompt for confirmation')
subparser.add_argument('-i', '--issue', help='issue ticket number')
subparser.add_argument('-p', '--password', action='store_true', help='account password')
subparser.add_argument('-P', '--protocols', help='account allowed protocols')
subparser.add_argument('-g', '--gid', help='optional group ID')
subparser.add_argument('login', metavar='LOGIN', help='account login name')
