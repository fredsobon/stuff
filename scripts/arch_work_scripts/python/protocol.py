'''
Created on 21 nov. 2011

@author: jmmasson
'''

import threading

class Flow:

    def __init__(self, session, request):
        self.id = id
        self.queue = session.queue
        self.request = request
        self.frame = None
        self.previous_frame = None
        self.logfile = False

    def skip(self, value):
        while value > 0:
            self.read_byte()
            value -= 1

    def read_string(self):
        len = self.read_int()
        value = ''
        while len > 0:
            value += chr(self.read_byte())
            len -= 1
        return value

    def read_name(self):
        len = self.read_short()
        value = ''
        while len > 0:
            value += chr(self.read_byte())
            len -= 1
        return value

    def read_double(self):
        value = 0.0
        self.skip(8)
        return value

    def read_long(self):
        value = self.read_int()
        value <<= 32
        value |= self.read_int()
        return value

    def read_int(self):
        value = self.read_short()
        value <<= 16
        value |= self.read_short()
        return value

    def read_short(self):
        short = self.read_byte()
        short <<= 8
        short |= self.read_byte()
        return short

    def read_byte(self):
        if self.frame == None:
            self.next()
        byte = self.frame.read_byte()
        if self.frame.end_of_buffer():
            self.previous_frame = self.frame
            self.frame = None
        return byte

    def next(self, show = True):
        if self.frame != None:
            if self.logfile:
                self.logfile.write('error next : not frame == None\n')
                self.logfile.write(str(self.frame))
        self.frame = self.queue.get()
#        print 'next_frame \n%s' % self.frame
#        if not self.frame.valid:
#            print 'frame error...'
        while self.frame.request != self.request:
            if self.logfile:
                self.logfile.write('error next : not frame direction\n')
                self.logfile.write(str(self.frame))
#            if show:
#                print 'next_frame error\n%s' % self.frame

            
            self.previous_frame = self.frame
            self.frame = self.queue.get()
#            print 'ERROR repeat next_frame'
#            print self.frame
            
        if self.logfile:
            self.logfile.write(str(self.frame))

class DATA:
    NULL_DATA = 0
    STRING_DATA = 1
    START_LONG_DATA = 2
    END_LONG_DATA = 3
    CURSOR_DATA = 4
    INTEGER_DATA = 5
    DOUBLE_DATA = 6
    END_BIND_VARS = 7
    END_RESULT_SET = 3


class Bind:

    NULL_BIND = 0
    STRING_BIND = 1
    INTEGER_BIND = 2
    DOUBLE_BIND = 3
    BLOB_BIND = 4
    CLOB_BIND = 5
    CURSOR_BIND = 6

    def __init__(self, name):
        self.name = name

    def __repr__(self):
        return '%s(%s)' % (self.name, self.__class__.__name__)

class InBindNull(Bind):
    
    def __init__(self, name):
        Bind.__init__(self, name)

    def __repr__(self):
        return '%s(NULL)' % self.name

class InBindString(Bind):

    def __init__(self, name, value):
        Bind.__init__(self, name)
        self.value = value

    def __repr__(self):
        return '%s(STRING)="%s"' % (self.name, self.value)
        
class InBindInteger(Bind):

    def __init__(self, name, value):
        Bind.__init__(self, name)
        self.value = value

    def __repr__(self):
        return '%s(INTEGER)="%s"' % (self.name, self.value)

class InBindDouble(Bind):

    def __init__(self, name, value, precision, scale):
        Bind.__init__(self, name)
        self.value = value
        self.precision = precision
        self.scale = scale

    def __repr__(self):
        return '%s(DOUBLE)=%s, %s, %s' % (self.name, self.value,
                                          self.precision, self.scale)

class InBindBLOB(Bind):

    def __init__(self, name, size):
        Bind.__init__(self, name)
        self.size = size

    def __repr__(self):
        return '%s(BLOB)=%s' % (self.name, self.size)

class InBindCLOB(Bind):

    def __init__(self, name, size):
        Bind.__init__(self, name)
        self.size = size

    def __repr__(self):
        return '%s(CLOB)=%s' % (self.name, self.size)

