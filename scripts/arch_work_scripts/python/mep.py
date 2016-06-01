#!/usr/bin/env python
# -*- coding: utf-8 -*-

#
# mep.py: e-merchant outil de synchronisation du code
#         Michel Anthenor <m.anthenor@pixmania-group.com>
#
# $HeadURL: http://svn.e-merchant.net/svn/norel-puppet/modules/svn/files/repo/bin/mep.py $
#


import os
import tempfile
import sys
import smtplib
from email.mime.text import MIMEText
import argparse
#import xtermcolor
import yaml
import parser
import pysvn
import subprocess
import subprocess
import logging
from logging.handlers import RotatingFileHandler
import shutil
import getpass
import signal
import time
import posixpath


SVN_BASE = 'http://svn.e-merchant.net/svn'
SVN_LOCAL = '/srv/svn'
DNS_ZONE = 'e-merchant.local'
LOCKFILE = '/var/lock/mep.lock'
MEP_REP = '/var/log/emrelease_code'
MEP_CONF = '/etc/emrelease_code'
LOG_FILE_COMPOSER = 'composer.log'
composer_args = [
        '/usr/local/bin/composer',
        'install',
        '--no-dev',
        '--prefer-dist',
        '--no-progress',
        '--optimize-autoloader',
    ]


def do_purge():
    ''' on fait le menage en sortant '''
    if os.path.isfile(LOCKFILE):
        os.remove(LOCKFILE)
        if os.path.isdir(TMPDIR):
            shutil.rmtree(TMPDIR, ignore_errors=True)
        sys.exit()


def do_mail():
    sender = 'noreply@e-merchant.com'
    recipients = ['ml-mep@e-merchant.com']

    message_text = "MEP %s\n POOL %s\n TAG %s\n ADMIN %s" % (application, \
        str(components), str(tag), str(auth_user))
    message = MIMEText(message_text)

    message['Subject'] = "MEP %s" % application
    message['From'] = sender
    message['To'] = ",".join(recipients)

    try:
        smtpObj = smtplib.SMTP('localhost')
        smtpObj.sendmail(sender, recipients, message.as_string())
        print "Successful sent email"
        logger.info("Successful sent email")
    except smtplib.SMTPException:
        print "Error: unable to send e-mail"
        logger.warning("Error: unable to send e-mail")


def do_args_revpropset():
    ''' on set le tag en prod et staging
    donnees fournies en mode mep.py -u xxx -t yyy '''
    try:
        client.revpropset('em:lastsync-staging', args.tag, repo_user, \
            pysvn.Revision(pysvn.opt_revision_kind.number, 0))
        client.revpropset('em:lastsync-prod', args.tag, repo_user, \
            pysvn.Revision(pysvn.opt_revision_kind.number, 0))
    except:
        print('Attention: pre-revprop-change n\'existe pas dans le \
            répertoire hooks')
        logger.warning('Attention: pre-revprop-change n\'existe pas \
            dans le répertoire hooks')


def do_revpropset():
    ''' on set le tag en prod et staging
    donnees non fournies en mode mep.py -u xxx -t yyy '''
    try:
        client.revpropset('em:lastsync-staging', tag, repo_user, \
            pysvn.Revision(pysvn.opt_revision_kind.number, 0))
        client.revpropset('em:lastsync-prod', tag, repo_user, \
            pysvn.Revision(pysvn.opt_revision_kind.number, 0))
    except:
        print('Attention: pre-revprop-change n\'existe pas dans le \
            répertoire hooks')
        logger.warning('Attention: pre-revprop-change n\'existe pas \
            dans le répertoire hooks')


def do_revpropget():
    ''' recuperation tag en staging et en prod '''
    global prod_version
    prod_version = client.revpropget("em:lastsync-staging", \
        os.path.join(SVN_BASE, application), \
        revision=pysvn.Revision(pysvn.opt_revision_kind.number, 0))[1]
    global staging_version
    staging_version = client.revpropget("em:lastsync-prod", \
        os.path.join(SVN_BASE, application), \
        revision=pysvn.Revision(pysvn.opt_revision_kind.number, 0))[1]
    return prod_version, staging_version


