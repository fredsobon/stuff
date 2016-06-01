# -*- coding: utf-8 -*-

import os
import shutil
import subprocess


def share_set(xchg_path, path, uid, writable):
    path = os.path.join(xchg_path, 'data', path)

    if not os.path.exists(path):
        os.makedirs(path, mode=0755)

    permission_set(path, uid, writable)


def share_unset(xchg_path, path, uid):
    path = os.path.join(xchg_path, 'data', path)

    if os.path.exists(path):
        permission_unset(path, uid)


def share_path_exists(xchg_path, path):
    return os.path.exists(os.path.join(xchg_path, 'data', path))


def permission_get(xchg_path, path):
    head, tail = os.path.split(os.path.join(xchg_path, 'data', path))
    return acl_parse(subprocess.check_output(['getfacl', tail], cwd=head))


def permission_set(path, uid, writable=False):
    subprocess.call(['setfacl', '-R', '-m', 'u:{0}:{1},d:u:{0}:{1}'.format(uid, 'rwX' if writable else 'r-X'), path])


def permission_unset(path, uid):
    subprocess.call(['setfacl', '-R', '-x', 'u:{0},d:u:{0}'.format(uid), path])


def acl_parse(lines):
    result = []

    for line in lines.split('\n'):
        if line and not line.startswith('#') and '::' not in line:
            result.append(line)

    return result


def acl_list(xchg_path, user_id=None):
    result = []
    errors = []
    path = os.path.join(xchg_path, 'data')
    len_prefix = len(path) + 1

    if user_id:
        user_id = ':%s:' % user_id

    count = 0

    for root, dirs, files in os.walk(path):
        for entry in dirs:
            acl = acl_parse(subprocess.check_output(['getfacl', entry], cwd=root))

            if not acl:
                continue

            count += 1

            for user_acl in acl:
                if user_id is None or user_id in user_acl:
                    result.append((os.path.join(root, entry)[len_prefix:], user_acl))

        for entry in files:
            acl = acl_parse(subprocess.check_output(['getfacl', entry], cwd=root))

            if acl:
                errors.append((os.path.join(root, entry)[len_prefix:], acl))

    return result, errors


def user_link(xchg_path, user, path):
    link = os.path.join(xchg_path, 'users', user, path)
    head = os.path.split(link)[0]

    if not os.path.exists(head):
        os.makedirs(head, mode=0755)

    os.symlink('%sdata/%s' % (('..%s' % os.sep) * (path.count(os.path.sep) + 2), path), link)


def user_unlink(xchg_path, user, path):
    home = os.path.join(xchg_path, 'users', user)
    link = os.path.join(home, path)

    if os.path.lexists(link):
        os.unlink(link)

    while True:
        path = os.path.split(path)[0]
        path_dir = os.path.join(home, path)

        if path and os.path.isdir(path_dir) and not os.listdir(path_dir):
            os.rmdir(path_dir)
        else:
            break


def user_path_exists(xchg_path, user, path=None):
    if path:
        path = os.path.join(xchg_path, 'users', user, path)
    else:
        path = os.path.join(xchg_path, 'users', user)

    return os.path.exists(path)


def user_mkdir(xchg_path, user):
    path = os.path.join(xchg_path, 'users', user)

    if not os.path.exists(path):
        os.makedirs(path)


def user_rmdir(xchg_path, user):
    path = os.path.join(xchg_path, 'users', user)

    if os.path.exists(path):
        shutil.rmtree(path)


def user_list(xchg_path):
    return os.listdir(os.path.join(xchg_path, 'users'))
