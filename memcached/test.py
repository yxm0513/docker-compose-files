#!/usr/bin/env python3
#coding:utf8
import memcache
mc = memcache.Client(['localhost:11211'], debug=True)
mc.set("name", "python")
ret = mc.get('name')
print (ret)
