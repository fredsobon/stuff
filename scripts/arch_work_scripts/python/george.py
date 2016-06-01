#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys, string, time, botcommon
from botplugins import plugins
from threading import Thread, Timer
from ircbot import SingleServerIRCBot
from irclib import nm_to_n, nm_to_h, irc_lower


class UDPInput(Thread):
    def __init__(self, bot, addr):
        Thread.__init__(self)
        self.daemon = True
        self.bot = bot
        from socket import socket, AF_INET, SOCK_DGRAM
        self.socket = socket(AF_INET, SOCK_DGRAM)
        self.socket.bind(addr)

    def run(self):
        while 1:
            data, addr = self.socket.recvfrom(1024)
            self.bot.say(data)

class GeorgeBot(SingleServerIRCBot):
    def __init__(self, channel, nickname, server, port):
        SingleServerIRCBot.__init__(self, [(server, port)], nickname, nickname)
        self.channel = channel
        self.nickname = nickname
        self.queue = botcommon.OutputManager(self.connection)
        self.queue.start()
        self.inputthread = UDPInput(self, ('localhost', 4242))
        self.inputthread.start()
        self.start()

    def on_nicknameinuse(self, c, e):
        self.nickname = c.get_nickname() + '_'
        c.nick(self.nickname)

    def on_welcome(self, c, e):
        c.join(self.channel)
        self.say('oh hai!')

    def on_privmsg(self, c, e):
        from_nick = nm_to_n(e.source())
        self.do_command(e, e.arguments()[0], from_nick)

    def on_pubmsg(self, c, e):
        from_nick = nm_to_n(e.source())
        a = string.split(e.arguments()[0], ':', 1)
        if len(a) > 1 \
            and irc_lower(a[0]) == irc_lower(self.nickname):
            self.do_command(e, string.strip(a[1]), from_nick)
        return

    def say(self, text):
        """Print TEXT into public channel, for all to see."""
        self.queue.send(text, self.channel)

    def say_private(self, nick, text):
        """Send private message of TEXT to NICK."""
        self.queue.send(text,nick)

    def reply(self, text, to_private=None):
        """Send TEXT to either public channel or TO_PRIVATE nick (if defined)."""

        if to_private is not None:
            self.say_private(to_private, text)
        else:
            self.say(text)

    def do_command(self, e, cmd, from_private):
        """This is the function called whenever someone sends a public or
        private message addressed to the bot. (e.g. "bot: blah").    Parse
        the CMD, execute it, then reply either to public channel or via
        /msg, based on how the command was received.    E is the original
        event, and FROM_PRIVATE is the nick that sent the message."""

        #Display our available commands
        if cmd == "help":
            self.say("Alors mon petit José, voilà pour apprendre à me parler poliment:")
            self.say("- Available commands "+my_plugins.list_plugins())
        #If it is a command we know
        elif cmd in my_plugins.plugin_list:
            print('[DEBUG][command] "%s" from %s' % (cmd, from_private))
            my_plugins.plugin_list[cmd].run(self)
        #Else say a random quote
        else:
            print('[DEBUG][blablah] "%s" from %s' % (cmd, from_private))
            my_plugins.plugin_list['quote'].run(self)

if __name__ == '__main__':
    try:
        #Load our plugins under ~./plugins directory
        my_plugins = plugins()
        #Load bot
        botcommon.trivial_bot_main(GeorgeBot)
    except KeyboardInterrupt:
        print("Shutting down.")