def do_simulation():
    ''' simulation de deploiement code '''
    print("ok: %s" % i)
    logger.info("host: %s", i)
    if os.path.isdir(os.path.join(TMPDIR,'src')):
        deploy = ['rsync', '-arzvcOn', '--timeout=3', '--delete', \
            "--exclude-from=%s" % exclusion, '--delete-excluded', "%s/src/" % TMPDIR, "%s::%s" % (i, application)]
        subprocess.call(deploy)
        deploy_log = subprocess.Popen(['rsync', '-arzvcOn', '--timeout=3', '--delete', \
            "--exclude-from=%s" % exclusion, '--delete-excluded', "%s/src/" % TMPDIR, "%s::%s" % (i, application)], \
            stdout=subprocess.PIPE)
        out, err = deploy_log.communicate()
        for t in out.split("\n"):
            logger.info("%s ", t)
    else:
        deploy = ['rsync', '-arzvcOn', '--timeout=3', '--delete', "--exclude-from=%s" % exclusion, '--delete-excluded', \
            "%s/" % TMPDIR, "%s::%s" % (i, application)]
        subprocess.call(deploy)
        deploy_log = subprocess.Popen(['rsync', '-arzvcOn', '--timeout=3', '--delete', \
            "--exclude-from=%s" % exclusion, '--delete-excluded', "%s/" % TMPDIR, "%s::%s" % (i, application)], \
            stdout=subprocess.PIPE)
        out, err = deploy_log.communicate()
        for t in out.split("\n"):
            logger.info("%s ", t)


def do_deployment():
    ''' deploiement code '''
    print("ok: %s" % i)
    logger.info("host: %s", i)
    if os.path.isdir(os.path.join(TMPDIR,'src')):
        deploy = ['rsync', '-arzvcO', '--timeout=3', '--delete', \
		"--exclude-from=%s" % exclusion, '--delete-excluded', "%s/src/" % TMPDIR, "%s::%s" % (i, application)]
        subprocess.call(deploy)
        deploy_log = subprocess.Popen(["rsync", "-arzvcO", "--timeout=3", \
            "--delete", "--exclude-from=%s" % exclusion, '--delete-excluded', "%s/src/" % TMPDIR, \
            "%s::%s" % (i, application)], stdout=subprocess.PIPE)
        out, err = deploy_log.communicate()
        for t in out.split("\n"):
            logger.info("%s ", t)
    else:
        deploy = ['rsync', '-arzvcO', '--timeout=3', '--delete', \
		"--exclude-from=%s" % exclusion, '--delete-excluded', "%s/" % TMPDIR, "%s::%s" % (i, application)]
        subprocess.call(deploy)
        deploy_log = subprocess.Popen(['rsync', '-arzvcO', '--timeout=3', \
            '--delete', "--exclude-from=%s" % exclusion, '--delete-excluded', "%s/" % TMPDIR, \
            "%s::%s" % (i, application)], stdout=subprocess.PIPE)
        out, err = deploy_log.communicate()
        for t in out.split("\n"):
            logger.info("%s ", t)


def get_login(realm, username, may_save):
    global auth_user
    print 'Authentication realm: ' + realm
    auth_user = raw_input("Entrez votre login: ")
    auth_pass = getpass.getpass("Entrez votre password: ")
    print("\nWelcome: %s" % auth_user)
    logger.info("Welcome: %s", auth_user)
    return True, auth_user, auth_pass, False


def do_lock():
    global LOCKFILE
    with open(os.path.join("/var/lock/", "mep_" + application + ".lock"), 'w+') as lockfile:
        LOCKFILE = os.path.join("/var/lock/", "mep_" + application + ".lock")


def do_get_resource():
    ##### recuperation resource.yaml
    global RESOURCE
    resource = "resource.yaml"
    RESOURCE = yaml.load(open(os.path.join(MEP_CONF, resource)))


