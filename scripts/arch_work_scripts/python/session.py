'''
Created on 22 nov. 2011

@author: jmmasson
'''

import socket
import time
import sys
import syslog
from array import array
from protocol import CmdAuthenticate
from protocol import CmdPing
from protocol import CmdEndSession

class Session:

    def __init__(self):
        self.socket = None
        self.timeout = 3.0
        self.buffer = array('B')
        self.error = ''
    
    def open(self, address, port):
        self.address = address
        self.port = int(port)
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(self.timeout)
            self.socket.connect((self.address, self.port))
        except Exception, e:
            print e
            self.error = e
            self.socket = None
        return self.socket != None

    def start(self, user, password):
        try:
            self.send_text(user)
            self.send_text(password)
            self.flush()
            result = self.recieve_short()
            if result == 0:
                self.error = self.recieve_string()
            else:
                dummy = self.recieve_short() # ???
        except Exception, e:
            self.error = str(e)
            result = 0
        return result == 1 

    def end(self):
        try:
            cmd = CmdEndSession()
            result = cmd.execute(self)
        except Exception, e:
            self.error = str(e)
            result = False
        return result

    def authenticate(self, user, password):
        try:
            cmd = CmdAuthenticate()
            result = cmd.execute(self, user, password)
            if not result:
                self.error = cmd.message
        except Exception, e:
            self.error = str(e)
            result = False
        return result

    def ping(self):
        try:
            cmd = CmdPing()
            result = cmd.execute(self)
        except Exception, e:
            print e
            result = False
        return result

    def check(self, address, port, user, password):
        result = False        
        message = []
        message.append('CHECK %s %s' % (address, port))
        time_session_start = time.time()
        if self.open(address, port):
            if self.start(user, password):
                if self.authenticate(user, password):
                    time_ping_start = time.time()
                    result = self.ping()
                    time_ping = time.time() - time_ping_start
                    if result:
                        message.append(' Ping time   = %f seconds' % time_ping)
                    else:
                        message.append(' ERROR Ping time = %f seconds' % time_ping)
                    self.end()
                else:
                    message.append(' ERROR Authenticate\n server message = "%s"\n' % self.error)
                self.close()
            else:
                message.append(' ERROR start session\n server message = "%s"\n' % self.error)
        else:
            message.append(' ERROR open session\n error message = "%s"\n' % self.error)
        time_session = time.time() - time_session_start
        message.append(' Session time = %f seconds' % time_session)
        return message

    def send_byte(self, value):
        self.buffer.append(value)

    def send_short(self, value):
        self.buffer.append(value >> 8)
        self.buffer.append(value & 255)

    def send_int(self, value):
        self.buffer.append(value >> 24)
        self.buffer.append((value >> 16) & 255)
        self.buffer.append((value >> 8) & 255)
        self.buffer.append(value & 255)

    def send_string(self, value):
        self.send_short(len(value))
        for c in value:
            self.buffer.append(ord(c))

    def send_text(self, value):
        self.send_int(len(value))
        for c in value:
            self.buffer.append(ord(c))

    def flush(self):
        self.socket.send(self.buffer)
        self.buffer = array('B')

    def revieve_value(self, size):
        result = 0
        while size > 0:
            result <<= 8;
            chunk = self.socket.recv(1)
            if chunk == '':
                raise RuntimeError("socket connection broken")
            result |= ord(chunk)
            size -= 1
        return result

    def recieve_byte(self):
        chunk = self.socket.recv(1)
        if chunk == '':
            raise RuntimeError("socket connection broken")
        return ord(chunk);

    def recieve_short(self):
        return self.revieve_value(2)

    def recieve_int(self):
        return self.revieve_value(4)

    def recieve_long(self):
        return self.revieve_value(8)

    def recieve_string(self):
        size = self.recieve_short()
        string = self.socket.recv(size)
        if string == '':
            raise RuntimeError("socket connection broken")
        return string 

    def recieve_text(self):
        size = self.recieve_int()
        text = self.socket.recv(size)
        if text == '':
            raise RuntimeError("socket connection broken")
        return text

    def close(self):
        result = True
        try:
            if self.socket:
                self.socket.shutdown(socket.SHUT_RDWR)
                self.socket.close()
        except Exception, e:
            self.error = str(e)
            result = False
        self.socket = None
        return result

if __name__ == '__main__':
    address = sys.argv[1]
    port = int(sys.argv[2])
    username = sys.argv[3]
    password = sys.argv[4]
    result = False        
    message = []
    session = Session()
    if session.open(address, port):
        if session.start(username, password):
            if session.authenticate(username, password):
                time_ping_start = time.time()
                result = session.ping()
                time_ping = time.time() - time_ping_start
                if not result:
                    message.append('ERROR Ping time = %f seconds' % time_ping)
                else:
                    message.append('Ping time = %f seconds' % time_ping)
                session.end()
            else:
                message.append('ERROR Authenticate\n server message = "%s"\n' % session.error)
            session.close()
        else:
            message.append('ERROR start session\n server message = "%s"\n' % session.error)
    else:
        message.append('ERROR open session\n error message = "%s"\n' % session.error)
    if message:
        message.insert(0, '%s:%s' % (address, port))
        syslog.syslog(syslog.LOG_ERR, ', '.join(message))
    print '\n'.join(message)