class OutBindNull(Bind):

    def __init__(self, name, size):
        Bind.__init__(self, name)
        self.size = size

    def __repr__(self):
        return '%s(NULL)' % self.name

class OutBindString(Bind):

    def __init__(self, name, size):
        Bind.__init__(self, name)
        self.size = size

    def __repr__(self):
        return '%s(STRING)[%d]' % (self.name, self.size)

class OutBindBLOB(Bind):

    def __init__(self, name, size):
        Bind.__init__(self, name)
        self.size = size

    def __repr__(self):
        return '%s(BLOB)[%d]' % (self.name, self.size)

class OutBindCLOB(Bind):

    def __init__(self, name, size):
        Bind.__init__(self, name)
        self.size = size

    def __repr__(self):
        return '%s(CLOB)[%d]' % (self.name, self.size)

class OutBindInteger(Bind):

    def __init__(self, name):
        Bind.__init__(self, name)

    def __repr__(self):
        return '%s(INTEGER)' % self.name

class OutBindDouble(Bind):

    def __init__(self, name):
        Bind.__init__(self, name)

    def __repr__(self):
        return '%s(DOUBLE)' % self.name

class OutBindCursor(Bind):

    def __init__(self, name):
        Bind.__init__(self, name)

    def __repr__(self):
        return '%s(CURSOR)' % self.name

class QueryData:

    def __init__(self):
        self.in_binds = []
        self.out_binds = []

    def read(self, communication):
        in_bind_count = communication.request.read_short()
        self.in_bind_count = in_bind_count
        while in_bind_count > 0:
            in_bind_count -= 1
            name = communication.request.read_name()
            type = communication.request.read_short()
            if type == Bind.NULL_BIND:
                bind = InBindNull(name)
            elif type == Bind.STRING_BIND:
                value = communication.request.read_string()
                bind = InBindString(name, value)
            elif type == Bind.INTEGER_BIND:
                value = communication.request.read_long()
                bind = InBindInteger(name, value)
            elif type == Bind.DOUBLE_BIND:
                value = communication.request.read_long()
                precision = communication.request.read_int()
                scale = communication.request.read_int()
                bind = InBindDouble(name, value, precision, scale)
            elif type == Bind.BLOB_BIND:
                size = communication.request.read_int()
                communication.request.skip(size)
                bind = InBindBLOB(name, size)
            elif type == Bind.CLOB_BIND:
                size = communication.request.read_int()
                communication.request.skip(size)
                bind = InBindCLOB(name, size)
            else:
                bind = None
                print ' error input bind type = %d' % type
                return False
            if bind:
                self.in_binds.append(bind)
        out_bind_count = communication.request.read_short()
        self.out_bind_count = out_bind_count
        while out_bind_count > 0:
            out_bind_count -= 1
            name = communication.request.read_name()
            type = communication.request.read_short()
            if type == Bind.NULL_BIND:
                bind = OutBindNull(name, communication.request.read_int())
            elif type == Bind.STRING_BIND:
                bind = OutBindString(name, communication.request.read_int())
            elif type == Bind.INTEGER_BIND:
                bind = OutBindInteger(name)
            elif type == Bind.DOUBLE_BIND:
                bind = OutBindDouble(name)
            elif type == Bind.BLOB_BIND:
                bind = OutBindBLOB(name, communication.request.read_int())
            elif type == Bind.CLOB_BIND:
                bind = OutBindCLOB(name, communication.request.read_int())
            elif type == Bind.CURSOR_BIND:
                bind = OutBindCursor(name)
            else:
                bind = None
                return False
            if bind:
                self.out_binds.append(bind)
        self.send_column_info = communication.request.read_short()
        return True

    def get_lines(self):
        lines = []
        if self.in_bind_count > 0:
            lines.append('\n  IN_BIND=%d' % self.in_bind_count)
        for bind in self.in_binds:
            lines.append(str(bind))
        if self.out_bind_count > 0:
            lines.append('\n  OUT_BIND=%d' % self.out_bind_count)
        for bind in self.out_binds:
            lines.append(str(bind))
        lines.append('\n  COLUMN_INFO=%s' % self.send_column_info)
        return lines

