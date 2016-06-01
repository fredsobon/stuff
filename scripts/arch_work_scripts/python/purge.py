# -*- coding: utf-8 -*-

from dataxchg.command import get_backend, load_config
import httplib
import logging
import logging.handlers


def log_handler():
    my_logger = logging.getLogger()
    my_logger.setLevel(logging.DEBUG)

    handler = logging.handlers.SysLogHandler(address='/dev/log')
    formatter = logging.Formatter('purge-static: %(message)s')

    # handler = logging.StreamHandler()
    # formatter = logging.Formatter('%(levelname)s %(message)s')

    handler.setFormatter(formatter)

    my_logger.addHandler(handler)

    return my_logger


def purge_static(ftp_user, ftp_path):

    global logger
    logger = log_handler()

    # Get static domain URL from backend
    backend = get_backend()
    domain = backend.domain_get_name(ftp_user)

    if not domain:
        # No associated domain URL, nothing to do
        return True

    # Strip 3 folders from FTP path (client + base static folder)
    url_path = '/' + ftp_path.split('/', 4)[-1]

    # NG
    static_purge(domain, url_path)


def static_purge(domain_name, path):

    parser = load_config()

    for static_host in [x.strip() for x in parser.get('main', 'static_host').split(',')]:
        try:
            logger.debug('Connecting to %s' % static_host.split('.')[0])

            conn = httplib.HTTPConnection(static_host, timeout=2)
            conn.request('PURGE', path, headers=dict(Host=domain_name))
            resp = conn.getresponse()

            if resp.status == 200:
                logger.info("flushing http://%s/%s (%s) done" % (
                    domain_name,
                    path,
                    static_host.split('.')[0]
                    ))
            else:
                logger.error("Error: %s" % resp.reason)

        except Exception, e:
                logger.error("Error: %s" % e)


def cdnetworks_flush_external(padname, path):
    import subprocess

    flush = subprocess.Popen(['/usr/local/bin/panther_purge', padname, path], stdin=None, stdout=subprocess.PIPE)
    flush_reply = flush.communicate()[0]
    if flush.returncode == 0:
        logger.info("flushing http://%s/%s (%s) done" % (
            padname,
            path,
            'Panther SOAP'
        ))
    else:
        logger.error("Error: flushing http://%s/%s (%s) failed (%s)" % (
            padname,
            path,
            'Panther SOAP',
            flush_reply
        ))


def cdnetworks_flush(padname, path):
    import urllib
    import json
    from urlparse import urlparse

    parser = load_config()

    params = urllib.urlencode({
        'user': parser.get('main', 'cdn_user'),
        'pass': parser.get('main', 'cdn_passwd'),
        'pad': padname,
        'type': 'item',
        'output': 'json',
        'path': path}
    )

    try:
        cdnetworks_api = urlparse(parser.get('main', 'cdn_uri'))

        conn = httplib.HTTPSConnection(parser.get('main', 'proxy_host'), int(parser.get('main', 'proxy_port')))
        conn.set_tunnel(cdnetworks_api.netloc, 443)
        conn.request('POST', cdnetworks_api.path, params)
        resp = conn.getresponse()

        if resp.status == 200:
            json_resp = json.loads(resp.read())
            if json_resp['resultCode'] == 200:
                logger.info("flushing http://%s/%s (%s) done" % (
                    padname,
                    path,
                    cdnetworks_api.netloc
                ))
            else:
                logger.error("Error: flushing http://%s/%s (%s) failed (%d - %s)" % (
                    padname,
                    path,
                    cdnetworks_api.netloc,
                    json_resp['resultCode'],
                    json_resp['details'],
                ))
        else:
            logger.error("Error: %s" % resp.reason)

    except Exception, e:
            logger.error("Error: %s" % e)

# vim: ft=python
