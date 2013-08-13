var log = require('./logger').create();

var Executor = function(capturedBrowsers, config, emitter) {
  var self = this;
  var batchSize = config.singleRunBatchSize;
  var runInBatches = config.singleRun && batchSize > 0;
  var untestedCount = config.singleRun ? config.browsers.length : 0;
  var executionScheduled = false;
  var pendingCount = 0;
  var runningBrowsers;

  var run = function(browsers) {
    executionScheduled = false;
    browsers.setAllIsReadyTo(false);
    browsers.clearResults();
    pendingCount = browsers.length;
    runningBrowsers = browsers.clone();
    emitter.emit('run_start', runningBrowsers);
    self.socketIoSockets.emit('execute', config.client);
  };

  var schedule = function() {
    var nonReady = [];
    var readyBrowsers;
    var runBatch = false;

    if (!capturedBrowsers.length) {
      log.warn('No captured browser, open http://%s:%s%s', config.hostname, config.port,
          config.urlRoot);
      return false;
    }

    if (!runInBatches) {
      if (capturedBrowsers.areAllReady(nonReady)) {
        log.debug('All browsers are ready, executing');
        run(capturedBrowsers);
        return true;
      }

      log.info('Delaying execution, these browsers are not ready: ' + nonReady.join(', '));
      executionScheduled = true;
      return false;
    }

    // batch handling
    readyBrowsers = capturedBrowsers.getReadyBrowsers(nonReady);
    runBatch = readyBrowsers.length >= batchSize || readyBrowsers.length === untestedCount;
    if (runBatch) {
      log.debug(batchSize + ' browsers are ready, executing');
      run(readyBrowsers);
      return true;
    }
  };

  this.schedule = schedule;

  this.onRunComplete = function() {
    if (executionScheduled) {
      schedule();
    }
  };

  this.onBrowserComplete = function() {
    pendingCount--;

    if (!runInBatches && !pendingCount) {
      emitter.emit('run_complete', runningBrowsers, runningBrowsers.getResults());
    }

    if (runInBatches) {
      untestedCount--;

      if (!untestedCount) {
        emitter.emit('run_complete', runningBrowsers, runningBrowsers.getResults());
      } else if (!pendingCount) {
        emitter.emit('batch_run_complete', runningBrowsers, runningBrowsers.getResults());
      }
    }
  };

  // bind all the events
  emitter.bind(this);
};


module.exports = Executor;
