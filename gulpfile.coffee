{task, async, sync, go, gutil} = require('ds-gulp-builder')(gulp = require('gulp'))

# Zork: It's local version of gulp builder - for gulp builder development
# {task, async, sync, go, gutil} = require('../../GIT/DSGulpBuilder')(require('gulp'))

[src, spec, docs, lib, generated] = ['./src', './spec', './docs', './lib', './generated']
tasks = []

# Clear ./build and ./generated folders
clearFolders = [
  task('clear-lib').clearFolder(lib).keep('.git')
]

# Run specs
#compileSpecs = task('compile-specs').coffee2js("#{spec}").dest("#{generated}/srv-specs")
#tasks.push runSpecs = task('run-specs', [compileSpecs]).jasmine("#{spec}", includeStackTrace: true).watch("#{src}/**/*")
tasks.push runSpecs = task('run-specs').jasmine(spec, includeStackTrace: true).watch("#{src}/**/*")

tasks.push 'docco'
gulp.task 'docco', ->

  gulp.watch "#{spec}/**/*.litcoffee", ['docco']

  gulp.src "#{spec}/**/*.litcoffee"
  .pipe (require 'gulp-docco')()
  .pipe gulp.dest docs

if gutil.env.dev then go tasks
else go sync [clearFolders, tasks]