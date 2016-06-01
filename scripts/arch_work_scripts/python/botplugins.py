#!/usr/bin/env python
# -*- coding: utf-8 -*-

import imp, sys, os.path, glob

#Load everything under in python under ~./plugins
class plugins():
    #Load every python files under ./plugins
    def load_plugins(self,path):
        for infile in glob.glob( os.path.join(path, '*.plugin') ):
            print '\t[DEBUG] '+str(os.path.basename(infile))
            #Command name
            command= str( os.path.splitext( os.path.split(infile)[1] )[0] )
            #Load file
            mod_name,file_ext = os.path.splitext(os.path.split(infile)[-1])
            #Store in our dict
            self.plugin_list[command]= imp.load_source(mod_name,infile)
        return True
    
    def list_plugins(self):
        #return ", ".join(self.plugin_list.keys())
        return str(self.plugin_list.keys())

    def __init__(self):
        print'[DEBUG] Loading plugins'
        self. plugin_list = {}
        self.load_plugins('plugins/')