class Column:

    def __init__(self, column_type_format):
        self.column_type_format = column_type_format

    def read(self, communication):
        self.name = communication.reply.read_name()
        if self.column_type_format == 0:
            self.type = communication.reply.read_short()
        else:
            self.type = communication.reply.read_name()
        self.length = communication.reply.read_int()
        self.precision = communication.reply.read_int()
        self.scale = communication.reply.read_int()
        self.nullable = communication.reply.read_short()
        self.primarykey= communication.reply.read_short()
        self.unique = communication.reply.read_short()
        self.partofkey = communication.reply.read_short()
        self.unsignednumber = communication.reply.read_short()
        self.zerofill = communication.reply.read_short()
        self.binary = communication.reply.read_short()
        self.autoincrement = communication.reply.read_short()
        
    def get_lines(self):
        lines = []
        lines.append('\n   "%s"' % self.name)
        if self.column_type_format == 0:
            lines.append('type=%d' % self.type)
        else:
            lines.append('type="%s"' % self.type)
        lines.append('length=%d' % self.length)
        lines.append('precision=%d' % self.precision)
        lines.append('scale=%d' % self.scale)
        lines.append('nullable=%d' % self.nullable)
        lines.append('primarykey=%d' % self.primarykey)
        lines.append('unique=%d' % self.unique)
        lines.append('partofkey=%d' % self.partofkey)
        lines.append('unsignednumber=%d' % self.unsignednumber)
        lines.append('zerofill=%d' % self.zerofill)
        lines.append('binary=%d' % self.binary)
        lines.append('autoincrement=%d' % self.autoincrement)
        return lines
        
class ReplyResult:
    
    def __init__(self, send_column_info):
        self.send_column_info = send_column_info
        self.columns = []
        self.binds = []
        self.response = 0
        self.message = ''
        self.error_cursor_id = False

    def read(self, communication):
        if communication.reply.frame != None:
            print '\nERROR reply result error, start frame not empty'
            print communication.reply.frame
            return False
        communication.reply.next()
        self.response = communication.reply.read_short()
        self.frame = communication.reply.frame
        self.time = communication.reply.frame.time
        if self.response == 0:
            self.message = communication.reply.read_name()
            self.error_cursor_id = communication.reply.frame != None
            if self.error_cursor_id:
                self.cursor_id = communication.reply.read_short()
            return True
        elif self.response != 1:
            print 'error reply result response'
#            print str(self.frame)
            return False
        self.cursor_id = communication.reply.read_short()
        
        value = communication.reply.read_short()
        if value != 0 and value != 1:
            print ' error reply result suspend_result_set'
#            print str(self.frame)
            return False
            
        self.suspend_result_set = value == 1
        if self.suspend_result_set:
            self.first_row_index = communication.reply.read_long()

        # column_info
        value = communication.reply.read_short()
        if value != 0 and value != 1:
            print ' error reply result knows_actual_rows'
#            print str(self.frame)
            return False
        self.knows_actual_rows = value == 1
        if self.knows_actual_rows:
            self.actual_rows = communication.reply.read_long()
            
        value = communication.reply.read_short()
        if value != 0 and value != 1:
            print ' error reply result knows_affected_rows'
#            print str(self.frame)
            return False
        self.knows_affected_rows = value == 1
        if self.knows_affected_rows:
            self.affected_rows = communication.reply.read_long()
        
        value = communication.reply.read_short()
        if value != 0 and value != 1:
            print ' error reply result sent_column_info'
