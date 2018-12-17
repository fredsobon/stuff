#!/usr/bin/env python

from sys import argv, exit
from re  import search
import websocket

#func
def usage():
    print("This check only test a websocket connection and the content of the server's answer. No arg needed")

def handshaking():
    handshake = ws.getstatus()
    print("ok the handshake value is", handshake)
    if handshake != status:
        print("websocket handshake failed..please check backend server !")
        webconn = "ko"
        exit(1)
    else:
        webconn = "ok"    
    return webconn

def main():
    webconn = handshaking()
    try:
        #first step - create websocket connection
        print("send ping to websocket server...")
        ws.send(message)
        print(ws.send)
        result =  ws.recv()
        if "i" in result:
            print("Received '%s'" % result )
        else: 
            print("connexion to websocket failed")
            exit(2)
        
        #second step - send message through the websocket tunnel     
        print("send ping to websocket server...")
        ws.send(message)
        print(ws.send)
        
        #last step - check the receiving message from backend server . 
        result =  ws.recv()
        if search(pattern , result):
            print("Received '%s'" % result )
        else:
            print("content match error in received message")
            exit(3)    
    finally:        
        ws.close()
        exit(0)
#vars 
url = "ws://echo.websocket.org"
message = "ping"
pattern = r'ping'
status = 101
ws = websocket.create_connection(url)
webconn = ""

#Ensure any arg is provided when script is launched
if (len(argv)) > 1:
    usage()
    exit(1)

if __name__ == "__main__":
    main()
