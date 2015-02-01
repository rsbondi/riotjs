
# if no "v" var given, default to package version
v ?= $(shell node -pe "require('./package.json').version")

# expand variable (so we can use it on branches w/o package.json, e.g. gh-pages)
VERSION := $(v)

.PHONY: test min

jshint:
	./node_modules/jshint/bin/jshint lib/*.js


riot:
	@ cat lib/compiler.js > compiler.js
	@ cat make/prefix.js | sed "s/VERSION/$(VERSION)/" > riot.js
	@ cat lib/observable.js lib/router.js lib/tmpl.js lib/tag/*.js >> riot.js
	@ cat riot.js compiler.js > riot+compiler.js
	@ cat make/suffix.js | tee -a riot.js riot+compiler.js > /dev/null

min: jshint riot
	@ for f in riot compiler riot+compiler; do ./node_modules/uglify-js/bin/uglifyjs $$f.js --comments --mangle -o $$f.min.js; done



#################################################
# Making new releases:
#
#   make release v=2.0.0
#   make publish
#
# ...which is a shorter version of:
#
#   make bump v=2.0.0
#   make version
#   make pages
#   make publish
#
# Bad luck? Revert with -undo, e.g.:
#
#   make bump-undo
#

MINOR_VERSION = `echo $(VERSION) | sed 's/\.[^.]*$$//'`


bump:
	# grab all latest changes to master
	# (if there's any uncommited changes, it will stop here)
	@ git checkout master
	@ git pull --rebase origin master
	# bump version in *.json files
	@ sed -i '' 's/\("version": "\)[^"]*/\1'$(VERSION)'/' *.json
	# bump to minor version in demo
	@ sed -i '' 's/[^/]*\(\/riot\.min\)/'$(MINOR_VERSION)'\1/' demo/index.html
	# generate riot.js & riot.min.js
	@ make min
	@ git status --short

bump-undo:
	# remove all uncommited changes
	@ git checkout master
	@ git reset --hard


version:
	@ git checkout master
	# create version commit
	@ git status --short
	@ git add --all
	@ git commit -am "$(VERSION)"
	@ git log --oneline -2
	# create version tag
	@ git tag -a 'v'$(VERSION) -m $(VERSION)
	@ git describe

version-undo:
	@ git checkout master
	# remove the version tag
	@ git tag -d 'v'$(VERSION)
	@ git describe
	# remove the version commit
	@ git reset `git rev-parse :/$(VERSION)`
	@ git reset HEAD^
	@ git log --oneline -2


pages:
	# get the latest gh-pages branch
	@ git fetch origin
	@ git checkout gh-pages
	@ git reset --hard origin/gh-pages
	# commit the demo files from master to gh-pages
	@ git checkout master .gitignore demo
	@ git status --short
	@ git add --all
	-@ git commit -am "$(VERSION)"
	@ git log --oneline -2
	# return back to master branch
	@ git checkout master

pages-undo:
	# reset all local changes
	@ git checkout gh-pages
	@ git reset --hard origin/gh-pages
	@ git status --short
	@ git log --oneline -2
	@ git checkout master


release: bump version pages

release-undo:
	make pages-undo
	make version-undo
	make bump-undo


publish:
	# push new version to npm and github
	# (github tag will also trigger an update in bower, component, cdnjs, etc)
	@ npm publish
	@ git push origin gh-pages
	@ git push origin master
	@ git push origin master --tags



#################################################
# Testing the packages locally
# (do this before publishing)
#
# Create a dir in sibling directory next to riot
#
# 	mkdir test && cd $_
#
# Bower
#
#   rm -rf bower_components && bower cache clean && bower install ../riotjs#master --offline
#   ls -al bower_components/riot
#
# NPM
#
#   rm -rf node_modules && npm install ../riotjs
#   ls -al node_modules/riot
#   node -e "console.log(require('riot').compile('<tag>\n<p>{2+2}</p>\n</tag>'))"
#   echo "require('riot')" > test.js
#   browserify test.js | subl
#