#            print str(self.frame)
            return False
        self.sent_column_info = value == 1
        self.col_count = communication.reply.read_int()
        
        if self.sent_column_info and self.send_column_info == 1:
            self.column_type_format = communication.reply.read_short()
            col_count = self.col_count
            while col_count > 0:
                col_count -= 1
                column = Column(self.column_type_format)
                column.read(communication)
                self.columns.append(column)

        # --output bind--
        result = True
        while True:
            type = communication.reply.read_short()
            if type == DATA.NULL_DATA:
                self.binds.append((type, None))
            elif type == DATA.STRING_DATA:
                self.binds.append((type, communication.reply.read_string()))
            elif type == DATA.INTEGER_DATA:
                self.binds.append((type, communication.reply.read_long()))
            elif type == DATA.DOUBLE_DATA:
                self.binds.append((type, [communication.reply.read_double(),
                                   communication.reply.read_int(),
                                   communication.reply.read_int()]))
            elif type == DATA.CURSOR_DATA:
                self.binds.append((type, communication.reply.read_short()))
            elif type == DATA.START_LONG_DATA:
                total_size = communication.reply.read_long()
                self.binds.append((type, total_size))
                while communication.reply.read_short() != DATA.END_LONG_DATA: 
                    size = communication.reply.read_int()
                    communication.reply.skip(size)
            elif type == DATA.END_BIND_VARS:
                break
            else:
                print ' error output bind type = %d' % type
#                print str(self.frame)
                result = False
                break
        if communication.reply.frame != None:
            print '\nERROR reply result error, end frame not empty'
            print communication.reply.frame
            return False
        return result

    def get_lines(self):
        lines = []
        if self.response != 1:
            lines.append('\nREPLY : ERROR %d "%s"' % (self.response, 
                                                      self.message))
            if self.error_cursor_id:
                lines.append('cursor_id=%s' % self.cursor_id)
            return lines

        lines.append('\nREPLY : OK')
        lines.append('cursor_id=%s' % self.cursor_id)
        lines.append('suspend=%s' % self.suspend_result_set)
        if self.suspend_result_set:
            lines.append('first_row_index=%s' % self.first_row_index)

        # column_info
        lines.append('\n  COLUMN_INFO:')
        if self.knows_actual_rows:
            lines.append('actual_rows=%s' % self.actual_rows)
        if self.knows_affected_rows:
            lines.append('affected_rows=%s' % self.affected_rows)
        lines.append('sent_column_info=%s' % self.sent_column_info)
        if self.sent_column_info and self.send_column_info == 1:
            lines.append('\n  COLUMN %d type_format=%d' % (self.col_count,
                                                           self.column_type_format))
            for column in self.columns:
                lines.extend(column.get_lines())

        index = 0
        for type, data in self.binds:
            index += 1
            if type == DATA.NULL_DATA:
                lines.append('\n  BIND(%d) NULL_DATA' % index)
            elif type == DATA.STRING_DATA:
                lines.append('\n  BIND(%d) STRING_DATA="%s"' % (index, data))
            elif type == DATA.INTEGER_DATA:
                lines.append('\n  BIND(%d) INTEGER_DATA=%d' % (index, data))
            elif type == DATA.DOUBLE_DATA:
                lines.append('\n  BIND(%d) DOUBLE_DATE=%d,%d,%d' % (index, 
                                                                     data[0],
                                                                     data[1],
                                                                     data[2]))
            elif type == DATA.CURSOR_DATA:
                lines.append('\n  BIND(%d) CURSOR_DATA=%d' % (index, data))
            elif type == DATA.START_LONG_DATA:
                lines.append('\n  BIND(%d) LONG_DATA=%d' % (index, data))               
        return lines

    def get_title(self):
        if self.response != 1:
            return 'ERROR %s' % self.message.rstrip()
        else:
            count = len(self.binds)
            if count > 0:
                return '%d bind variables' % count
            else:
                return 'OK'

class ReplyData:

    def __init__(self):
        self.datas = []

    def read(self, communication):
        if communication.reply.frame != None:
            print '\nERROR reply data error, start frame not empty'
            return False
        if not communication.end_of_result_set:
            communication.reply.next()
#            frame = communication.reply.frame
            self.time = communication.reply.frame.time
            count = 0
            while True:
                count += 1
                type = communication.reply.read_short()
                if type == DATA.NULL_DATA:
                    self.datas.append((type, None))
                elif type == DATA.STRING_DATA:
                    self.datas.append((type, communication.reply.read_string()))
                elif type == DATA.START_LONG_DATA:
                    total_size = communication.reply.read_long()
                    while communication.reply.read_short() != DATA.END_LONG_DATA:
                        size = communication.reply.read_int()
                        communication.reply.skip(size)
                    self.datas.append((type, [total_size, None]))
                elif type == DATA.END_RESULT_SET:
                    communication.end_of_result_set = True
                    break
                else:
                    print 'ERROR result data type = %d (count=%d)' % (type, count)
