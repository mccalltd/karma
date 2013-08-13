describe 'executor', ->
  Browser = require('../../lib/browser').Browser
  BrowserCollection = require('../../lib/browser').Collection
  EventEmitter = require('../../lib/events').EventEmitter
  Executor = require '../../lib/executor'

  executor = emitter = capturedBrowsers = config = spy = null

  setup = (configuration) ->
    config = configuration
    emitter = new EventEmitter
    capturedBrowsers = new BrowserCollection emitter
    capturedBrowsers.add new Browser
    executor = new Executor capturedBrowsers, config, emitter
    executor.socketIoSockets = new EventEmitter

    spy =
      onRunStart: -> null
      onRunComplete: -> null
      onBatchRunComplete: -> null
      onSocketsExecute: -> null

    sinon.spy spy, 'onRunStart'
    sinon.spy spy, 'onRunComplete'
    sinon.spy spy, 'onBatchRunComplete'
    sinon.spy spy, 'onSocketsExecute'

    emitter.on 'run_start', spy.onRunStart
    emitter.on 'run_complete', spy.onRunComplete
    emitter.on 'batch_run_complete', spy.onBatchRunComplete
    executor.socketIoSockets.on 'execute', spy.onSocketsExecute


  #============================================================================
  # not batching runs
  #============================================================================
  describe 'when not batching runs', ->
    beforeEach ->
      setup {client: {}}


    it 'should start the run and pass client config', ->
      capturedBrowsers.areAllReady = -> true

      executor.schedule()
      expect(spy.onRunStart).to.have.been.called
      expect(spy.onSocketsExecute).to.have.been.calledWith config.client


    it 'should wait for all browsers to finish', ->
      capturedBrowsers.areAllReady = -> false

      # they are not ready yet
      executor.schedule()
      expect(spy.onRunStart).not.to.have.been.called
      expect(spy.onSocketsExecute).not.to.have.been.called

      capturedBrowsers.areAllReady = -> true
      emitter.emit 'run_complete'
      expect(spy.onRunStart).to.have.been.called
      expect(spy.onSocketsExecute).to.have.been.called


  #============================================================================
  # batching runs
  #============================================================================
  describe 'when batching runs', ->
    readyBrowsers = null

    beforeEach ->
      setup {client: {}, browsers: ['Fake', 'Fake', 'Fake'], singleRun: true, singleRunBatchSize: 2}
      readyBrowsers = new BrowserCollection emitter
      capturedBrowsers.getReadyBrowsers = -> readyBrowsers


    it 'should start the run when a batch of browsers is ready', ->
      capturedBrowsers.areAllReady = -> false

      # batch is not ready yet
      executor.schedule()
      expect(spy.onRunStart).not.to.have.been.called
      expect(spy.onSocketsExecute).not.to.have.been.called

      # batch is ready
      readyBrowsers.add new Browser
      readyBrowsers.add new Browser
      executor.schedule()
      expect(spy.onRunStart).to.have.been.called
      expect(spy.onSocketsExecute).to.have.been.calledWith config.client


    it 'should start the run when all the browsers are ready', ->
      capturedBrowsers.add new Browser
      capturedBrowsers.add new Browser
      readyBrowsers.add new Browser
      readyBrowsers.add new Browser
      readyBrowsers.add new Browser

      executor.schedule()
      expect(spy.onRunStart).to.have.been.called
      expect(spy.onSocketsExecute).to.have.been.calledWith config.client


    it 'should emit "batch_run_complete" after a batch run finishes', ->
      readyBrowsers.add new Browser
      readyBrowsers.add new Browser

      executor.schedule()
      executor.onBrowserComplete()
      expect(spy.onBatchRunComplete).not.to.have.been.called

      executor.onBrowserComplete()
      expect(spy.onBatchRunComplete).to.have.been.calledWith


    it 'should emit "run_complete" after all browsers finish', ->
      readyBrowsers.add new Browser
      readyBrowsers.add new Browser

      executor.schedule()
      executor.onBrowserComplete()
      executor.onBrowserComplete()
      expect(spy.onRunComplete).not.to.have.been.called

      executor.schedule()
      executor.onBrowserComplete()
      expect(spy.onRunComplete).to.have.been.calledWith
