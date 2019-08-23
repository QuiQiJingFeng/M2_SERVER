local skynet = require "skynet"
local cluster = require "skynet.cluster"
local log  =require "skynet.log"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
local proto = require "proto"

skynet.start(function()
	log.info("InterFace Server Start")
	sprotoloader.save(proto.c2s, 1)
	sprotoloader.save(proto.s2c, 2)
	skynet.uniqueservice("connect_manager")
	skynet.exit()
end)