#                    print 'data header 1 %s' % str(frame.header)
#                    print 'data header 2 %s' % str(communication.reply.frame.header)
                    print '  data count = %s' % len(self.datas)
                    for dt, val in self.datas:
                        print 'type=%s value=%s' % (dt, val)
                    break
        if communication.reply.frame != None:
            print '\nERROR reply data error, end frame not empty'
            print communication.reply.frame
            return False
        return True

    def get_lines(self):
        lines = []
        if self.datas:
            lines.append('\n  DATA')
            for type, data in self.datas:
                if type == DATA.NULL_DATA:
                    lines.append('\n   NULL_DATA')
                elif type == DATA.STRING_DATA:
                    lines.append('\n   STRING_DATA="%s"' % data)
                elif type == DATA.START_LONG_DATA:
                    lines.append('\n   START_LONG_DATA=%d' % data[0])
        return lines

    def get_title(self):
        return '%d datas' % len(self.datas)

class Command:

    NEW_QUERY = 0
    FETCH_RESULT_SET = 1
    ABORT_RESULT_SET = 2
    SUSPEND_RESULT_SET = 3
    RESUME_RESULT_SET = 4
    SUSPEND_SESSION = 5
    END_SESSION = 6
    PING = 7
    IDENTIFY = 8
    COMMIT = 9
    ROLLBACK = 10
    AUTHENTICATE = 11
    AUTOCOMMIT = 12
    REEXECUTE_QUERY = 13
    FETCH_FROM_BIND_CURSOR = 14
    DBVERSION = 15
    BINDFORMAT = 16
    SERVERVERSION = 17
    STATISTICS = 18

    command_names = ['NEW_QUERY', 'FETCH_RESULT_SET', 'ABORT_RESULT_SET',
                     'SUSPEND_RESULT_SET', 'RESUME_RESULT_SET',
                     'SUSPEND_SESSION', 'END_SESSION','PING','IDENTIFY',
                     'COMMIT','ROLLBACK', 'AUTHENTICATE','AUTOCOMMIT',
                     'REEXECUTE_QUERY','FETCH_FROM_BIND_CURSOR',
                     'DBVERSION','BINDFORMAT','SERVERVERSION',
                     'STATISTICS']
    
    def __init__(self, time = ''):
        self.error = False
        self.time = time
        self.send_column_info = 1

    def read(self, communication):
        pass

    def reply_byte(self, communication):
        communication.reply.next()
        self.reply = communication.reply.read_byte()

    def reply_string(self, communication):
        communication.reply.next()
        self.reply = communication.reply.read_name()

class CmdNewQuery(Command):

    def read(self, communication): 
        value = communication.request.read_short()
        if value == 0:
            self.need_new_cursor = True
        elif value == 1:
            self.need_new_cursor = False
            self.cursor_id = communication.request.read_short()
        else:
            print 'NEW_QUERY need_new_cursor = %s' % value
            print communication.request.frame

            self.need_new_cursor = False
            self.error = True
            return False
        self.query = communication.request.read_string()
        self.query_data = QueryData()
        if not self.query_data.read(communication):
            self.error = True
            return False       
        communication.end_of_result_set = False
        self.reply_result = ReplyResult(self.send_column_info)
        if not self.reply_result.read(communication):
            self.error = True
            return False
        self.reply_data = ReplyData()
        if not self.reply_data.read(communication):
            self.error = True
            return False
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : NEW_QUERY')
        try:
            if self.need_new_cursor:
                lines.append('NEED_NEW_CURSOR')
            else:
                lines.append('DONT_NEED_NEW_CURSOR')
                lines.append('cursor_id=%d' % self.cursor_id)
            lines.append('query="%s"' % self.query)        
            lines.extend(self.query_data.get_lines())
            lines.extend(self.reply_result.get_lines())
            lines.extend(self.reply_data.get_lines())
        except Exception, e:
            lines.append(str(e))
        return lines

    def get_request_title(self):
        if self.error:
            query = ''
        else:
            if len(self.query) > 50:
                query = self.query[:50]+'...'
            else:
                query = self.query
            query = query.replace('\t', ' ',50)
            query = query.replace('\n', ' ',50)
            query = query.replace('\r', ' ',50)
            query = query.replace('  ', ' ',50)
        return 'NEW_QUERY "%s"' % query.strip()
    
    def get_reply_title(self):
        if self.error:
            return ''
        if self.reply_result.response == 1:
            return '%s, %s' % (self.reply_result.get_title(),
                               self.reply_data.get_title())
        else:
            return self.reply_result.get_title() 

