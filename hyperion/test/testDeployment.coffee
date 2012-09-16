###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###

async = require 'async'
pathUtils = require 'path'
fs = require 'fs-extra'
FSItem = require '../src/model/FSItem'
utils = require '../src/utils'
util = require 'util'
server = require '../src/web/proxy'
Browser = require 'zombie'
git = require 'gift'
assert = require('chai').assert
service = require('../src/service/AuthoringService').get()
notifier = require('../src/service/Notifier').get()

port = utils.confKey 'server.staticPort'
rootUrl = "http://localhost:#{port}"
root = utils.confKey 'game.dev'
repository = pathUtils.resolve pathUtils.dirname root
repo = null

describe 'Deployement tests', -> 

  before (done) ->
    # given a clean game source
    fs.remove repository, (err) ->
      return done err if err?
      fs.mkdir root, done

  version = '1.0.0'

  describe 'given a brand new game folder', ->

    beforeEach (done) ->
      # given a clean game source
      fs.remove root, ->
        fs.mkdir root, (err) ->
          return done err if err?
          # given a valid game client in it
          fs.copy './hyperion/test/fixtures/working-client', root, done

    it 'should coffee compilation errors be reported', (done) ->
      # given a non-compiling coffee script
      fs.copy './hyperion/test/fixtures/Router.coffee.error', pathUtils.join(root, 'js', 'Router.coffee'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, (err) ->
          # then an error is reported
          assert.isNotNull err
          assert.include err, "Parse error on line 50: Unexpected 'STRING'", "Unexpected error: #{err}"
          done()
    
    it 'should stylus compilation errors be reported', (done) ->
      # given a non-compiling stylus sheet
      fs.copy './hyperion/test/fixtures/rheia.styl.error', pathUtils.join(root, 'style', 'rheia.styl'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, (err) ->
          # then an error is reported
          assert.isNotNull err
          assert.include err, "@import 'unexisting'", "Unexpected error: #{err}"
          done()

    it 'should no main html file be detected', (done) ->
      # given no main file
      fs.remove pathUtils.join(root, 'index.html'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, (err) ->
          # then an error is reported
          assert.isNotNull err
          assert.include err, 'no html page including requirej found', "Unexpected error: #{err}"
          done()

    it 'should main html file without requirejs be detected', (done) ->
      # given a main file without requirejs
      fs.copy './hyperion/test/fixtures/index.html.norequire', pathUtils.join(root, 'index.html'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, (err) ->
          # then an error is reported
          assert.isNotNull err
          assert.include err, 'no html page including requirej found', "Unexpected error: #{err}"
          done()

    it 'should no requirejs configuration be detected', (done) ->
      # given a requirejs entry file without configuration
      fs.copy './hyperion/test/fixtures/Router.js.noconfigjs', pathUtils.join(root, 'js', 'Router.coffee'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, (err) ->
          # then an error is reported
          assert.isNotNull err
          assert.include err, 'no requirejs configuration file found', "Unexpected error: #{err}"
          done()

    it 'should requirejs optimization error be detected', (done) ->

      # given a requirejs entry file without error
      fs.copy './hyperion/test/fixtures/Router.coffee.requirejserror', pathUtils.join(root, 'js', 'Router.coffee'), (err) ->
        return done err if err?

        # when optimizing the game client
        service.deploy version, (err) ->
          # then an error is reported
          assert.isNotNull err
          assert.include err, 'optimized.out\\js\\backbone.js', "Unexpected error: #{err}"
          done()

  describe 'given a started static server', ->

    before (done) ->
      # given a valid game client in it
      fs.copy './hyperion/test/fixtures/working-client', root, (err) ->
        return done err if err?
        # given a initiazed git repository
        git.init repository, (err) ->
          return done err if err?
          repo = git repository
          repo.add [], all:true, (err) ->
            return done err if err?
            repo.commit 'initial', all:true, (err, stdout, stderr) ->
              return done err if err?
              server.listen port, 'localhost', done

    afterEach (done) ->
      notifier.removeAllListeners notifier.NOTIFICATION
      done()
      
    after (done) ->
      server.close()
      done()

    it 'should no version be registerd', (done) ->
      service.listVersion (err, versions) ->
        return done err if err?
        assert.equal 0, versions.length
        done()

    it 'should file be correctly compiled and deployed', (done) ->
      @timeout 20000
      notifications = []

      # then notifications are received in the right order
      notifier.on notifier.NOTIFICATION, (event, type, number) ->
        return unless event is 'deployement'
        notifications.push type
        assert.equal number, notifications.length, 'unexpected notification number' 

      # when deploying the game client
      service.deploy version, (err) ->
        return done "Failed to deploy valid client: #{err}" if err?
        # then notifications were properly received
        assert.deepEqual notifications, [
          'DEPLOY_START'
          'COMPILE_STYLUS'
          'COMPILE_COFFEE'
          'OPTIMIZE_JS'
          'OPTIMIZE_HTML'
          'DEPLOY'
          'DEPLOY_END'
        ]
        # then the client was deployed
        browser = new Browser silent: true
        browser.visit("#{rootUrl}/game").then( ->
          # then the resultant url is working, with template rendering and i18n usage
          body = browser.body.textContent.trim()
          assert.match body, new RegExp "#{version}\\s*Edition du monde"
          done()
        ).fail done

    it 'should deploy, save, remove, move and restoreVersion be disabled while deploying', (done) ->
      async.forEach [
        {method: 'deploy', args: ['2.0.0']}
        {method: 'save', args: ['index.html', 'admin']}
        {method: 'remove', args: ['index.html', 'admin']}
        {method: 'move', args: ['index.html', 'index.html2', 'admin']}
        {method: 'restoreVersion', args: [version]}
      ], (spec, next) ->
        # when invoking the medhod
        spec.args.push (err) ->
          assert.isDefined err
          assert.include err, ' in progress', "unexpected error #{err}"
          assert.include err, version, "unexpected error #{err}"
          next()
        service[spec.method].apply service, spec.args
      , done

    it 'should commit be successful', (done) ->
      # when commiting the deployement
      service.commit (err) ->
        return done "Failed to commit deployement: #{err}" if err?

        # then a git version was created
        repo.tags (err, tags) ->
          return done "Failed to consult tags: #{err}" if err?
          assert.equal 1, tags.length
          assert.equal tags[0].name, version

          # then no more save folder exists
          save = pathUtils.resolve pathUtils.normalize utils.confKey 'game.save'
          fs.exists save, (exists) ->
            assert.isFalse exists, "#{save} still exists"
            done()

    it 'should commit and rollback not invokable outside deploy', (done) ->
      async.forEach ['Commit', 'Rollback'], (method, next) ->
        # when invoking the medhod
        service[method.toLowerCase()] (err) ->
          # then error is throwned
          assert.isDefined err
          assert.equal err, "#{method} can only be performed after deploy", "unexpected error #{err}"
          next()
      , done

    it 'should version not be reused', (done) ->
      service.deploy version, (err) ->
        assert.isDefined err
        assert.equal err, "Version #{version} already used", "unexpected error #{err}"
        done()

    it 'should version be registerd', (done) ->
      service.listVersion (err, versions) ->
        return done err if err?
        assert.equal 1, versions.length
        assert.deepEqual [version], versions
        done()

    version2 = '2.0.0'

    it 'should another deployement be possible', (done) ->
      @timeout 20000

      # given a modification on a file
      fs.copy './hyperion/test/fixtures/common.coffee.v2', pathUtils.join(root, 'nls', 'common.coffee'), (err) ->
        return done err if err?
        repo.commit 'change to v2', all:true, (err, stdout, stderr) ->
          return done err if err?

          # when deploying the game client
          service.deploy version2, (err) ->
            return done "Failed to deploy valid client: #{err}" if err?
            # then the client was deployed
            browser = new Browser silent: true
            browser.visit("#{rootUrl}/game").then( ->
              # then the resultant url is working, with template rendering and i18n usage
              body = browser.body.textContent.trim()
              assert.match body, new RegExp "#{version2}\\s*Edition du monde 2"
              # then the deployement can be commited
              service.commit done
            ).fail done

    it 'should new version be also registered', (done) ->
      service.listVersion (err, versions) ->
        return done err if err?
        assert.equal 2, versions.length
        assert.deepEqual [version, version2], versions
        done()

    it 'should previous version be restored', (done) ->
      # given a modification not versionned with tags
      fs.copy './hyperion/test/fixtures/common.coffee.v3', pathUtils.join(root, 'nls', 'common.coffee'), (err) ->
        return done err if err?
        repo.commit 'change to v3', all:true, (err, stdout, stderr) ->
          return done err if err?

          # when restoring version 1
          service.restoreVersion version, (err) ->
            return done err if err?
            # then file common.coffee was restored
            fs.readFile './hyperion/test/fixtures/working-client/nls/common.coffee', 'utf-8', (err, originalContent) ->
              fs.readFile pathUtils.join(root, 'nls', 'common.coffee'), 'utf-8', (err, content) ->
                assert.equal content, originalContent, 'Version was not restored'
                done()

    it 'should last version be restored', (done) ->
      # when restoring version 2
      service.restoreVersion version2, (err) ->
        return done err if err?
        # then file common.coffee was restored
        fs.readFile './hyperion/test/fixtures/common.coffee.v2', 'utf-8', (err, originalContent) ->
          fs.readFile pathUtils.join(root, 'nls', 'common.coffee'), 'utf-8', (err, content) ->
            assert.equal content, originalContent, 'Version was not restored'
            done()

    it 'should unversionned be restored', (done) ->
      # when restoring current working file
      service.restoreVersion null, (err) ->
        return done err if err?
        # then file common.coffee was restored
        fs.readFile './hyperion/test/fixtures/common.coffee.v3', 'utf-8', (err, originalContent) ->
          fs.readFile pathUtils.join(root, 'nls', 'common.coffee'), 'utf-8', (err, content) ->
            assert.equal content, originalContent, 'Version was not restored'
            done()
    
    version3 = '3.0.0'

    it 'should deployement be rollbacked', (done) ->
      @timeout 20000

      # given a modification on game files
      labels = pathUtils.join root, 'nls', 'common.coffee'
      fs.readFile labels, 'utf8', (err, content) ->
        return done err if err?
        content = content.replace 'Edition du monde 3', 'yeah !'
        fs.writeFile labels, content, (err) ->
          return done err if err?
          # given a commit
          repo.commit 'change to v3', all:true, (err, stdout, stderr) ->
            return done err if err?

            # given a deployed game client
            service.deploy version3, (err) ->
              return done err if err?
              
              # when rollbacking
              service.rollback (err) ->
                return done "Failed to rollback: #{err}" if err?

                # then no version was made
                repo.tags (err, tags) ->
                  return done err if err?
                  return assert.fail "Version #{version2} has been tagged" for tag in tags when tag.name is version3

                  # then file still modified
                  fs.readFile labels, 'utf8', (err, newContent) ->
                    return done err if err?
                    assert.equal newContent, content, "File was modified"

                    # then the save folder do nt exists anymore 
                    save = pathUtils.resolve pathUtils.normalize utils.confKey 'game.save'
                    fs.exists save, (exists) ->
                      assert.isFalse exists, "#{save} still exists"

                      # then the previous client was deployed
                      browser = new Browser silent: true
                      browser.visit("#{rootUrl}/game").then( ->
                        # then the resultant url is working, with template rendering and i18n usage
                        body = browser.body.textContent.trim()
                        assert.match body, new RegExp "#{version2}\\s*Edition du monde 2"
                        done()
                      ).fail done