def do_log():
    global logger
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    formatter = logging.Formatter("%(asctime)s :: %(levelname)s :: \
        %(message)s")
    file_handler = RotatingFileHandler(os.path.join(MEP_REP, application, \
        'activity.log'), 'a', 50000000, 1)
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)


def set_releaseversion_php():
    if os.path.isdir(os.path.join(TMPDIR,'src')):
        with open(os.path.join(TMPDIR, 'src','release_version.inc.php'), 'w') as release_version_php:
            release_version_php.write("<?php\ndefine('RELEASE_VERSION', '" + tag + "');\n?>")
    else:
        with open(os.path.join(TMPDIR, 'release_version.inc.php'), 'w') as release_version_php:
             release_version_php.write("<?php\ndefine('RELEASE_VERSION', '" + tag + "');\n?>")


def do_composer():
    if os.path.isfile(os.path.join(TMPDIR, 'src','composer.json')):
        os.chdir(os.path.join(TMPDIR, 'src'))
        try:
            subprocess.check_call(composer_args)
        except subprocess.CalledProcessError:
            logger.error("Install composer failed: %s", open(os.path.join(MEP_REP, application, 'error.log'), 'w'))
            sys.exit()
    elif os.path.isfile(os.path.join(TMPDIR, 'composer.json')):
        os.chdir(TMPDIR)
        try:
            subprocess.call(composer_args)
        except subprocess.CalledProcessError:
            logger.error("Install composer failed: %s", open(os.path.join(MEP_REP, application, 'error.log'), 'w'))
            sys.exit()


signal.signal(signal.SIGINT, signal.SIG_IGN)


TMPDIR = tempfile.mkdtemp(prefix='mep_', suffix='tmp', dir='/tmp')
##### changement permissions pour le rsync sinon 700 home du user
os.chmod(TMPDIR, 0775)

# af0000
# http://vim.wikia.com/wiki/Xterm256_color_names_for_console_Vim
##### tests presence repertoires
if os.path.isfile(LOCKFILE):
    #print (xtermcolor.colorize('ATTENTION UN FICHIER DE LOCK
    #EXISTE DEJA', 0xaf0000))
    print ('ATTENTION UN FICHIER DE LOCK EXISTE DEJA')
    do_purge()
elif not os.path.isdir(MEP_CONF):
    #print (xtermcolor.colorize('ATTENTION LE REPERTOIRE MEP
    #N EXISTE PAS', 0xaf0000))
    print ('ATTENTION LE REPERTOIRE MEP N EXISTE PAS')
    do_purge()
elif not os.path.isdir(MEP_REP):
    #print (xtermcolor.colorize('ATTENTION LE REPERTOIRE LOG DES
    #MEP N EXISTE PAS', 0xaf0000))
    print ('ATTENTION LE REPERTOIRE LOG DES MEP N EXISTE PAS')
    do_purge()

##### recuperation utilisateur + tag
parser = argparse.ArgumentParser(usage="mep.py -a application -t tag")
parser.add_argument('-a', '--application', action='store')
parser.add_argument('-t', '--tag', action='store')
args = parser.parse_args()

if (args.application):
    application = args.application
    do_lock()
else:
    application = raw_input('Entrez projet: ')
    do_lock()

if not os.path.isdir(os.path.join(SVN_LOCAL, application)):
    #print (xtermcolor.colorize('ATTENTION LE REPOSITORY
    # DU PROJET N EXISTE PAS', 0xaf0000))
    print ('ATTENTION LE REPOSITORY DU PROJET N EXISTE PAS')
    do_purge()

LOG = os.path.join(MEP_REP, application, 'activity.log')

##### partie svn
client = pysvn.Client()
client.set_interactive(True)
client.callback_get_login = get_login

