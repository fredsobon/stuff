#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# emwarmer: cache warming website crawler
#           by Vincent Batoufflet <vbatoufflet@e-merchant.com>
#

import codecs
import ConfigParser
import getopt
import hashlib
import HTMLParser
import os.path
import Queue
import sys
import threading
import time
import urllib2
import urlparse


DEFAULT_CRAWL_DEPTH = 5
DEFAULT_CRAWL_RETRY = 0
DEFAULT_WORKER_COUNT = 8

USER_AGENT = 'e-merchant/warmer'


class Crawler(threading.Thread):
    lock = threading.Lock()

    def __init__(self, queue):
        threading.Thread.__init__(self)

        self.kill_received = False
        self.queue = queue

    def run(self):
        global known_urls
        global started

        while processing:
            try:
                url, level, retry = self.queue.get_nowait()
            except Queue.Empty:
                time.sleep(1)
                continue

            status, links, err_msg = crawl_page(url, level=level)

            if opt_verbose:
                path = urlparse.urlparse(url).path

                sys.stdout.write('[%s] (level: %d, retry: %d) url: %s, links: %d\n' %
                    ('err' if status is None else status, level, opt_retry - retry, path, len(links)))

                if err_msg is not None:
                    sys.stdout.write('      %s\n' % err_msg)

            if status != 200:
                if retry > 1:
                    # Re-enqueue new URL
                    self.queue.put((url, level, retry - 1))
            else:
                for url in links:
                    # Stop if maximum level reached
                    if not processing or level >= opt_depth:
                        break

                    url_hash = hashlib.sha1(url).hexdigest()

                    Crawler.lock.acquire()

                    if url_hash in known_urls:
                        Crawler.lock.release()
                    else:
                        known_urls[url_hash] = url
                        Crawler.lock.release()

                        # Enqueue new URL
                        self.queue.put((url, level + 1, opt_retry))

            self.queue.task_done()

            started = True


class Parser(HTMLParser.HTMLParser):
    def __init__(self, base_url):
        HTMLParser.HTMLParser.__init__(self)

        self.base_url = base_url.rstrip('/')
        self.links = set()

    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            for name, value in attrs:
                if name == 'href':
                    # Skip anchor links
                    if value.startswith('#'):
                        continue

                    if value.startswith('//'):
                        # Handle scheme-aware links
                        value = urlparse.urlparse(value).scheme + ':' + value
                    elif not urlparse.urlparse(value).scheme:
                        # Handle relative links
                        value = self.base_url + '/' + value.lstrip('/')

                    self.links.add(value)
                    break


def crawl_page(page_url, level=None):
    # Get base URL information
    parse = urlparse.urlparse(page_url)
    base_url = urlparse.urlunsplit((parse.scheme, opt_headers.get('Host', parse.netloc), '', '', ''))

    # Request page
    request = urllib2.Request(page_url)
    request.add_header('User-Agent', USER_AGENT)

    for key, value in opt_headers.iteritems():
        request.add_header(key, value)

    try:
        links = []
        response = urllib2.urlopen(request)

        if response.info().gettype() == 'text/html':
            # Parse for additional links
            parser = Parser(base_url)
            parser.feed(codecs.getreader('utf-8')(response).read())

            links = [x for x in parser.links if urlparse.urlparse(x).netloc == opt_headers.get('Host', parse.netloc)]

        response.close()

        return response.getcode(), links, None
    except urllib2.HTTPError, e:
        return e.code, [], None
    except Exception, e:
        return None, [], str(e)


def print_usage(fd=sys.stdout):
    fd.write('''
Usage: %(program)s [OPTIONS] URL
       %(program)s [OPTIONS] -c PATH

Cache warming website crawler.

Options:
   -c, --config   set configuration file path
   -h, --help     display this help and exit
   -H, --header   set request header
   -d, --depth    set crawl depth
   -r, --retry    set number of per URL retries
   -v, --verbose  enable verbosity
   -w, --workers  set number of concurrent workers
''' % {'program': os.path.basename(sys.argv[0])})


processing = True
started = False
terminated = False

known_urls = {}

# Parse for command-line arguments
opt_depth = DEFAULT_CRAWL_DEPTH
opt_headers = {}
opt_retry = DEFAULT_CRAWL_RETRY
opt_verbose = False
opt_workers = DEFAULT_WORKER_COUNT

try:
    opts, args = getopt.gnu_getopt(sys.argv[1:], 'c:d:hH:r:vw:',
        ['config=', 'depth=', 'help', 'header=', 'retry=', 'verbose', 'workers='])

    for opt, arg in opts:
        if opt in ('-c', '--config'):
            if not os.path.exists(arg):
                raise getopt.GetoptError('config file was not found')

            # Get options from configuration file
            parser = ConfigParser.ConfigParser()
            parser.optionxform = str
            parser.read(arg)

            for key in ('depth', 'retry', 'workers'):
                globals()['opt_' + key] = parser.getint('main', key)

            if parser.has_option('main', 'verbose'):
                opt_verbose = parser.getboolean('main', 'verbose')

            for key, value in parser.items('headers'):
                opt_headers[key] = value

            if parser.has_option('main', 'url'):
                args.insert(0, parser.get('main', 'url'))
        elif opt in ('-h', '--help'):
            print_usage()
            sys.exit(0)
        elif opt in ('-d', '--depth'):
            if not arg.isdigit():
                raise getopt.GetoptError('depth must be digit')

            opt_depth = int(arg)
        elif opt in ('-H', '--header'):
            key, value = [x.strip() for x in arg.split(': ')]
            opt_headers[key] = value
        elif opt in ('-r', '--retry'):
            if not arg.isdigit():
                raise getopt.GetoptError('retry count must be digit')

            opt_retry = int(arg)
        elif opt in ('-v', '--verbose'):
            opt_verbose = True
        elif opt in ('-w', '--workers'):
            if not arg.isdigit():
                raise getopt.GetoptError('workers count must be digit')

            opt_workers = int(arg)
except getopt.GetoptError, e:
    sys.stderr.write('Error: %s\n' % e)
    print_usage(fd=sys.stderr)
    sys.exit(1)

if len(args) != 1:
    sys.stderr.write('Error: missing URL parameter\n')
    print_usage(fd=sys.stderr)
    sys.exit(1)

# Prepare queue
queue = Queue.Queue()
queue.put((args.pop(), 0, opt_retry))

# Launch crawlers
threads = []

for x in xrange(opt_workers):
    thread = Crawler(queue)
    thread.setDaemon(True)
    thread.start()

    threads.append(thread)

try:
    while True:
        if started and queue.empty():
            processing = False
            break

        time.sleep(1)
except KeyboardInterrupt:
    sys.stderr.write('SIGINT reveived, cancelling requests...\n')
    sys.exit(1)

for thread in threads:
    thread.join()
