#! /usr/bin/env python
# -*- coding: utf-8 -*-

import os, re, codecs, string

site_name = input("Indiquez le repertoire du site : ")
#site_name = raw_input("Indiquez le repertoire du site : ") # Python 2.6

# Paths
style_img_dir = "../../../{}/styles/i/".format(site_name)
content_img_dir = "../../../{}/images/".format(site_name)
#style_img_dir = "../../../%s/styles/i/" % (site_name,) # Python 2.6
#content_img_dir = "../../../%s/images/" % (site_name,) # Python 2.6

# File name
generated_file = "images_{}.html".format(site_name.lower())
#generated_file = "images_%s.html" % (site_name.lower(),) # Python 2.6

# Returns HTML output
def get_image_list(img_dir):
    
    html_output = ""
    regex = re.compile('.+(jpg|png|gif)$')
    
    cur_dir = os.getcwd()
    os.chdir(img_dir)
    
    for dirpath, dirnames, filenames in os.walk("."):
        for filename in filenames:
            if regex.match(filename):
                img_path = os.path.normpath(img_dir + dirpath + '/' + filename).replace('\\', "/")
                html_output += '\t\t\t<tr><td>' + img_path.lstrip('./') + '</td><td><img src="' + img_path + '"/></td></tr>' + "\r\n"
    
    os.chdir(cur_dir)
    
    return html_output

style_img_html = get_image_list(style_img_dir)
content_img_html = get_image_list(content_img_dir)

# Template
tpl = codecs.open('image_list.tpl', 'r', 'utf-8')
tpl_content = tpl.read()
tpl_content = tpl_content.replace('<SITE_NAME>', site_name)
tpl_content = tpl_content.replace('<STYLE_IMG_LIST>', style_img_html)
tpl_content = tpl_content.replace('<CONTENT_IMG_LIST>', content_img_html)

# HTML file
html_file = codecs.open(generated_file, 'w', 'utf-8')
html_file.write(tpl_content)
html_file.close()