class CmdFetchResultSet(Command):

    def read(self, communication):
        self.cursor_id = communication.request.read_short()
        self.skip = communication.request.read_long()
        self.rows_id = communication.request.read_long()
        self.reply_data = ReplyData()
        if not self.reply_data.read(communication):
            self.error = True
            return False
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : FETCH_RESULT_SET')
        lines.append('cursor_id=%s' % self.cursor_id)
        lines.append('skip=%s' % self.skip)
        lines.append('rows_id=%s' % self.rows_id)
        lines.extend(self.reply_data.get_lines())
        return lines

    def get_request_title(self):
        return 'FETCH_RESULT_SET'

    def get_reply_title(self):
        return self.reply_data.get_title()

class CmdAbortResultSet(Command):

    def read(self, communication):
        self.cursor_id = communication.request.read_short()
        communication.end_of_result_set = True
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : ABORT_RESULT_SET')
        lines.append('cursor_id=%s' % self.cursor_id)
        return lines

    def get_request_title(self):
        return 'ABORT_RESULT_SET'

    def get_reply_title(self):
        return ''

class CmdSuspendResultSet(Command):

    def read(self, communication):
        self.cursor_id = communication.request.read_short()
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : SUSPEND_RESULT_SET')
        lines.append('cursor_id=%s' % self.cursor_id)
        return lines

    def get_request_title(self):
        return 'SUSPEND_RESULT_SET'

    def get_reply_title(self):
        return ''

class CmdResumeResultSet(Command):

    def read(self, communication):
        self.cursor_id = communication.request.read_short()
        self.skip = communication.request.read_long()
        self.rows_id = communication.request.read_long()
        self.reply_result = ReplyResult(self.send_column_info)
        if not self.reply_result.read(communication):
            self.error = True
            return False        
        self.reply_data = ReplyData()
        if not self.reply_data.read(communication):
            self.error = True
            return False
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : RESUME_RESULT_SET')
        lines.append('cursor_id=%s' % self.cursor_id)
        lines.append('skip=%s' % self.skip)
        lines.append('rows_id=%s' % self.rows_id)
        lines.extend(self.reply_result.get_lines())
        lines.extend(self.reply_data.get_lines())
        return lines

    def get_request_title(self):
        return 'RESUME_RESULT_SET'
    
    def get_reply_title(self):
        if self.reply_result.response == 1:
            return '%s, %s' % (self.reply_result.get_title(),
                               self.reply_data.get_title())
        else:
            return self.reply_result.get_title() 

class CmdSuspendSession(Command):

    def read(self, communication):
        return True

    def get_lines(self):
        return ['REQUEST : SUSPEND_SESSION']

    def get_request_title(self):
        return 'SUSPEND_SESSION'

    def get_reply_title(self):
        return ''

class CmdEndSession(Command):

    def read(self, communication):
        return True

    def execute(self, session):
        session.send_short(Command.END_SESSION)
        session.flush()
        return True

    def get_lines(self):
        return ['REQUEST : END_SESSION']

    def get_request_title(self):
        return 'END_SESSION'

    def get_reply_title(self):
        return ''

class CmdPing(Command):

    def read(self, communication):
        self.reply_byte(communication)
        return True

    def execute(self, session):
        session.send_short(Command.PING)
        session.flush()
        return session.recieve_byte() == 1

    def get_lines(self):
        lines = []
        lines.append('REQUEST : PING')
        lines.append('\nREPLY : %s' % self.reply)
        return lines

    def get_request_title(self):
        return 'PING'

    def get_reply_title(self):
        if self.reply == 1:
            return 'OK'
        else:
            return 'ERROR'

