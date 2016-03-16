mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
Cache         = require 'meshblu-core-cache'
redis         = require 'fakeredis'
uuid          = require 'uuid'
DeviceManager = require '..'

describe 'DeviceManager', ->
  beforeEach (done) ->
    @datastore = new Datastore
      database: mongojs 'subscription-manager-test'
      collection: 'subscriptions'

    @datastore.remove done

    @cache = new Cache client: redis.createClient uuid.v1()

  beforeEach ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new DeviceManager {@datastore, @cache, @uuidAliasResolver}

  describe '->findOne', ->
    describe 'when called with a subscriberUuid and has subscriptions', ->
      beforeEach (done) ->
        record =
          uuid: 'pet-rock'

        @datastore.insert record, done

      beforeEach (done) ->
        @sut.findOne {uuid:'pet-rock'}, (error, @device) => done error

      it 'should have a device', ->
        expect(@device).to.deep.equal uuid: 'pet-rock'

  describe '->update', ->
    describe 'when the device exists', ->
      beforeEach (done) ->
        record =
          uuid: 'wet-sock'

        @datastore.insert record, done

      beforeEach (done) ->
        update =
          $set:
            foo: 'bar'
        @sut.update {uuid:'wet-sock',data:update}, (error) => done error

      it 'should have a device', (done) ->
        @datastore.findOne {uuid: 'wet-sock'}, (error, device) =>
          return done error if error?
          expect(device).to.deep.contain uuid: 'wet-sock', foo: 'bar'
          expect(device.meshblu.updatedAt).not.to.be.undefined
          expect(device.meshblu.hash).not.to.be.undefined
          done()

  describe '->create', ->
    beforeEach (done) ->
      @sut.create {type:'not-wet'}, (error, @device) => done error

    it 'should return you a device with the uuid and token', ->
      console.log @device
      expect(@device.uuid).to.exist
      expect(@device.token).to.exist

    it 'should have a device and all of the base properties', (done) ->
      @datastore.findOne {uuid: @device.uuid}, (error, device) =>
        return done error if error?
        console.log device
        expect(device.type).to.equal 'not-wet'
        expect(device.online).to.be.false
        expect(device.uuid).to.exist
        expect(device.token).to.exist
        expect(device.meshblu.createdAt).to.exist
        expect(device.meshblu.hash).to.exist
        done()

    it 'should create the token in the cache', (done) ->
      @datastore.findOne {uuid: @device.uuid}, (error, device) =>
        return done error if error?
        @cache.exists "meshblu-token-cache:#{device.uuid}:#{device.token}", (error, result) =>
          return done error if error?
          expect(result).to.be.true
          done()