if not os.path.isdir(os.path.join(MEP_CONF, application)):
    #print (xtermcolor.colorize('ATTENTION LE REPERTOIRE CONF
    # DU PROJET N EXISTE PAS', 0xaf0000))
    print ('ATTENTION LE REPERTOIRE CONF DU PROJET N EXISTE PAS')
    os.makedirs(os.path.join(MEP_CONF, application))


if not os.path.isdir(os.path.join(MEP_REP, application)):
    #print (xtermcolor.colorize('ATTENTION LE REPERTOIRE LOG
    # DU PROJET N EXISTE PAS', 0xaf0000))
    print ('ATTENTION LE REPERTOIRE LOG DU PROJET N EXISTE PAS')
    os.makedirs(os.path.join(MEP_REP, application))

do_log()

logger.info("UTILISATEUR: %s ", application)

if not os.path.isfile(os.path.join(MEP_CONF, application, application + '.excl')):
    with open(os.path.join(MEP_CONF, application, application + '.excl'), 'w+') as exclusion:
        exclusion.write("%s\n%s\n%s\n%s\n%s" % ('.bash*', '.ssh', \
                '.subversion', '.svn', '.log'))
else:
    with open(os.path.join(MEP_CONF, application, application + '.excl'), 'w+') as exclusion:
            #exclusion = os.path.join(MEP_CONF, application, application + '.excl')
        exclusion.write("%s\n%s\n%s\n%s\n%s" % ('.bash*', '.ssh', \
            '.subversion', '.svn', '.log'))

exclusion = os.path.join(MEP_CONF, application, application + '.excl')

do_get_resource()

do_revpropget()
print("\nTAG STAGING: %s" % staging_version)
logger.info("TAG STAGING: %s", staging_version)
print("TAG PROD: %s" % prod_version)
logger.info("TAG PROD: %s", prod_version)

repo_user = os.path.join(SVN_BASE, application)

if not (args.tag):
    tag = raw_input('Entrez tag: ')
    logger.info("TAG CHOISI: %s ", tag)
else:
    tag = args.tag
    logger.info("TAG CHOISI: %s ", tag)

##### export du code
try:
     client.export(os.path.join(SVN_BASE, application, 'tags', tag), \
         TMPDIR, force=True, recurse=True, ignore_externals=False)
     if os.path.isdir(os.path.join(TMPDIR,'src')):
        open(os.path.join(TMPDIR, 'src','release.version'), 'w').write(tag + "\n")
        set_releaseversion_php()
     else:
        open(os.path.join(TMPDIR, 'release.version'), 'w').write(tag + "\n")
        set_releaseversion_php()
except:
    print("CE TAG N'EXISTE PAS")
    do_purge()

do_composer()

##### liste composants pool pour application
components = RESOURCE['user_list'][application]['components']

pool_members = []
print("\nPOOLS:")
for i in components:
    pool = i + '-prod' + '.' + DNS_ZONE
    #print(xtermcolor.colorize(pool, 0x00af00)) # vert
    print(pool) # vert
    logger.info(pool)
    sorti = subprocess.Popen(["dig", "+tcp", "+short", pool], \
        stdout=subprocess.PIPE)
    out, err = sorti.communicate()
    for i in out.split():
        logger.info("host: %s", i)
        pool_members.append(i)
deploy_release = raw_input("\nOn simule la MEP (o/N) ? ")
if deploy_release.lower() == "o":
    logger.info("MEP %s", application)
    print('SIMULATION POUR %s\n' % application)
    logger.info('SIMULATION POUR %s', application)
    time.sleep(1)
    for i in pool_members:
        do_simulation()
    deploy_release = raw_input("\nOn fait vraiment la MEP (o/N) ? ")
    if deploy_release.lower() == "o":
        print("DEPLOIEMENT CODE POUR %s\n" % application)
        logger.info("DEPLOIEMENT CODE POUR %s", application)
        time.sleep(1)
        for i in pool_members:
            do_deployment()
        do_mail()
        if (args.tag):
            do_args_revpropset()
        else:
            do_revpropset()
    do_purge()
do_purge()

