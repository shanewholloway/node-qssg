# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

exports.pluginTypes = pluginTypes = {}

class ComposedCommonPlugin
  kinds: ''
  registerPluginOn: (pluginMap)->
    pluginMap.addPluginAt '&'+@kind

  init: (opt)-> @initOptions(opt) if opt?
  initOptions: (opt)->
    if opt?
      for own k,v of opt
        @[k] = v
    return @

  inspect: -> "«#{@constructor.name}»"
  toString: -> @inspect()

  asPluginPipeline: (pi_list)->
    new pluginTypes.pipeline(pi_list)

  composePlugin: (pi_list, entry)->
    @extendPlugins?(pi_list)
    if pi_list.length>1
      pi = @asPluginPipeline(pi_list)
    else pi = pi_list[0]
    pi = pi.adapt(entry)

    self = Object.create @, pi:value:pi
    self.initComposed?(pi)
    return self

  rename: (entry)-> @pi.rename(entry)

  simple: (entry, callback)-> @notImplemented('simple', entry, callback)
  composite: (entry, callback)-> @notImplemented('composite', entry, callback)
  context: (entry, callback)-> @notImplemented('context', entry, callback)
  simpleDir: (entry, callback)-> @notImplemented('simpleDir', entry, callback)
  compositeDir: (entry, callback)-> @notImplemented('compositeDir', entry, callback)
  contextDir: (entry, callback)-> @notImplemented('contextDir', entry, callback)

  notImplemented: (protocolMethod, entry, callback)->
    err = "#{@}::#{protocolMethod}() not implemented for {entry: '#{entry.srcRelPath}'}"
    callback(new Error(err)); return

exports.ComposedCommonPlugin = ComposedCommonPlugin

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ComposedPlugin extends ComposedCommonPlugin
  isFileKindPlugin: true; isDirKindPlugin: true

  simple: (entry, callback)->
    @pi.bindRender(entry, callback)
  composite: (entry, callback)->
    @pi.bindRender(entry, callback)
  context: (entry, callback)->
    @pi.bindContext(entry, callback)

  simpleDir: (entry, callback)->
    if entry.ext.length
      return @compositeDir(entry, callback)
    @pi.contentDir(entry, callback)
  compositeDir: (entry, callback)->
    @pi.compositeDir(entry, callback)
  contextDir: (entry, callback)->
    @pi.contextDir(entry, callback)

exports.ComposedPlugin = ComposedPlugin
pluginTypes.composed = ComposedPlugin

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class TemplatePlugin extends ComposedCommonPlugin
  isFileKindPlugin: true; isDirKindPlugin: true

  prefix: 't_'
  composite: (entry, callback)->
    @pi.bindTemplate(entry, callback, false)
  context: (entry, callback)->
    @pi.bindTemplate(entry, callback, @prefix)

exports.TemplatePlugin = TemplatePlugin
pluginTypes.template = TemplatePlugin

