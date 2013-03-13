# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

fs = require 'fs'
path = require 'path'
funcQueues = require './funcQueues'

do -> exports[k]=v for k,v of funcQueues

fs = Object.create(fs)
fs.makeDirs = (aPath, mode, callback=->)->
  if typeof mode is 'function'
    callback = mode; mode = undefined
  step = (aPath, next)->
    fs.exists aPath, (exists)->
      if exists
        return next(null, false)
      step path.dirname(aPath), ->
        fs.mkdir aPath, mode, (err)->
          next(err, true)

  return step(path.resolve(aPath), callback)

exports.fs = fs


createTaskTracker = ->
  self = funcQueues.closureQueue(arguments...)
  self.done = funcQueues.functionList()
  self.add = (args...)->
    task = self()
    if typeof args[args.length-1] is 'function'
      task = task.wrap(args.pop())
    task.args = args if args.length?
    return task

  self.defer = (ms, callback)->
    if typeof ms is 'function'
      callback = ms; ms = null

    task = self(callback)
    if ms?
      setTimeout task, ms
    else process.nextTick task
    return task

  return self
exports.createTaskTracker = createTaskTracker

