#!/usr/bin/env python

from sys import argv, exit
from re  import search
from websocket import create_connection

#func
def usage():
    print("This check only test a websocket connection and the content of the server's answer. No arg needed")

#vars 
url = "ws://echo.websocket.org"
message = "ping"
pattern= r'pong'

#Ensure any arg is provided when script is launched
if (len(argv)) > 1:
    usage()
    exit(1)

if __name__ == "__main__":
    try:
        #first step - create websocket connection
        ws = create_connection(url)
        result =  ws.recv()
        #if "o" in result:
        print("Received '%s'" % result )
        #else: 
        #print("connexion to websocket failed")
        #    exit(2)
        
        #second step - send message through the websocket tunnel     
        print("send ping to websocket server...")
        ws.send(message)
        
        #last step - check the receiving message from backend server . 
        result =  ws.recv()
        #if search(pattern , result):
        print("Received '%s'" % result )
        #else:
        #    print("content match error in received message")
        #    exit(3)    
    finally:        
        ws.close()
        exit(0)

