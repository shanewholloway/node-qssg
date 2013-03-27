//@ sourceMappingURL=content.map
// Generated by CoffeeScript 1.6.1
var ContentBaseNode, ContentCollectionMixin, ContentComposite, ContentItem, ContentRoot, ContentTree, ContentTreeNode, CtxTree, Renderable, invokeList,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

invokeList = require('./util').invokeList;

Renderable = (function() {

  function Renderable() {}

  Renderable.prototype.bindRender = function(renderFn) {
    Object.defineProperties(this, {
      render: {
        value: renderFn
      }
    });
    return this;
  };

  Renderable.prototype.bindRenderComposed = function() {
    return this.bindRender(this.renderComposed);
  };

  Renderable.prototype.renderTasks = function() {
    var tasks;
    if ((tasks = this._renderTasks) == null) {
      tasks = invokeList.ordered();
      Object.defineProperties(this, {
        _renderTasks: {
          value: tasks
        }
      });
    }
    return tasks;
  };

  Renderable.prototype.addTemplate = function(tmplFn, order) {
    var tasks;
    if (typeof tmplFn !== 'function') {
      throw new Error("Content template must be a function");
    }
    tasks = this.renderTasks();
    if (tasks.tmpl == null) {
      tasks.tmpl = invokeList.ordered();
      tasks.add(1.0, this.renderTemplateFn.bind(this, tasks.tmpl));
    }
    tasks.tmpl.add(order, tmplFn);
    return this;
  };

  Renderable.prototype.renderTemplateFn = function(templates, source, vars, answerFn) {
    var tmplFn;
    tmplFn = templates.sort().slice(-1).pop();
    vars = Object.create(vars, {
      content: {
        value: source
      }
    });
    return tmplFn(vars, answerFn);
  };

  Renderable.prototype.renderComposed = function(vars, answerFn) {
    var stepFn;
    vars.ctx = this.ctx;
    try {
      stepFn = this._renderTasks.iter(function(renderFn, err, src) {
        if ((err == null) && renderFn !== void 0) {
          try {
            return renderFn(src, vars, stepFn);
          } catch (err) {
            return answerFn(err);
          }
        } else {
          return answerFn(err, src);
        }
      });
      return stepFn();
    } catch (err) {
      return answerFn(err);
    }
  };

  return Renderable;

})();

ContentBaseNode = (function(_super) {

  __extends(ContentBaseNode, _super);

  function ContentBaseNode() {
    return ContentBaseNode.__super__.constructor.apply(this, arguments);
  }

  ContentBaseNode.prototype.isContentNode = true;

  ContentBaseNode.prototype.init = function(parent) {
    Object.defineProperties(this, {
      parent: {
        value: parent
      }
    });
    this.meta = {};
    return this.ctx = this.initCtx(parent != null ? parent.ctx : void 0, parent);
  };

  ContentBaseNode.prototype.updateMetaFromEntry = function(entry) {
    this.meta.entry = entry;
    return this.meta.srcPath = entry.srcPath;
  };

  ContentBaseNode.prototype.initCtx = function(ctx_next) {
    return ctx_next || this.pushCtx();
  };

  ContentBaseNode.prototype.pushCtx = function(ctx_next) {
    var tmpl;
    if (ctx_next == null) {
      return {
        tmpl: {}
      };
    }
    tmpl = Object.create(ctx_next.tmpl || (ctx_next.tmpl = {}));
    return Object.create(ctx_next, {
      tmpl: {
        value: tmpl
      },
      ctx_next: {
        value: ctx_next
      }
    });
  };

  ContentBaseNode.prototype.visit = function(visitor, keyPath) {
    throw new Error("Subclass responsibility: " + this.constructor.name + "::visit()");
  };

  ContentBaseNode.prototype.compositeWith = function(key, contentItem, parent) {
    var comp;
    comp = new ContentComposite(parent, key);
    comp.addItem(this.name, this);
    comp.addItem(key, contentItem);
    return comp;
  };

  ContentBaseNode.prototype.touch = function(arg) {
    if (arg == null) {
      arg = true;
    }
    if (arg === 0) {
      delete this.mtime;
    } else if (arg === true) {
      this.mtime = new Date();
    } else {
      arg = Math.max(this.mtime || 0, arg || 0);
      this.mtime = new Date(arg);
    }
    return this.mtime;
  };

  return ContentBaseNode;

})(Renderable);

ContentItem = (function(_super) {

  __extends(ContentItem, _super);

  ContentItem.prototype.kind = 'item';

  function ContentItem(parent, name) {
    this.name = name;
    this.init(parent);
  }

  ContentItem.prototype.initCtx = function(ctx_next) {
    return ctx_next;
  };

  ContentItem.prototype.visit = function(visitor, keyPath) {
    if (keyPath == null) {
      keyPath = [];
    }
    return visitor(this.kind, this, keyPath.concat([this.name]));
  };

  return ContentItem;

})(ContentBaseNode);

ContentComposite = (function(_super) {

  __extends(ContentComposite, _super);

  ContentComposite.prototype.kind = 'composite';

  function ContentComposite(parent, name) {
    this.name = name;
    this.list = [];
    this.init(parent);
  }

  ContentComposite.prototype.addItem = function(key, item) {
    if (!item.isContentNode) {
      throw new Error("Can only add ContentItem objects");
    }
    this.list.push(item);
    return item;
  };

  ContentComposite.prototype.compositeWith = function(key, contentItem, parent) {
    this.list.push(contentItem);
    return this;
  };

  ContentComposite.prototype.visit = function(visitor, keyPath) {
    var res;
    if (keyPath == null) {
      keyPath = [];
    }
    res = visitor(this.kind, this, keyPath.slice());
    if (res === false) {

    } else {
      return this.visitList(visitor, keyPath);
    }
  };

  ContentComposite.prototype.visitList = function(visitor, keyPath) {
    var each, _i, _len, _ref;
    if (keyPath == null) {
      keyPath = [];
    }
    _ref = this.list;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      each = _ref[_i];
      each.visit(visitor, keyPath);
    }
    return true;
  };

  return ContentComposite;

})(ContentBaseNode);

