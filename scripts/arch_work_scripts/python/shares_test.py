'''
Created on 24 sept. 2013

@author: jmmasson
'''
import unittest
import subprocess


class Test(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.user = 'user_test'
        cls.path = 'application/feeds/rep1'
        subprocess.check_output(['./scripts/xchgctl',
                                 'useradd',
                                 '-c', 'em',
                                 '-p', '1234',
                                 cls.user])
        Test._show_user_infos()

    @classmethod
    def tearDownClass(cls):
        print 'tearDownClass user del', Test.user
        Test._show_user_infos()

    def test_1_sharelist(self):
        print 'test sharelist'
        output = self._check_output(['./scripts/xchgctl', 'sharelist'])
        assert not 'Error' in output

    def _inList(self, lines, writable):
        for line in lines.split('\n'):
            fields = line.split()
            if len(fields) == 3:
                if fields[0] == Test.path and \
                    fields[1] == Test.user and \
                    fields[2] == writable:
                    return True
        return False

    def _check_output(self, args):
        print ' '.join(args)
        output = subprocess.check_output(args, stderr=subprocess.STDOUT)
        print output
        return output

    @staticmethod
    def _show_user_infos():
        print subprocess.check_output(['./scripts/xchgctl', 'sharelist'],
                                          stderr=subprocess.STDOUT)
        print subprocess.check_output(['./scripts/xchgctl',
                                          'acllist', '-l', Test.user],
                                          stderr=subprocess.STDOUT)
        print subprocess.check_output(['tree', '/srv/exchange/users/%s' % Test.user],
                                          stderr=subprocess.STDOUT)

    def test_2_shareadd(self):
        print 'test shareadd'
        output = self._check_output(['./scripts/xchgctl',
                                     'shareadd',
                                     '-l', Test.user,
                                     '-p', Test.path,
                                     '-w', '-c'])
        print subprocess.check_output(['./scripts/xchgctl',
                                          'acllist', '-l', Test.user],
                                          stderr=subprocess.STDOUT)
        print subprocess.check_output(['tree', '/srv/exchange/users/%s' % Test.user],
                                          stderr=subprocess.STDOUT)

        self.assertNotIn('Error', output, output)
        output = self._check_output(['./scripts/xchgctl',
                                     'sharelist'])
        assert self._inList(output, '1')
 
    def test_3_sharemod(self):
        print 'test sharemod'
        output = self._check_output(['./scripts/xchgctl',
                                     'sharemod',
                                     '-l', Test.user,
                                     '-p', '/srv/exchange/%s' % Test.path])
        Test._show_user_infos()
        assert not 'Error' in output
        output = subprocess.check_output(['./scripts/xchgctl',
                                          'sharelist'],
                                          stderr=subprocess.STDOUT)
        assert self._inList(output, '0')
   
    def test_4_sharedel(self):
        print 'test sharedel'
        output = self._check_output(['./scripts/xchgctl',
                                     'sharedel',
                                     '-l', Test.user,
                                     '-p', Test.path,
                                     '-f'])
        Test._show_user_infos()
        assert not 'Error' in output
 
    def test_5_sharecollid(self):
        print 'share collid'
        output = self._check_output(['./scripts/xchgctl',
                                    'shareadd',
                                    '-l', Test.user,
                                    '-p', 'feeds/rep1/rep2/rep3',
                                    '-w', '-c'])
        assert not 'Error' in output
        Test._show_user_infos()
        output = self._check_output(['./scripts/xchgctl',
                                    'shareadd',
                                    '-l', Test.user,
                                    '-p', 'feeds/rep1/rep2/rep3/rep4',
                                    '-w'])
        assert 'Error' in output
        Test._show_user_infos()
        output = self._check_output(['./scripts/xchgctl',
                                    'shareadd',
                                    '-l', Test.user,
                                    '-p', 'feeds/rep1/rep2',
                                    '-w'])
        assert 'Error' in output
        Test._show_user_infos()
        output = self._check_output(['./scripts/xchgctl',
                                    'shareadd',
                                    '-l', Test.user,
                                    '-p', 'feeds/rep1/rep2/rep3_1',
                                    '-w'])
        Test._show_user_infos()
        assert not 'Error' in output

    def test_6_userdel(self):
        print 'user del', Test.user
        output = subprocess.check_output(['./scripts/xchgctl', 'userdel',
                                          '-f', Test.user])
        print output
        assert 'OK' in output
        assert not Test.user in subprocess.check_output(['./scripts/xchgctl', 'sharelist',
                                                                      '-l', Test.user],
                                                                     stderr=subprocess.STDOUT)
        assert 'Error' in subprocess.check_output(['./scripts/xchgctl',
                                                   'acllist', '-l', Test.user],
                                                  stderr=subprocess.STDOUT)
        assert '0 directories, 0 files'  in subprocess.check_output(['tree', '/srv/exchange/users/%s' % Test.user],
                                                                    stderr=subprocess.STDOUT)