class CmdIdentify(Command):

    def read(self, communication):
        self.reply_string(communication)
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : IDENTIFY')
        lines.append('\nREPLY : "%s"' % self.reply)
        return lines

    def get_request_title(self):
        return 'IDENTIFY'

    def get_reply_title(self):
        return self.reply

class CmdCommit(Command):

    def read(self, communication):
        self.reply_byte(communication)
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : COMMIT')
        lines.append('\nREPLY : %s' % self.reply)
        return lines

    def get_request_title(self):
        return 'COMMIT'

    def get_reply_title(self):
        return self.reply

class CmdRollBack(Command):

    def read(self, communication):
        self.reply_byte(communication)
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : ROLLBACK')
        lines.append('\nREPLY : %s' % self.reply)
        return lines

    def get_request_title(self):
        return 'ROLLBACK'

    def get_reply_title(self):
        return self.reply

class CmdAuthenticate(Command):

    def __init__(self, time = '', request = True):
        Command.__init__(self, time)
        self.request = request
        
    def read(self, communication):
        self.user = communication.request.read_string()
        self.password = communication.request.read_string()
        communication.reply.next()
        self.result = communication.reply.read_short()
        if self.result == 0:
            self.message =  communication.reply.read_name()
        else:
            if not self.request:
                communication.reply.read_short()
        return True

    def execute(self, session, user, password):
        if self.request:
            session.send_short(Command.AUTHENTICATE)
        session.send_text(user)
        session.send_text(password)
        session.flush()
        result = session.recieve_short()
        if result == 0:
            self.message = session.recieve_string()
        else:
            self.message = ''
        return result == 1

    def get_lines(self):
        lines = []
        if self.request:
            lines.append('REQUEST : AUTHENTICATE')
        else:
            lines.append('START SESSION')
        lines.append('user="%s"' % self.user)
        lines.append('password="%s"' % self.password)
        if self.result == 0:
            lines.append('\nREPLY : ERROR %s' % self.message)
        elif self.result == 1:
            lines.append('\nREPLY : OK')        
        return lines

    def get_request_title(self):
        if self.request:
            return 'AUTHENTICATE'
        else:
            return 'START SESSION'

    def get_reply_title(self):
        if self.result == 1:
            return 'OK'
        else:
            return self.message

class CmdAutoCommit(Command):

    def read(self, communication):
        self.value = communication.request.read_byte()
        self.reply_byte(communication)
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : AUTO_COMMIT')
        lines.append('bool=%d' % self.value)
        lines.append('\nREPLY : %s' % self.reply)
        return lines

    def get_request_title(self):
        return 'AUTO_COMMIT'

    def get_reply_title(self):
        return self.reply

class CmdReexecuteQuery(Command):

    def read(self, communication):
        self.cursor_id = communication.request.read_short()
        self.query_data = QueryData()
        if not self.query_data.read(communication):
            self.error = True
            return False
        self.reply_result = ReplyResult(self.send_column_info)
        if not self.reply_result.read(communication):
            self.error = True
            return False
        self.reply_data = ReplyData()
        if not self.reply_data.read(communication):
            self.error = True
            return False
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : REEXECUTE_QUERY')
        lines.append('cursor_id=%d' % self.cursor_id)
        lines.extend(self.query_data.get_lines())
        lines.extend(self.reply_result.get_lines())
        lines.extend(self.reply_data.get_lines())
        return lines

    def get_request_title(self):
        return 'REEXECUTE_QUERY'

    def get_reply_title(self):
        if self.reply_result.response == 1:
            return '%s, %s' % (self.reply_result.get_title(),
                               self.reply_data.get_title())
        else:
            return self.reply_result.get_title() 

