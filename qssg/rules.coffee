# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

path = require 'path'
events = require 'events'
{MatchEntry} = require './entry'

class Classifier extends events.EventEmitter
  constructor: ->
    super
    @rulesets = []
    @_coreRules = @addRuleset(0, 'core')

  matchRules: (entry, mx)=>
    if not (typeof mx.match is 'function')
      throw new Error("Classifier `mx` must implement `match()`")
    for rules in @rulesets
      for fn in rules
        if fn(Object.create(entry), mx)
          return true
    return false

  addRuleset: (w_or_ruleset, rulesetName)->
    if rulesetName?
      rs0 = @rulesets[rulesetName]
      rs0 ||= qrules.ruleset(@, w_or_ruleset)
      @rulesets[rulesetName] = rs0
    else rs0 = qrules.ruleset(@, w_or_ruleset)

    w0 = rs0.w||0 # find weight
    # use linear insert for small list
    for rs,idx in @rulesets
      if w0 < (rs.w||0)
        @rulesets.splice(idx,0,rs0)
        return rs0
    @rulesets.push rs0
    return rs0

  rule: (fnList...)-> @_coreRules.ruleEx(fnList)
  ruleEx: (fnList)-> @_coreRules.ruleEx(fnList)

qrules =
  Classifier: Classifier
  classifier: (sendFn)->
    new @.Classifier(sendFn)

  anyEx: (fnList)->
    return fnList if typeof fnList is 'function'
    return fnList[0] if fnList.length==1
    return (e, mx)->
      fnList.some (fn)-> fn(e, mx)
  any: (fnList...)-> qrules.anyEx(fnList)
  everyEx: (fnList)->
    return fnList if typeof fnList is 'function'
    return fnList[0] if fnList.length==1
    return (e, mx)->
      fnList.every (fn)-> fn(e, mx)
  every: (fnList...)-> qrules.everyEx(fnList)

  ruleset: (self, w) ->
    rs = []
    rs.w = w if w?
    rs.addRuleset = -> @
    rs.rule = (fnList...)->
      return rs.ruleEx(fnList)
    rs.ruleEx = (fnList)->
      fn = qrules.everyEx(fnList)
      rs.push fn if fn?
      return self
    return rs

  classify: (rx, fields, test)->
    rx = rx.source || rx
    rx = new RegExp("^#{rx}$", 'i')
    if fields.split?
      fields = fields.split ' '
    return (entry)->
      name0 = entry.name0 || entry.name.split('.')[0]
      mx = rx.exec(name0)
      if mx?
        entry.cx = cx = (entry.cx||{})
        fields.forEach (k,i)->
          if (f = mx[1+i])?
            entry[k] = cx[k] = f
        if not test? or test(arguments...)
          return true
      return false

  thenMatch: (args...)->
    qrules.thenMatchEx(args)
  thenMatchEx: (args)->
    return (entry, mx)-> mx.match(entry, args...); return true
  thenMatchKey: (kind)->
    return (entry, mx)-> mx.match(entry, kind); return true

  testDirOrExt: (entry)->
    entry.isDirectory() or entry.ext

  contextRuleset: (ruleset, opt={})->
    ruleset.rule(
      qrules.any(
        qrules.classify(/-(\w)-([^-].+)/, 'kind0 name0'),
        qrules.classify(/-([^-].+)-(\w)-?/, 'name0 kind0'),
        qrules.classify(/-([^-].+)/, 'name0', qrules.testDirOrExt)),
      qrules.thenMatchKey(opt.kind || 'context'))
    return ruleset

  compositeRuleset: (ruleset, opt={})->
    ruleset.rule(
      qrules.any(
        qrules.classify(/([^-].+)-(\w)-?/, 'name0 kind0'),
        qrules.classify(/([^-].+)-/, 'name0', qrules.testDirOrExt)),
      qrules.thenMatchKey(opt.kind || 'composite'))
    return ruleset

  simpleRuleset: (ruleset, opt={})->
    if opt.rulesetName is not false
      ruleset = ruleset.addRuleset(opt.w||1.0, opt.rulesetName||'simple')
    ruleset.rule(qrules.thenMatchKey(opt.kind || 'simple'))
    return ruleset

  standardRuleset: (host, opt={})->
    @contextRuleset(host, opt.context)
    @compositeRuleset(host, opt.composite)
    @simpleRuleset(host, opt.simple)
    return host

qrules.qrules = qrules
module.exports = qrules
