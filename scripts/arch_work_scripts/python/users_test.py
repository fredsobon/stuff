'''
Created on 24 sept. 2013

@author: jmmasson
'''
import unittest
import subprocess


class Test(unittest.TestCase):

    def test_1(self):
        output = subprocess.check_output(['./scripts/xchgctl'])
        assert 'usage' in output

    def test_2_useradd(self):
        output = subprocess.check_output(['./scripts/xchgctl',
                                          'useradd',
                                          '-c', 'em',
                                          '-p', '1234',
                                          'user_test'],
                                          stderr=subprocess.STDOUT)
        assert 'OK' in output
        output = subprocess.check_output(['./scripts/xchgctl', 'userlist'])
        assert 'user_test' in output
        uid = 0
        for line in output.split('\n'):
            fields =  line.split()
            if len(fields) == 8:
                if fields[1] == 'user_test':
                    print line
                    uid = int(fields[0])
            else:
                print line
        assert uid >= 10000


    def test_3_userdel(self):
        output = subprocess.check_output(['./scripts/xchgctl',
                                          'userdel',
                                          '-f',
                                          'user_test'],
                                          stderr=subprocess.STDOUT)
        print output
        assert 'OK' in output
