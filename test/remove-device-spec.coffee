mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
Cache         = require 'meshblu-core-cache'
redis         = require 'fakeredis'
uuid          = require 'uuid'
DeviceManager = require '..'

describe 'Remove Device', ->
  beforeEach (done) ->
    @datastore = new Datastore
      database: mongojs 'device-manager-test'
      collection: 'devices-test'

    @datastore.remove done

    @cache = new Cache client: redis.createClient uuid.v1()

  beforeEach ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new DeviceManager {@datastore, @cache, @uuidAliasResolver}

  describe 'when the device exists', ->
    beforeEach (done) ->
      record =
        uuid: 'should-be-removed-uuid'

      @datastore.insert record, done

    beforeEach (done) ->
      record =
        uuid: 'should-not-be-removed-uuid'

      @datastore.insert record, done

    beforeEach (done) ->
      @sut.remove {uuid:'should-be-removed-uuid'}, (error) => done error

    it 'should remove the device', (done) ->
      @datastore.findOne {uuid: 'should-be-removed-uuid'}, (error, device) =>
        return done error if error?
        expect(device).to.not.exist
        done()

    it 'should not remove the other device', (done) ->
      @datastore.findOne {uuid: 'should-not-be-removed-uuid'}, (error, device) =>
        return done error if error?
        expect(device.uuid).to.equal 'should-not-be-removed-uuid'
        done()

  describe 'when the device doesn\'t exists', ->
    beforeEach (done) ->
      @sut.remove {uuid:'unknown-uuid'}, (@error) => done()

    it 'should not have an error',  ->
      expect(@error).to.not.exist

  describe 'when called without a uuid', ->
    beforeEach (done) ->
      @sut.remove {uuid: null}, (@error) => done()

    it 'should have an error',  ->
      expect(@error.message).to.equal 'Missing uuid'
