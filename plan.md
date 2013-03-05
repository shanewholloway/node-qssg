# QSSG: Development Plan

## Code
- Dependency sorting for contentTree.
	- Implement as a visitor?
	- Ask plugins for dependencies 

- How to handle mtime for composites and templates?

## Examples
Many concepts would best be explained with a few good examples.

Showcase:
 - build sitemap from visitor
 - create blog with generated RSS feed
 - composite to concat and minify JS & CSS


## Documentation

- design & philosophy
- usage overview
- build process

- API
  - site
  - plugins
  - tree, context tree, composite tree
  - content & visitor


## Test Suite
Create using Mocha? Should `fs` be mocked for test?
