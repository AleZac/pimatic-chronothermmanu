module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  types = env.require('decl-api').types
  _ = env.require 'lodash'
  M = env.matcher


  class ChronoThermManuPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      deviceConfigDef = require("./device-config-schema")
      @framework.deviceManager.registerDeviceClass("ChronoThermManuDevice", {
        configDef: deviceConfigDef.ChronoThermManuDevice,
        createCallback: (config, lastState, framework) ->
          return new ChronoThermManuDevice(config, lastState)
      })

      @framework.ruleManager.addActionProvider(new ChronoThermSeasonActionProvider(@framework))
      # wait till all plugins are loaded
      @framework.on "after init", =>
      # Check if the mobile-frontent was loaded and get a instance
        mobileFrontend = @framework.pluginManager.getPlugin 'mobile-frontend'
        if mobileFrontend?
          mobileFrontend.registerAssetFile 'js', "pimatic-chronothermmanu/app/ct-page.coffee"
          mobileFrontend.registerAssetFile 'css', "pimatic-chronothermmanu/app/ct.css"
          mobileFrontend.registerAssetFile 'html', "pimatic-chronothermmanu/app/ct.html"
        else
          env.logger.warn "your plugin could not find the mobile-frontend. No gui will be available"

  class ChronoThermManuDevice extends env.devices.Device


    realtemperature: 0
    result: 0
    perweb: 0
    _mode: null
    _manuTemp: null

    attributes:
      result:
        description: "Result"
        type: "number"
      realtemperature:
        description: "Variable with real temperature"
        type: "string"
      mode:
        description: "The current mode"
        type: "string"
        enum: ["manu", "off", "boost"]
      manuTemp:
        label: "Temperature Setpoint"
        description: "The temp that should be set"
        type: "number"
      valve:
        description: "valve"
        type: "boolean"
      season:
        description: "The current season"
        type: "string"
        enum: ["winter", "summer"]
    actions:
      changeValveTo:
        params:
          valve:
            type:"boolean"
      changeSeasonTo:
        params:
          season:
            type: "string"
      changeModeTo:
        params:
          mode:
            type: "string"
      changeTemperatureTo:
        params:
          manuTemp:
            type: "number"
    template: "ChronoThermManuDevice"

    constructor: (@config, lastState, framework) ->
      @id = @config.id
      @name = @config.name
      @realtemperature = 0
      @result = 0
      @setMode(lastState?.mode?.value or "manu")
      @intattivo = 0
      @setManuTemp(lastState?.manuTemp?.value or 20)
      @season = lastState?.season?.value or "winter"
      @varManager = plugin.framework.variableManager #so you get the variableManager
      @_exprChangeListeners = []

      for reference in [
        {name: "realtemperature", expression: @config.realtemperature}
      ]
        do (reference) =>
          name = reference.name
          info = null

          evaluate = ( =>
            # wait till VariableManager is ready
            return Promise.delay(10).then( =>
              unless info?
                info = @varManager.parseVariableExpression(reference.expression)
                @varManager.notifyOnChange(info.tokens, evaluate)
                @_exprChangeListeners.push evaluate
              switch info.datatype
                when "numeric" then @varManager.evaluateNumericExpression(info.tokens)
                when "string"then @varManager.evaluateStringExpression(info.tokens)
                else
                  assert false
            ).then((val) =>
              if val
                env.logger.debug @id, name, val
                val = val.toFixed(1)
                @_setAttribute name, val
              return @[name]
            )
          )
          @_createGetter(name, evaluate)
      super()
      @girotempo = setInterval ( =>
        @setValve()
        ), 1000 * @config.interval
    setValve:() ->
      if @season is "winter"
        if @realtemperature < @result
          @valve = true
        else
          @valve = false
      else
        if @realtemperature > @result
          @valve = true
        else
          @valve = false
      @emit "valve", @valve
      return Promise.resolve()
    _setAttribute: (attributeName, value) ->
      if @[attributeName] isnt value
        @[attributeName] = value
        @emit attributeName, value
    setSeason: (season) ->
      if season is @season then return
      @season = season
      @emit "season",@season
      return Promise.resolve()
    setMode: (mode) ->
      if mode is @_mode then return
      switch mode
        when 'manu'
          @result = @_manuTemp
          @emit "result", @result
        when 'boost'
          @result = 50
          @emit "result", @result
        when 'off'
    #       if @config.interface is 0
          if @season is "winter"
            @result = @config.offwintemp
          else
            @result = @config.offsummtemp
          @emit "result", @result
      @_mode = mode
      @emit "mode", @_mode
      return Promise.resolve()
    setManuTemp: (manuTemp) ->
      if manuTemp is @_manuTemp then return
      @_manuTemp = manuTemp
      if @_mode is "manu"
        @result = @_manuTemp
        @emit "result", @result
      @emit "manuTemp", @_manuTemp
      return Promise.resolve()
    changeSeasonTo: (season) ->
      @setSeason(season)
      return Promise.resolve()
    changeModeTo: (mode) ->
      @setMode(mode)
      return Promise.resolve()
    changeTemperatureTo: (manuTemp) ->
      @setManuTemp(manuTemp)
      return Promise.resolve()
    destroy: () ->
      @varManager.cancelNotifyOnChange(cl) for cl in @_exprChangeListeners
      super()
    getManuTemp: () ->  Promise.resolve(@_manuTemp)
    getMode: () ->  Promise.resolve(@_mode)
    getResult: () -> Promise.resolve(@result)
    getRealTemperature: () -> Promise.resolve(@realtemperature)
    getValve: () -> Promise.resolve(@valve)
    getSeason: () -> Promise.resolve(@season)

  class ChronoThermSeasonActionProvider extends env.actions.ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) =>
      # The result the function will return:
      retVar = null

      season = _(@framework.deviceManager.devices).values().filter(
        (device) => device.hasAction("changeSeasonTo")
      ).value()

      if season.length is 0 then return

      device = null
      valueTokens = null
      match = null

      # Try to match the input string with:
      M(input, context)
        .match('set season of ')
        .matchDevice(season, (next, d) =>
          next.match(' to ')
            .matchStringWithVars( (next, ts) =>
              m = next.match(' season', optional: yes)
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              device = d
              valueTokens = ts
              match = m.getFullMatch()
            )
        )

      if match?
        if valueTokens.length is 1 and not isNaN(valueTokens[0])
          value = valueTokens[0]
          assert(not isNaN(value))
          modes = ["winter", "summer"]
          if modes.indexOf(value) < -1
            context?.addError("Allowed modes: winter,summer")
            return
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new ChronoThermSeasonActionHandler(@framework, device, valueTokens)
        }
      else
        return null
  class ChronoThermSeasonActionHandler extends env.actions.ActionHandler

    constructor: (@framework, @device, @valueTokens) ->
      assert @device?
      assert @valueTokens?

    setup: ->
      @dependOnDevice(@device)
      super()

    ###
    Handles the above actions.
    ###
    _doExecuteAction: (simulate, value) =>
      return (
        if simulate
          __("would set mode %s to %s", @device.name, value)
        else
          @device.changeSeasonTo(value).then( => __("set season %s to %s", @device.name, value) )
      )

    # ### executeAction()
    executeAction: (simulate) =>
      @framework.variableManager.evaluateStringExpression(@valueTokens).then( (value) =>
        @lastValue = value
        return @_doExecuteAction(simulate, value)
      )

    # ### hasRestoreAction()
    hasRestoreAction: -> yes
    # ### executeRestoreAction()
    executeRestoreAction: (simulate) => Promise.resolve(@_doExecuteAction(simulate, @lastValue))

  plugin = new ChronoThermManuPlugin
  return plugin
