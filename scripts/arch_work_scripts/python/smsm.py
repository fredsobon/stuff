#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 et
#
# SMS sender/receiver for E-merchant monitoring
# ---------------------------------------------
# Author: Marc Falzon <m.falzon@pixmania-group.com>
#
# Required 3rd-party modules:
# - argparse (if Python < 2.7)
# - sms (http://pypi.python.org/pypi/sms)
# - yaml (http://pyyaml.org/)


import sys
import time
import argparse
import urllib2
from messaging import sms
import yaml
from urllib import urlencode


mblox_nr_tpl = '''<?xml version="1.0" encoding="ISO-8859-1" ?>
<NotificationRequest Version="3.5">
<NotificationHeader>
<PartnerName>%s</PartnerName>
<PartnerPassword>%s</PartnerPassword>
</NotificationHeader>
<NotificationList BatchID="1">
%s
</NotificationList>
</NotificationRequest>'''

mblox_notification_tpl = '''<Notification SequenceNumber="%d" MessageType="SMS">
<Message><![CDATA[%s]]></Message>
<Profile>20443</Profile>
<SenderID Type="Alpha">Monitoring</SenderID>
<Subscriber>
<SubscriberNumber>%s</SubscriberNumber>
</Subscriber>
</Notification>'''

parser = argparse.ArgumentParser(description='SMS sender/receiver for E-merchant monitoring')

parser.add_argument('-c', '--configuration', metavar='FILE', help='configuration file')
parser.add_argument('-d', '--debug', action='store_true', help='be verbose (debug)')
parser.add_argument('-n', '--recipients', metavar='LIST',
    help='LIST is comma-separated recipients telephone numbers ("+XX"-prefixed), \
    overriding recipients in configuration file')
parser.add_argument('-r', '--receive', action='store_true', help='receive mode')
parser.add_argument('-s', '--send', action='store_true', help='send mode')
parser.add_argument('-t', '--text', help='text to send (quoted)')
parser.add_argument('-g', '--gateway', help='gateway to use (web|modem)')

args = parser.parse_args()


if (args.receive and args.send) or (not args.receive and not args.send):
    parser.exit(1, 'error: you must use either --send (-s) or --receive (-r).\nUse -h for usage.\n')
if not args.configuration:
    parser.exit(1, 'error: you must provide a configuration file (-c).\nUse -h for usage.\n')

try:
    f = open(args.configuration, 'r')
    conf = yaml.load(f)
    f.close()
except IOError:
    print('error: unable to read configuration file at %s' % args.configuration)
    sys.exit(1)


def debug(text):
    print('[debug] %s %s' % (time.strftime('%d/%m/%Y %H:%M:%S', time.localtime()), text))

    return True


def log(text):
    f = open(conf['global']['logfile'], 'a+')
    f.write('%s %s\n' % (time.strftime('%d/%m/%Y %H:%M:%S', time.localtime()), text))
    f.close()

    return True


def process_message(msg):
    action = msg.text[:1].lower()

    if not action.endswith(' ') and action[0] not in conf['receive']['actions'].keys():
        if conf['global']['logging']:
            log('received message "%s" from %s matches no action, discarding' % (msg.text, msg.number))
        return False
    else:
        msg.text = msg.text.lower()

        if conf['global']['logging']:
            log('received message "%s" from %s' % (msg.text, msg.number))

        if action[0] == 's':
            subscribe(msg)
        elif action[0] == 'u':
            unsubscribe(msg)
        #elif action[0] == 'd':
        #    downtime(msg)


def receive_mode(modem):
    for msg in modem.messages():
        msg.text = msg.text.rstrip()

        if args.debug:
            debug('fetched message "%s" from %s' % (msg.text, msg.number))

        process_message(msg)
        time.sleep(5)
        msg.delete()

    return True


def store_conf():
    try:
        f = open(args.configuration, 'w')
        yaml.dump(conf, f, indent=2, default_flow_style=False)
        f.close()
        dumped = True
    except IOError:
        dumped = False
        if args.debug:
            debug('error while storing configuration to file %s' % args.configuration)
        if conf['global']['logging']:
            log('error while storing configuration to file %s' % args.configuration)

    return True if dumped else False


def send_mode(gateway, modem=None):
    text = args.text[:130] + '...' if len(args.text) >= 140 else args.text
    text = text.replace('\t', ' ')
    text = text.translate(None,'[]=^')

    if args.gateway == 'modem':
        for recipient in conf['send']['recipients']:
            try:
                modem.send(recipient, text)
                if args.debug:
                    debug('sent message "%s" to %s' % (text, recipient))
                if conf['global']['logging']:
                    log('sent message "%s" to %s (via modem)' % (text, recipient))
            except sms.ModemError, e:
                if args.debug:
                    debug('error occurred while sending message "%s" to %s (%s)' % (text, recipient, e))
                if conf['global']['logging']:
                    log('error occurred while sending message "%s" to %s' % (text, recipient))
            time.sleep(5)
    else:
        notification_seqnum = 1
        recipients = ''
        notifications = ''

        for recipient in conf['send']['recipients']:
            notifications += mblox_notification_tpl % (
                notification_seqnum,
                text,
                recipient[1:],
            )
            notification_seqnum += 1

        xmldata = {'XMLDATA': mblox_nr_tpl %
            (
                conf['mblox']['username'],
                conf['mblox']['password'],
                notifications,
            )
        }

        if args.debug:
            debug('sending message "%s" to Mblox for %s' % (text, ', '.join(conf['send']['recipients'])))

        try:
            if conf['global']['proxy']:
                urllib2.install_opener(urllib2.build_opener(urllib2.ProxyHandler({'http': conf['global']['proxy']})))

            u = urllib2.urlopen(conf['mblox']['url'], urlencode(xmldata), 10)

            if conf['global']['logging']:
                log('sent message "%s" to %s (via web)' % (text, ', '.join(conf['send']['recipients'])))

            if args.debug:
                print(u.read())
        except (urllib2.URLError, urllib2.HTTPError), e:
            if args.debug:
                debug('error occurred while sending notification request to Mblox (%s)'
                    % (e.reason if 'reason' in e.__dict__ else 'error ' + str(e.code)))
            if conf['global']['logging']:
                log('error occurred while sending notification request to Mblox (%s)'
                    % (e.reason if 'reason' in e.__dict__ else 'error ' + str(e.code)))

    return True


def subscribe(msg):
    if not msg.number in conf['send']['recipients']:
        conf['send']['recipients'].append(msg.number)

    if store_conf():
        modem.send(msg.number, 'O hai! Subscription confirmed (send "u" to unsubscribe).')
        if conf['global']['logging']:
           log('%s subscribed to monitoring' % msg.number)

    return True


def unsubscribe(msg):
    if msg.number in conf['send']['recipients']:
        conf['send']['recipients'].remove(msg.number)

    if store_conf():
        modem.send(msg.number, 'Unsubscription confirmed. See you!')
        if conf['global']['logging']:
           log('%s unsubscribed from monitoring' % msg.number)

    return True


if args.gateway == 'modem':
    try:
        modem = sms.Modem(conf['modem']['device'])
    except:
        print('error: modem is unavailable, exiting.')
        sys.exit(2)

if args.send:
    if not args.text:
        parser.exit(1, 'error: no text provided (-t).\n')
    if not args.gateway:
        parser.exit(1, 'error: no gateway specified (-g).\n')

    if args.recipients:
        conf['send']['recipients'] = args.recipients.split(',')

    if args.gateway == 'modem':
        send_mode('modem', modem)
    else:
        send_mode('web')
else:
    receive_mode(modem)
