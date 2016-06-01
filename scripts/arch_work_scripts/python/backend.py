# -*- coding: utf-8 -*-

import base64
import hashlib
import MySQLdb.cursors
import os


class Backend:
    def __init__(self, host, port, db, user, passwd):
        self.db = MySQLdb.connect(host=host, port=port, db=db, user=user, passwd=passwd,
            cursorclass=MySQLdb.cursors.DictCursor)

    def __del__(self):
        if hasattr(self, 'db'):
            self.db.close()

    def domain_exists(self, login):
        domain_id = None

        cur = self.db.cursor()
        cur.execute("SELECT id FROM domains WHERE user_id = %s" % self.user_get_id(login))

        if cur.rowcount > 0:
            domain_id = cur.fetchone()['id']

        cur.close()

        return domain_id is not None

    def domain_get_id(self, name):
        domain_id = None

        cur = self.db.cursor()
        cur.execute("SELECT id FROM domains WHERE name = '%s'" % MySQLdb.escape_string(name))

        if cur.rowcount > 0:
            domain_id = cur.fetchone()['id']

        cur.close()

        return domain_id

    def domain_get_name(self, username):
        domain_name = None

        cur = self.db.cursor()
        cur.execute("SELECT domains.name FROM domains, users WHERE domains.user_id = users.id AND users.login = '%s'" % MySQLdb.escape_string(username))

        if cur.rowcount > 0:
            domain_name = cur.fetchone()['name']

        cur.close()

        return domain_name

    def domain_list(self, filter=None):
        cur = self.db.cursor()

        cur.execute('''
            SELECT domains.id, users.login, domains.name
            FROM domains, users
            WHERE domains.user_id = users.id
            %s
            ORDER BY id
        ''' % ("AND name LIKE '%%%s%%'" % MySQLdb.escape_string(filter) if filter else ''))

        result = list(cur.fetchall())

        cur.close()

        return result

    def domain_set(self, **kwargs):
        args = []

        if kwargs.get('login') and not 'modify' in kwargs:
            args.append(('user_id', "%s" % self.user_get_id(kwargs.get('login'))))

        if kwargs.get('name'):
            args.append(('name', "'%s'" % MySQLdb.escape_string(kwargs.get('name'))))

        cur = self.db.cursor()

        if len(args) > 0:
            if 'modify' in kwargs:
                query = "UPDATE domains SET %s WHERE user_id = %s" % (', '.join([x + ' = ' + y for x, y in args]),
                    self.user_get_id(kwargs.get('login')))
            else:
                query = 'INSERT INTO domains (%s) VALUES (%s)' % tuple([', '.join(x) for x in zip(*args)])
            cur.execute(query)
            self.db.commit()

        cur.close()

    def domain_unset(self, login):
        user_id = self.user_get_id(login)

        if not user_id:
            return False

        cur = self.db.cursor()
        cur.execute("DELETE FROM domains WHERE user_id = %d" % user_id)
        cur.close()

        self.db.commit()

    def user_exists(self, login):
        return self.user_get_id(login) is not None

    def user_get_id(self, login):
        user_id = None

        cur = self.db.cursor()
        cur.execute("SELECT id FROM users WHERE login = '%s'" % MySQLdb.escape_string(login))

        if cur.rowcount > 0:
            user_id = cur.fetchone()['id']

        cur.close()

        return user_id

    def user_list(self, filter=None):
        cur = self.db.cursor()

        cur.execute('''
            SELECT users.id, login, accessed, expires, allow_ftp, allow_sftp, issue_ref, clients.name, gid
            FROM users, clients
            WHERE users.client_id = clients.id
            %s
            ORDER BY id
        ''' % ("AND login LIKE '%%%s%%'" % MySQLdb.escape_string(filter) if filter else ''))

        result = list(cur.fetchall())

        cur.close()

        return result

    def user_set(self, **kwargs):
        args = []

        if kwargs.get('login') and not 'modify' in kwargs:
            args.append(('login', "'%s'" % MySQLdb.escape_string(kwargs.get('login'))))

        if kwargs.get('password'):
            args.append(('password', "'%s'" % MySQLdb.escape_string('{sha1}' +
                base64.b64encode(hashlib.sha1(kwargs.get('password')).digest()))))

        if kwargs.get('expires'):
            args.append(('expires', "'%s'" % MySQLdb.escape_string(kwargs.get('expires'))))

        if kwargs.get('protocols'):
            protocols = [x.strip().lower() for x in kwargs.get('protocols').split(',')]
            args.append(('allow_ftp', '%s' % ('TRUE' if 'ftp' in protocols else 'FALSE')))
            args.append(('allow_sftp', '%s' % ('TRUE' if 'sftp' in protocols else 'FALSE')))

        if kwargs.get('issue'):
            args.append(('issue_ref', "'%s'" % MySQLdb.escape_string(kwargs.get('issue'))))

        if kwargs.get('gid'):
            args.append(('gid', "'%s'" % MySQLdb.escape_string(kwargs.get('gid'))))

        cur = self.db.cursor()

        if kwargs.get('client'):
            cur.execute("SELECT id FROM clients WHERE name = '%(client)s' OR tag = '%(client)s'" %
                {'client': MySQLdb.escape_string(kwargs.get('client'))})

            args.append(('client_id', MySQLdb.escape_string(str(cur.fetchone()['id']))))

        if len(args) > 0:

            if 'modify' in kwargs:
                query = "UPDATE users SET %s WHERE login = '%s'" % (', '.join([x + ' = ' + y for x, y in args]),
                    MySQLdb.escape_string(kwargs.get('login')))
            else:
                query = 'INSERT INTO users (%s) VALUES (%s)' % tuple([', '.join(x) for x in zip(*args)])
            cur.execute(query)
            self.db.commit()

        cur.close()

    def user_unset(self, login):
        user_id = self.user_get_id(login)

        if not user_id:
            return False

        cur = self.db.cursor()
        cur.execute("DELETE FROM shares WHERE user_id = %d" % user_id)
        cur.execute("DELETE FROM users WHERE id = %d" % user_id)
        cur.close()

        self.db.commit()

    def share_contains(self, user_id, path):
        path = os.path.split(path)[0]

        while path:
            share_id = self.share_id(user_id, path)

            if share_id is not None:
                return share_id

            path = os.path.split(path)[0]

        return None

    def share_delete(self, share_id):
        cur = self.db.cursor()
        cur.execute("DELETE FROM shares WHERE id = %s" % share_id)
        cur.close()

        self.db.commit()

    def share_exists(self, user_id, path):
        return self.share_id(user_id, path) is not None

    def share_get_path(self, share_id):
        result = None

        cur = self.db.cursor()

        cur.execute('SELECT share_path FROM shares WHERE id = %d' % share_id)

        if cur.rowcount > 0:
            result = cur.fetchone()['share_path']

        cur.close()

        return result

    def share_id(self, user_id, path):
        share_id = None

        cur = self.db.cursor()

        cur.execute("SELECT id FROM shares WHERE user_id = %s AND share_path = '%s'" %
            (user_id, MySQLdb.escape_string(path)))

        if cur.rowcount > 0:
            share_id = cur.fetchone()['id']

        cur.close()

        return share_id

    def share_insert(self, user_id, path, writable, acl):
        args = [
            ('user_id', str(user_id)),
            ('share_path', "'%s'" % MySQLdb.escape_string(path)),
            ('writable', str(writable)),
            ('acl', str(acl))
        ]

        cur = self.db.cursor()
        cur.execute("INSERT INTO shares (%s) VALUES (%s)" % tuple([', '.join(x) for x in zip(*args)]))
        cur.close()

        self.db.commit()

    def share_is_acl_set(self, share_id):
        is_acl_set = None

        cur = self.db.cursor()

        cur.execute("SELECT acl FROM shares WHERE id = %s" % (share_id))

        if cur.rowcount > 0:
            is_acl_set = cur.fetchone()['acl']

        cur.close()

        return is_acl_set

    def share_intersect(self, user_id, path):
        result = None

        cur = self.db.cursor()

        query = '''
            SELECT id FROM shares
            WHERE user_id = %s
            AND share_path LIKE '%s/%%'
        ''' % (user_id, MySQLdb.escape_string(path))

        cur.execute(query)

        if cur.rowcount > 0:
            result = cur.fetchone()['id']

        cur.close()

        return result

    def share_list(self, user_id=None):
        cur = self.db.cursor()

        cur.execute('''
            SELECT shares.share_path, users.login, shares.writable, shares.acl
            FROM shares
            INNER JOIN users ON users.id = shares.user_id
            %s
            ORDER BY shares.share_path
        ''' % ('WHERE shares.user_id=%d' % user_id if user_id is not None else ''))

        result = list(cur.fetchall())

        cur.close()

        return result

    def share_update(self, share_id, writable):
        args = [
            ('writable', str(writable)),
        ]

        cur = self.db.cursor()
        cur.execute("UPDATE shares SET %s WHERE id = %s" % (', '.join([x + ' = ' + y for x, y in args]), share_id))
        cur.close()

        self.db.commit()
