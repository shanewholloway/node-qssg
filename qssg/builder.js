// Generated by CoffeeScript 1.6.3
var SiteBuilder, events, inspect, path, qutil, url,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

events = require('events');

path = require('path');

url = require('url');

qutil = require('./util');

inspect = require('util').inspect;

SiteBuilder = (function(_super) {
  __extends(SiteBuilder, _super);

  SiteBuilder.prototype.fsTaskQueue = qutil.taskQueue(35);

  function SiteBuilder(rootPath, contentTree) {
    this.contentTree = contentTree;
    this.rootPath = path.resolve(rootPath);
    this.cwd = path.resolve('.');
  }

  SiteBuilder.prototype.build = function(vars, doneBuildFn) {
    var dirTasks, fsTasks, logTasksUpdate, tasks, tidUpdate, trackerMap,
      _this = this;
    if (typeof vars === 'function') {
      doneBuildFn = vars;
      vars = null;
    }
    trackerMap = {};
    fsTasks = qutil.invokeList.ordered();
    dirTasks = qutil.createTaskTracker(function() {
      _this.fsTaskQueue.extend(fsTasks.sort());
      return fsTasks = null;
    });
    tasks = qutil.createTaskTracker(function() {
      logTasksUpdate();
      clearInterval(tidUpdate);
      doneBuildFn();
      return _this.emit('done');
    });
    logTasksUpdate = this.logTasksUpdate.bind(this, tasks, trackerMap);
    tidUpdate = setInterval(logTasksUpdate, this.msTasksUpdate || 2000);
    this.emit('begin');
    return this.contentTree.visit(function(vkind, citem, keyPath) {
      var fullPath, relPath, rx, rx_vars, statDone;
      relPath = keyPath.join('/');
      fullPath = path.resolve(_this.rootPath, relPath);
      if (vkind === 'tree') {
        _this.fs.makeDirs(fullPath, dirTasks());
      }
      if (citem.render == null) {
        return;
      }
      rx = Object.create(null, {
        relPath: {
          value: relPath,
          enumerable: true
        },
        fullPath: {
          value: fullPath
        },
        rootPath: {
          value: _this.rootPath
        },
        content: {
          value: citem
        }
      });
      rx_vars = Object.create(vars, {
        output: {
          value: rx,
          enumerable: true
        },
        item: {
          value: citem,
          enumerable: true
        }
      });
      if (typeof vars.adaptVars === "function") {
        vars.adaptVars(rx_vars);
      }
      statDone = tasks();
      fsTasks.push(function(taskDone) {
        return _this.fs.stat(rx.fullPath, taskDone.wrap(function(err, stat) {
          var renderAnswer, renderDone;
          if (stat != null) {
            rx.mtime = stat.mtime;
            if ((citem.mtime != null) && citem.mtime < stat.mtime) {
              statDone();
              return _this.logUnchanged(rx);
            }
          }
          _this.logStart(rx);
          renderDone = tasks(function() {
            return delete trackerMap["" + relPath + "#end"];
          });
          trackerMap["" + relPath + "#end"] = renderAnswer;
          renderAnswer = tasks(function() {
            delete trackerMap["" + relPath];
            return _this.renderAnswerEx.apply(_this, [renderDone, rx].concat(__slice.call(arguments)));
          });
          trackerMap["" + relPath] = renderAnswer;
          citem.render(rx_vars, renderAnswer);
          return statDone();
        }));
      });
      tasks.seed();
      return true;
    });
  };

  SiteBuilder.prototype.fs = qutil.fs;

  SiteBuilder.prototype.renderAnswerEx = function(done, rx, err, what) {
    var mtime, _ref,
      _this = this;
    if (err != null) {
      done();
      return this.logProblem(err, rx);
    }
    if (what == null) {
      done();
      return this.logEmpty(rx);
    }
    mtime = (_ref = rx.content) != null ? _ref.mtime : void 0;
    if ((mtime != null) && rx.mtime && mtime <= rx.mtime) {
      done();
      return this.logUnchanged(rx);
    }
    this.fsTaskQueue["do"](function() {
      if (what.pipe != null) {
        what.pipe(_this.fs.createWriteStream(rx.fullPath)).on('close', done);
      } else {
        _this.fs.writeFile(rx.fullPath, what, done);
      }
      return _this.logChanged(rx);
    });
  };

  SiteBuilder.prototype.logPathsFor = function(rx) {
    var _ref;
    return {
      src: path.relative(this.cwd, ((_ref = rx.content) != null ? _ref.meta.srcPath : void 0) || '??/' + rx.relPath),
      rx: rx,
      dst: path.relative(this.cwd, rx.fullPath)
    };
  };

  SiteBuilder.prototype.logStart = function(rx) {
    var rxp;
    this.emit('start', rxp = this.logPathsFor(rx));
  };

  SiteBuilder.prototype.logProblem = function(err, rx) {
    var rxp;
    if (!this.emit('problem', err, rxp = this.logPathsFor(rx))) {
      console.error("ERROR['" + rxp.src + "'] :: " + err);
      if (rx.plugins != null) {
        console.error("  plugins: " + rx.plugins);
      }
      if (err.stack) {
        console.error(err.stack);
      }
    }
  };

  SiteBuilder.prototype.logChanged = function(rx) {
    var rxp;
    if (!this.emit('changed', rxp = this.logPathsFor(rx))) {
      console.log("write['" + rxp.src + "'] -- '" + rxp.dst + "'");
    }
  };

  SiteBuilder.prototype.logUnchanged = function(rx) {
    var rxp;
    this.emit('unchanged', rxp = this.logPathsFor(rx));
  };

  SiteBuilder.prototype.logEmpty = function(rx) {
    var rxp;
    this.emit('empty', rxp = this.logPathsFor(rx));
  };

  SiteBuilder.prototype.logTasksUpdate = function(tasks, trackerMap) {
    if (!this.emit('update', tasks, trackerMap)) {
      return console.warn("tasks active: " + tasks.active + " waiting on: " + (inspect(Object.keys(trackerMap))));
    }
  };

  return SiteBuilder;

})(events.EventEmitter);

exports.SiteBuilder = SiteBuilder;

exports.createBuilder = function(rootPath, content) {
  return new SiteBuilder(rootPath, content);
};

exports.setContentPaths = function(rootPath, rootUrl, content) {
  var base;
  base = {
    root: this.rootPath,
    url_root: this.rootUrl,
    url: function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return url.resolve.apply(url, [rootUrl, this.rel].concat(__slice.call(args)));
    },
    full: {
      get: function() {
        return path.resolve(rootPath, this.rel);
      }
    },
    relative: {
      enumerable: true,
      get: function() {
        return this.rel;
      }
    }
  };
  return content.visit(function(vkind, citem, keyPath) {
    var relPath;
    relPath = keyPath.join('/');
    citem.paths = Object.create(base, {
      rel: {
        value: relPath
      }
    });
    return true;
  });
};

/*
//@ sourceMappingURL=builder.map
*/