ContentRoot = (function(_super) {

  __extends(ContentRoot, _super);

  ContentRoot.prototype.kind = 'root';

  function ContentRoot(key) {
    ContentRoot.__super__.constructor.call(this, null, key);
  }

  return ContentRoot;

})(ContentComposite);

ContentTreeNode = (function(_super) {

  __extends(ContentTreeNode, _super);

  ContentTreeNode.prototype.kind = 'tree';

  function ContentTreeNode(parent, name) {
    this.name = name;
    this.items = {};
    this.init(parent);
    if (!this.name) {
      throw new Error("Key must be valid " + this);
    }
  }

  ContentTreeNode.prototype.addItem = function(key, item) {
    var curItem;
    if (!item.isContentNode) {
      throw new Error("Can only add ContentNode objects");
    }
    if ((curItem = this.items[key]) != null) {
      item = curItem.compositeWith(key, item, this);
    }
    this.items[key] = item;
    return item;
  };

  ContentTreeNode.prototype.getItem = function(key) {
    return this.items[key];
  };

  ContentTreeNode.prototype.visit = function(visitor, keyPath) {
    var res;
    if (keyPath == null) {
      keyPath = [];
    }
    keyPath = keyPath.concat([this.name]);
    res = visitor(this.kind, this, keyPath.slice());
    if (res === false) {

    } else {
      return this.visitItems(visitor, keyPath);
    }
  };

  ContentTreeNode.prototype.visitItems = function(visitor, keyPath) {
    var each, key, _ref;
    if (keyPath == null) {
      keyPath = [];
    }
    _ref = this.items;
    for (key in _ref) {
      each = _ref[key];
      each.visit(visitor, keyPath);
    }
    return true;
  };

  return ContentTreeNode;

})(ContentBaseNode);

ContentTree = (function(_super) {

  __extends(ContentTree, _super);

  function ContentTree() {
    return ContentTree.__super__.constructor.apply(this, arguments);
  }

  ContentTree.prototype.isContentTree = true;

  ContentTree.prototype.initCtx = function(ctx_next, parent) {
    if (parent != null ? parent.isContentTree : void 0) {
      return this.pushCtx(ctx_next);
    }
    return ContentTree.__super__.initCtx.call(this, ctx_next, parent);
  };

  return ContentTree;

})(ContentTreeNode);

CtxTree = (function(_super) {

  __extends(CtxTree, _super);

  function CtxTree() {
    return CtxTree.__super__.constructor.apply(this, arguments);
  }

  CtxTree.prototype.kind = 'ctx_tree';

  CtxTree.prototype.isCtxTree = true;

  CtxTree.prototype.initCtx = function(ctx_parent) {
    var ctx;
    if (ctx_parent != null) {
      ctx = this.pushCtx(ctx_parent[this.name]);
      return ctx_parent[this.name] = ctx;
    } else {
      return this.pushCtx();
    }
  };

  CtxTree.prototype.adaptMatchKind = function(matchKind) {
    return 'context';
  };

  return CtxTree;

})(ContentTreeNode);

ContentCollectionMixin = (function() {

  function ContentCollectionMixin() {}

  ContentCollectionMixin.prototype.ContentItem = ContentItem;

  ContentCollectionMixin.prototype.ContentTree = ContentTree;

  ContentCollectionMixin.prototype.CtxTree = CtxTree;

  ContentCollectionMixin.prototype.newContentEx = function(parent, key) {
    return new this.ContentItem(parent, key);
  };

  ContentCollectionMixin.prototype.newContent = function(key) {
    return this.newContentEx(this, key);
  };

  ContentCollectionMixin.prototype.addContent = function(key) {
    return this.addItem(key, this.newContentEx(this, key));
  };

  ContentCollectionMixin.prototype.getContent = function(key) {
    var item;
    if ((item = typeof this.getItem === "function" ? this.getItem(key) : void 0) == null) {
      item = this.addContent(key);
    }
    return item;
  };

  ContentCollectionMixin.prototype.newTreeEx = function(parent, key) {
    return new this.ContentTree(parent, key);
  };

  ContentCollectionMixin.prototype.newTree = function(key) {
    return this.newTreeEx(this, key);
  };

  ContentCollectionMixin.prototype.addTree = function(key) {
    return this.addItem(key, this.newTreeEx(this, key));
  };

  ContentCollectionMixin.prototype.newCtxTreeEx = function(parent, key) {
    return new this.CtxTree(parent, key);
  };

  ContentCollectionMixin.prototype.newCtxTree = function(key) {
    return this.newCtxTreeEx(this, key);
  };

  ContentCollectionMixin.mixInto = function(tgtClass) {
    var k, tgt, v, _ref;
    tgt = tgtClass.prototype || tgtClass;
    _ref = this.prototype;
    for (k in _ref) {
      v = _ref[k];
      tgt[k] = v;
    }
  };

  return ContentCollectionMixin;

})();

ContentCollectionMixin.mixInto(ContentTree);

ContentCollectionMixin.mixInto(ContentComposite);

module.exports = {
  ContentBaseNode: ContentBaseNode,
  ContentCollectionMixin: ContentCollectionMixin,
  ContentItem: ContentItem,
  ContentTree: ContentTree,
  ContentRoot: ContentRoot,
  createRoot: function() {
    return new ContentRoot();
  }
};
