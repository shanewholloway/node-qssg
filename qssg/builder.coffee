# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

path = require('path')
qutil = require('./util')
{inspect} = require('util')

class SiteBuilder
  fsTaskQueue: qutil.taskQueue(35)
  constructor: (rootPath, @contentTree)->
    @rootPath = path.resolve(rootPath)
    @cwd = path.resolve('.')

  build: (vars, doneBuildFn)->
    if typeof vars is 'function'
      doneBuildFn = vars; vars = null

    rootPath = @rootPath
    rootOutput = Object.create null,
      rootPath: value: @rootPath, enumerable: true
    vars = Object.create vars||null,
      output: value: rootOutput

    trackerMap = {}

    fnList = []
    dirTasks = qutil.createTaskTracker => @fsTaskQueue.extend fnList; fnList = null
    tidUpdate = setInterval @logTasksUpdate.bind(@, tasks, trackerMap), @msTasksUpdate||2000
    tasks = qutil.createTaskTracker -> clearInterval(tidUpdate); doneBuildFn()

    logStarted = @logStarted.bind(@)
    @contentTree.visit (vkind, contentItem, keyPath)=>
      return true if not contentItem.renderFn?

      relPath = keyPath.join('/')
      fullPath = path.resolve(@rootPath, relPath)
      if vkind is 'tree'
        @fs.makeDirs fullPath, dirTasks()

      output = Object.create rootOutput,
        vkind: value: vkind
        relPath: value: relPath, enumerable: true
        fullPath: value: fullPath
        contentItem: value: contentItem

      objVars = Object.create vars,
        output: value: output, enumerable: true

      renderAnswer = tasks =>
        delete trackerMap[relPath]
        @renderAnswerEx(output, arguments...)
      trackerMap[relPath] = renderAnswer

      fnList.push (taskDone)=>
        @fs.stat output.fullPath, taskDone.wrap (err, stat)->
          output.mtime = stat.mtime if stat?
          logStarted(output)
          contentItem.renderFn(objVars, renderAnswer)

      return true

  fs: qutil.fs
  renderAnswerEx: (rx, err, what)->
    if err? and not @logError(err, rx)
      return

    if what?
      mtime = rx.contentItem?.entry?.mtime
      if mtime? and rx.mtime and mtime<=rx.mtime
        @logUnchanged(rx)
      else
        @fsTaskQueue.do =>
          if what.pipe?
            what.pipe(@fs.createWriteStream(rx.fullPath))
          else
            @fs.writeFile(rx.fullPath, what)
          @logChanged(rx)
    return

  logStarted: (rx)->
    #console.error "start['#{path.relative(@cwd, rx.fullPath)}']"
    return
  logTasksUpdate: (tasks, trackerMap)->
    console.warn "tasks active: #{tasks.active} waiting on: #{inspect(Object.keys(trackerMap))}"
  logError: (err, rx)->
    console.error "ERROR['#{path.relative(@cwd, rx.fullPath)}'] :: #{err}"
    return
  logChanged: (rx)->
    console.error "WRITE['#{path.relative(@cwd, rx.fullPath)}']"
    return
  logUnchanged: (rx)->
    #console.error "unchanged ['#{path.relative(@cwd, rx.fullPath)}']"
    return

exports.SiteBuilder = SiteBuilder

