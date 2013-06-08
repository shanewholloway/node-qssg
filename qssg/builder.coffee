# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

events = require('events')

path = require('path')
url = require('url')
qutil = require('./util')
{inspect} = require('util')

class SiteBuilder extends events.EventEmitter
  fsTaskQueue: qutil.taskQueue(35)
  constructor: (rootPath, @contentTree)->
    @rootPath = path.resolve(rootPath)
    @cwd = path.resolve('.')

  build: (vars, doneBuildFn)->
    if typeof vars is 'function'
      doneBuildFn = vars; vars = null

    trackerMap = {}
    fsTasks = qutil.invokeList.ordered()
    dirTasks = qutil.createTaskTracker =>
      @fsTaskQueue.extend fsTasks.sort(); fsTasks = null
    tasks = qutil.createTaskTracker =>
      logTasksUpdate()
      clearInterval(tidUpdate)
      doneBuildFn()
      @emit('done')
    logTasksUpdate = @logTasksUpdate.bind(@, tasks, trackerMap)
    tidUpdate = setInterval logTasksUpdate, @msTasksUpdate||2000

    @emit('begin')
    @contentTree.visit (vkind, citem, keyPath)=>
      relPath = keyPath.join('/')
      fullPath = path.resolve(@rootPath, relPath)
      if vkind is 'tree'
        @fs.makeDirs fullPath, dirTasks()

      if not citem.render?
        return

      rx = Object.create null,
        relPath: value: relPath, enumerable: true
        fullPath: value: fullPath
        rootPath: value: @rootPath
        content: value: citem

      rx_vars = Object.create vars,
        output: value: rx, enumerable: true
        item: value: citem, enumerable: true

      vars.adaptVars?(rx_vars)

      statDone = tasks()
      fsTasks.push (taskDone)=>
        @fs.stat rx.fullPath, taskDone.wrap (err, stat)=>
          if stat?
            rx.mtime = stat.mtime
            if citem.mtime? and citem.mtime < stat.mtime
              statDone()
              return @logUnchanged(rx)
          @logStart(rx)

          renderDone = tasks =>
            delete trackerMap["#{relPath}#end"]
          trackerMap["#{relPath}#end"] = renderAnswer
          renderAnswer = tasks =>
            delete trackerMap["#{relPath}"]
            @renderAnswerEx(renderDone, rx, arguments...)
          trackerMap["#{relPath}"] = renderAnswer
          citem.render(rx_vars, renderAnswer)
          statDone()

      tasks.seed() # add an empty task to start when no rendered items are added
      return true

  fs: qutil.fs
  renderAnswerEx: (done, rx, err, what)->
    if err?
      done()
      return @logProblem(err, rx)
    if not what?
      done()
      return @logEmpty(rx)

    mtime = rx.content?.mtime
    if mtime? and rx.mtime and mtime<=rx.mtime
      done()
      return @logUnchanged(rx)

    @fsTaskQueue.do =>
      if what.pipe?
        what.pipe(@fs.createWriteStream(rx.fullPath))
          .on('close', done)
      else
        @fs.writeFile rx.fullPath, what, done
      @logChanged(rx)
    return

  logPathsFor: (rx)->
    src:path.relative @cwd, rx.content?.meta.srcPath or '??/'+rx.relPath
    rx:rx, dst:path.relative @cwd, rx.fullPath
  logStart: (rx)->
    @emit('start', rxp=@logPathsFor(rx))
    #console.log "start['#{rxp.src}'] -- '#{rxp.dst}'"
    return
  logProblem: (err, rx)->
    if not @emit('problem', err, rxp=@logPathsFor(rx))
      console.error "ERROR['#{rxp.src}'] :: #{err}"
      if rx.plugins?
        console.error "  plugins: #{rx.plugins}"
      console.error err.stack if err.stack
    return
  logChanged: (rx)->
    if not @emit('changed', rxp=@logPathsFor(rx))
      console.log "write['#{rxp.src}'] -- '#{rxp.dst}'"
    return
  logUnchanged: (rx)->
    @emit('unchanged', rxp=@logPathsFor(rx))
    #console.log "unchanged['#{srcPath}'] -- '#{dstPath}'"
    return
  logEmpty: (rx)->
    @emit('empty', rxp=@logPathsFor(rx))
    #console.log "EMPTY['#{rxp.src}'] -- '#{rxp.dst}'"
    return
  #emit: ->

  logTasksUpdate: (tasks, trackerMap)->
    if not @emit('update', tasks, trackerMap)
      console.warn "tasks active: #{tasks.active} waiting on: #{inspect(Object.keys(trackerMap))}"

exports.SiteBuilder = SiteBuilder
exports.createBuilder = (rootPath, content)->
  new SiteBuilder(rootPath, content)

exports.setContentPaths = (rootPath, rootUrl, content)->
  base =
    root:@rootPath, url_root:@rootUrl,
    url: (args...)->
      url.resolve(rootUrl, @rel, args...)
    full: get: ->
      path.resolve(rootPath, @rel)
    relative: {enumerable: true, get: -> @rel}

  content.visit (vkind, citem, keyPath)->
    relPath = keyPath.join('/')
    citem.paths = Object.create base,
      rel: value: relPath
    return true

