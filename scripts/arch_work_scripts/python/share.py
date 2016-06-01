# -*- coding: utf-8 -*-

import dataxchg.filesystem as fs
import os
import sys

from __main__ import subparsers
from dataxchg.command import get_backend, get_base_path

backend = get_backend()
base_path = get_base_path()


def share_add(args):
    user_id = backend.user_get_id(args.login)

    if not user_id:
        sys.stderr.write("Error: user `%s' does not exist\n" % args.login)
        return

    args.path = share_clean_path(args.path)

    if not args.path:
        sys.stderr.write('Error: shared data path must not be empty\n')
        return

    if backend.share_exists(user_id, args.path):
        sys.stderr.write("Error: share `%s' for `%s' user already exists\n" % (args.path, args.login))
        return

    share_id = backend.share_contains(user_id, args.path)

    if share_id is None:
        share_id = backend.share_intersect(user_id, args.path)

    if share_id is not None:
        sys.stderr.write("Error: share `%s' conflicts with `%s'\n" % (args.path, backend.share_get_path(share_id)))
        return

    if fs.user_path_exists(base_path, args.login, args.path):
        sys.stderr.write("Error: share `%s' user path already exists\n" % args.path)
        return

    if not args.create and not fs.share_path_exists(base_path, args.path):
        sys.stderr.write("Error: share `%s' data path does not exist\n" % args.path)
        return

    backend.share_insert(user_id, args.path, args.writable, (True != args.noacl))

    if not args.noacl:
        sys.stdout.write('Setting ACL... [Please wait]\n')
        fs.share_set(base_path, args.path, user_id, args.writable)

    fs.user_link(base_path, args.login, args.path)

    sys.stdout.write('OK\n')


def share_delete(args):
    user_id = backend.user_get_id(args.login)

    if not user_id:
        sys.stderr.write("Error: user `%s' does not exist\n" % args.login)
        return

    args.path = share_clean_path(args.path)

    if not args.path:
        sys.stderr.write('Error: shared data path must not be empty\n')
        return

    share_id = backend.share_id(user_id, args.path)

    if share_id is not None:
        if not args.force:
            sys.stdout.write("You are about to delete share `%s' for user `%s'. Are you sure? (y/N) " %
                (args.path, args.login))

            if raw_input().lower().strip() not in ['y', 'yes']:
                return

        backend.share_delete(share_id)

        if backend.share_is_acl_set(share_id):
            if fs.share_path_exists(base_path, args.path):
                sys.stdout.write('Unsetting ACL... [Please wait]\n')
                fs.share_unset(base_path, args.path, user_id)
            else:
                sys.stderr.write("Warning: shared data path `%s' data path does not exist\n" % args.path)

        fs.user_unlink(base_path, args.login, args.path)

        sys.stdout.write('OK\n')
    else:
        sys.stderr.write("Error: share `%s' for user `%s' does not exist\n" % (args.path, args.login))


def share_list(args):
    result = backend.share_list()

    if not result:
        sys.stdout.write('No share found.\n')
        return

    if not args.raw:
        result.insert(0, {
            'share_path': 'Path',
            'login': 'Login',
            'writable': 'Writable',
            'acl': 'ACL set'
        })

    row_format = ''
    row_total = 0

    for key in ('share_path', 'login', 'writable', 'acl'):
        max_length = max([len(str(x[key])) for x in result])
        row_format += '%%(%s)-%ds  ' % (key, max_length)
        row_total += max_length

    for row in result:
        row = dict((x, y if y is not None else '-') for x, y in row.iteritems())
        sys.stdout.write(row_format % row + '\n')

        if not args.raw and row['writable'] == 'Writable':
            sys.stdout.write('-' * (row_total + 2 * (len(row.keys()) - 1)) + '\n')


def share_modify(args):
    user_id = backend.user_get_id(args.login)

    if not user_id:
        sys.stderr.write("Error: user `%s' does not exist\n" % args.login)
        return

    args.path = share_clean_path(args.path)

    if not args.path:
        sys.stderr.write('Error: shared data path must not be empty\n')
        return

    if not fs.share_path_exists(base_path, args.path):
        sys.stderr.write("Error: share `%s' data path does not exist\n" % args.path)
        return

    share_id = backend.share_id(user_id, args.path)

    if share_id:
        backend.share_update(share_id, args.writable)

        if backend.share_is_acl_set(share_id):
            sys.stdout.write('Setting ACL... [Please wait]\n')
            fs.share_set(base_path, args.path, user_id, args.writable)

        sys.stdout.write('OK\n')
    else:
        sys.stderr.write('Error: share does not exist\n' % args.path)


def share_clean_path(path):
    if path.startswith(base_path):
        path = path[len(base_path) + 1:]

    return path.lstrip('/')


subparser = subparsers.add_parser('shareadd', help='add a new share')
subparser.set_defaults(func=share_add)
subparser.add_argument('-c', '--create', action='store_true', default=False, help='create path if needed')
subparser.add_argument('-l', '--login', help='user login', required=True)
subparser.add_argument('-p', '--path', help='shared data path', required=True)
subparser.add_argument('-w', '--writable', action='store_true', default=False, help='give user write permission')
subparser.add_argument('-X', '--noacl', action='store_true', default=False, help='create home symlink without setting ACL')

subparser = subparsers.add_parser('sharedel', help='delete an existing share')
subparser.set_defaults(func=share_delete)
subparser.add_argument('-l', '--login', help='user login', required=True)
subparser.add_argument('-p', '--path', help='path', required=True)
subparser.add_argument('-f', '--force', action='store_true', default=False, help='do not prompt for confirmation')

subparser = subparsers.add_parser('sharelist', help='list existing shares')
subparser.set_defaults(func=share_list)
subparser.add_argument('-l', '--login', help='user login')
subparser.add_argument('-p', '--path', help='shared data path')
subparser.add_argument('-r', '--raw', action='store_true', help='print list in raw format')

subparser = subparsers.add_parser('sharemod', help='modify an existing share')
subparser.set_defaults(func=share_modify)
subparser.add_argument('-l', '--login', help='user login', required=True)
subparser.add_argument('-p', '--path', help='shared data path', required=True)
subparser.add_argument('-w', '--writable', action='store_true', default=False, help='give user write permission')
