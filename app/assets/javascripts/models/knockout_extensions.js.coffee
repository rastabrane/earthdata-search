do (ko, $=jQuery) ->

  ko.observableArray.fn.contains = (obj) ->
    @indexOf(obj) != -1

  ko.observableArray.fn.isEmpty = (obj) ->
    this().length == 0

  # Valid names: 'added', 'deleted', 'retained'
  ko.observableArray.fn.subscribeChange = (status, callback) ->
    previousValue = null

    beforeChange = (oldValue) ->
      previousValue = oldValue.slice(0)

    afterChange = (latestValue) ->
      for {status, value} in ko.utils.compareArrays(previousValue, latestValue)
        callback?(value) if status == 'name'
      previousValue = null

    @subscribe(beforeChange, undefined, 'beforeChange')
    @subscribe(afterChange)

  ko.observableArray.fn.subscribeAdd = (callback) ->
    @subscribeChange('added', callback)

  ko.observableArray.fn.subscribeRemove = (callback) ->
    @subscribeChange('deleted', callback)

  # http://www.knockmeout.net/2012/05/quick-tip-skip-binding.html
  ko.bindingHandlers.stopBinding =
    init: ->
      controlsDescendantBindings: true
  ko.virtualElements.allowedBindings.stopBinding = true

  # For observables that need to make an XHR or similar call to compute their value
  ko.asyncComputed = (initialValue, timeout, method, obj) ->
    value = ko.observable(initialValue)

    isSetup = ko.observable(false)

    isPendingRead = true

    callAsyncMethod = ->
      method.call obj, value.peek(), value, isPendingRead
      isPendingRead = true

    asyncComputed = ko.computed
      read: ->
        val = value.peek()
        callAsyncMethod()
        val
      write: value
      deferEvaluation: true

    result = ko.computed
      read: ->
        # Causes an evaluation of computed, thereby setting up dependencies correctly
        unless isSetup()
          asyncComputed.extend(throttle: timeout)
          isSetup(true)
        value()
      write: (newValue) ->
        isSetup(true) unless isSetup()
        value(newValue)
      deferEvaluation: true

    result.isSetup = isSetup

    result.readImmediate = ->
      callAsyncMethod()
      isPendingRead = false

    originalDispose = result.dispose
    result.dispose = ->
      originalDispose()
      asyncComputed.dispose()

    result


  ko.bindingHandlers.showModal =
    init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->

    update: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
      isShown = ko.unwrap(valueAccessor())
      if isShown
        method = 'show'
      else
        method = 'hide'
      $(element).modal(method)


  ko.bindingHandlers.echoform =
    init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
    update: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
      $el = $(element)
      if $el.data('echoforms')
        $el.echoforms('destroy')
        $el.off('echoforms:modelchange')

      options = ko.unwrap(valueAccessor())
      methodName = options.method()
      if methodName?
        method = null
        for available in options.availableMethods
          if available.name == methodName
            method = available
            break
        if available?.form?
          $el.echoforms(form: available.form)
          syncModel = ->
            isValid = $(this).echoforms('isValid')
            options.isValid(isValid)
            if isValid
              modelString = $(this).echoforms('serialize')
              options.model = modelString
            else
              options.model = null
            null
          $el.on 'echoforms:modelchange', syncModel
          syncModel.call($el)
        else
          options.isValid(true)
      null