class CmdFetchFromBindCursor(Command):

    def read(self, communication):
        self.cursor_id = communication.request.read_short()
        self.column_info = communication.request.read_short()
        communication.end_of_result_set = False
        self.reply_result = ReplyResult(self.send_column_info)
        if not self.reply_result.read(communication):
            self.error = True
            return False
        self.reply_data = ReplyData()
        if not self.reply_data.read(communication):
            self.error = True
            return False
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : FETCH_FROM_BIND_CURSOR')
        lines.append('cursor_id=%d' % self.cursor_id)
        lines.append('column_info="%s"' % self.column_info)
        lines.extend(self.reply_result.get_lines())
        try:
            lines.extend(self.reply_data.get_lines())
        except:
            pass
        return lines

    def get_request_title(self):
        return 'FETCH_FROM_BIND_CURSOR'

    def get_reply_title(self):
        if self.reply_result.response == 1:
            return '%s, %s' % (self.reply_result.get_title(),
                               self.reply_data.get_title())
        else:
            return self.reply_result.get_title() 

class CmdDBVersion(Command):

    def read(self, communication):
        self.reply_string(communication)
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : DB_VERSION')
        lines.append('\nREPLY : "%s"' % self.reply)
        return lines

    def get_request_title(self):
        return 'DB_VERSION'

    def get_reply_title(self):
        reply = self.reply.replace('\\n', ' ')
        return reply.strip()

class CmdBindFormat(Command):

    def read(self, communication):
        self.reply_string(communication)
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : BIND_FORMAT')
        lines.append('\nREPLY : "%s"' % self.reply)
        return lines

    def get_request_title(self):
        return 'BIND_FORMAT'

    def get_reply_title(self):
        return self.reply

class CmdServerVersion(Command):

    def read(self, communication):
        self.reply_string(communication)
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : SERVER_VERSION')
        lines.append('\nREPLY : "%s"' % self.reply)
        return lines

    def get_request_title(self):
        return 'SERVER_VERSION'

    def get_reply_title(self):
        return self.reply

class CmdStatistics(Command):

    def read(self, communication):
        self.reply_string(communication)
        return True

    def get_lines(self):
        lines = []
        lines.append('REQUEST : STATISTICS')
        lines.append('\nREPLY : "%s"' % self.reply)
        return lines

    def get_request_title(self):
        return 'STATISTICS'

    def get_reply_title(self):
        return self.reply

class Communication(threading.Thread):

    command_def = [CmdNewQuery,
                   CmdFetchResultSet,
                   CmdAbortResultSet,
                   CmdSuspendResultSet,
                   CmdResumeResultSet,
                   CmdSuspendSession,
                   CmdEndSession,
                   CmdPing,
                   CmdIdentify,
                   CmdCommit,
                   CmdRollBack,
                   CmdAuthenticate,
                   CmdAutoCommit,
                   CmdReexecuteQuery,
                   CmdFetchFromBindCursor,
                   CmdDBVersion,
                   CmdBindFormat,
                   CmdServerVersion,
                   CmdStatistics]

    def __init__(self, listener, session, logfile=False):
        threading.Thread.__init__(self, name='Communication')
        self.id = session.id
        self.end_of_result_set = True
        self.listener = listener
        self.request = Flow(session, True)
        self.reply = Flow(session, False)
        if logfile:
            self.logfile = open('./log/%s.log' % session.id, 'w')
        else:
            self.logfile = False
        self.request.logfile = self.logfile
        self.reply.logfile = self.logfile

    def run(self):
        show = False
        while True:
            self.request.next(show)
            show = True
            frame = self.request.frame
            if self.request.frame.first:
                command = CmdAuthenticate(frame.time, False)
                command.frame = frame
                command.read(self)
                if self.logfile:
                    self.logfile.write(' '.join(command.get_lines()))
                    self.logfile.write('\n')
                self.listener.update_cb(self.id, command)
            else:
                time = frame.time
                code = self.request.read_short()
                if code >= 0 and code < 19:
                    command = Communication.command_def[code](time)
                    command.frame = frame
                    command.read(self)
                    if self.logfile:
                        self.logfile.write(' '.join(command.get_lines()))
                        self.logfile.write('\n')
                    self.listener.update_cb(self.id, command)
                else:
                    str = 'code %s error...' % code
                    if self.logfile:
                        self.logfile.write('%s\n' % str)
                    self.listener.error_cb('%s\n\n' % str)
                    print str

    def stop(self):
        self._Thread__stop()

    def log(self, message):
        if self.logfile:
            self.logfile.write(message)
            self.logfile.write('\n')
            self.logfile.flush()
