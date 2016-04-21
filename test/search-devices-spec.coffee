_             = require 'lodash'
mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
Cache         = require 'meshblu-core-cache'
redis         = require 'fakeredis'
uuid          = require 'uuid'
DeviceManager = require '..'

describe 'Search Devices', ->
  beforeEach (done) ->
    @datastore = new Datastore
      database: mongojs 'device-manager-test'
      collection: 'devices-test'

    @datastore.remove done

    @cache = new Cache client: redis.createClient uuid.v1()

  beforeEach ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new DeviceManager {@datastore, @cache, @uuidAliasResolver}

  describe 'when called without a uuid', ->
    beforeEach (done) ->
      @sut.search {uuid: null}, (@error) => done()

    it 'should have an error', ->
      expect(@error.message).to.equal 'Missing uuid'

  context 'OG devices', ->
    beforeEach (done) ->
      sabers = [
        {
          uuid: 'underwater-lightsaber'
          owner: 'darth-vader'
          type: 'light-saber'
        }
        {
          uuid: 'fire-saber'
          type: 'light-saber'
          discoverWhitelist: ['darth-vader']
        }
        {
          uuid: 'dual-phase-lightsaber'
          type: 'light-saber'
          color: 'red'
          discoverWhitelist: ['*']
        }
        {
          uuid: 'curve-hilted'
          type: 'light-saber'
          color: 'blue'
        }
        {
          uuid: 'great-lightsaber'
          configureWhitelist: ['*']
          type: 'light-saber'
        }
        {
          uuid: 'darth-vader'
          type: 'sith-lord'
        }
      ]
      @datastore.insert sabers, done

    context 'when called and it will find devices', ->
      beforeEach (done) ->
        @sut.search {uuid: 'darth-vader', query: {type:'light-saber'}}, (error, @devices) => done error

      it 'should return 3 devices', ->
        expect(@devices.length).to.equal 3

      it 'should return the correct devices', ->
        expect(@devices).to.containSubset [
          {uuid: 'underwater-lightsaber'}
          {uuid: 'fire-saber'}
          {uuid: 'dual-phase-lightsaber'}
        ]

    context 'when called with a null query and it will find devices', ->
      beforeEach (done) ->
        @sut.search {uuid: 'darth-vader', query: null}, (error, @devices) => done error

      it 'should return 3 devices', ->
        expect(@devices.length).to.equal 4

    context 'when called with an empty query and it will find devices', ->
      beforeEach (done) ->
        @sut.search {uuid: 'darth-vader', query: null}, (error, @devices) => done error

      it 'should return 3 devices', ->
        expect(@devices.length).to.equal 4

  context 'V2.0.0 Devices', ->
    beforeEach (done) ->
      beers = [
        {
          uuid: 'coors-i-dont-know'
          meshblu:
            version: '2.0.0'
            whitelists:
              discover: view: [uuid: '*']
          type: 'light-beer'

        }
        {
          uuid: 'peters-secret-special-brew'
          meshblu:
            version: '2.0.0'
            whitelists:
              discover: view: [uuid: 'darth-peter']
          type: 'light-beer'

        }
        {
          uuid: 'that-lucky-charms-leprechauns-brew'
          meshblu:
            version: '2.0.0'
            whitelists:
              discover: view: [uuid: 'that-lucky-charms-leprechaun']
          type: 'light-beer'

        }
        {
          uuid: 'peters-ipa-he-pretends-doesnt-exist'
          meshblu:
            version: '2.0.0'
            whitelists:
              discover: view: [uuid: '*']
          type: 'ipa-beer'

        }
      ]
      @datastore.insert beers, done

    beforeEach (done) ->
      @sut.search {uuid: 'darth-peter', query: {type:'light-beer'}}, (error, @devices) => done error

    it 'should return 2 devices', ->
      expect(@devices.length).to.equal 2

    it 'should return the correct devices', ->
      expect(@devices).to.containSubset [
        {uuid: 'coors-i-dont-know'}
        {uuid: 'peters-secret-special-brew'}
      ]

  context 'messed up hybrid devices', ->
    context 'v2 device with an OG whitelist', ->
      beforeEach (done) ->
        freakDevice =
          uuid: 'miss-transmogrified'
          meshblu:
            version: '2.0.0'
          discoverWhitelist: ['*']
          type: 'freak'

        @datastore.insert [freakDevice], done

      beforeEach (done) ->
        @sut.search {uuid: 'freak-finder', query: {type:'freak'}}, (error, @devices) => done error

      it 'should not return devices', ->
        expect(@devices).to.be.empty

    context 'v2 device with an owner', ->
      beforeEach (done) ->
        freakDevice =
          uuid: 'you-cant-own-me'
          meshblu:
            version: '2.0.0'
          owner: 'freak-finder'
          type: 'freak'

        @datastore.insert [freakDevice], done

      beforeEach (done) ->
        @sut.search {uuid: 'freak-finder', query: {type:'freak'}}, (error, @devices) => done error

      it 'should not return devices', ->
        expect(@devices).to.be.empty

  context 'OG device with v2 whitelists', ->
    beforeEach (done) ->
      freakDevice =
        uuid: 'do-what-i-want-not-what-i-say'
        meshblu:
          whitelists:
            discover:
              view: [uuid: '*']
        type: 'freak'

      @datastore.insert [freakDevice], done

    beforeEach (done) ->
      @sut.search {uuid: 'freak-finder', query: {type:'freak'}}, (error, @devices) => done error

    it 'should not return devices', ->
      expect(@devices).to.be.empty

  describe 'when a 1100 devices are created', ->
    beforeEach (done) ->
      sabers = _.times 1100, =>
        return {
          uuid: 'fire-saber'
          type: 'light-saber'
          discoverWhitelist: ['darth-vader']
        }
      @datastore.insert sabers, done

    describe 'when called and it will find only a 1000 devices', ->
      beforeEach (done) ->
        @sut.search {uuid: 'darth-vader', query: {type:'light-saber'}}, (error, @devices) => done error

      it 'should return 1000 devices', ->
        expect(@devices.length).to.equal 1000
