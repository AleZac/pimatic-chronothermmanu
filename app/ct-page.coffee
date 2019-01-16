$(document).on( "templateinit", (event) ->

  class ChronoThermManuItem extends pimatic.DeviceItem
    constructor: (templData, @device) ->
      super(templData, @device)

      @inputValue = ko.observable()
      @stAttr = @getAttribute('manuTemp')
      @inputValue(@stAttr.value())

      attrValue = @stAttr.value()
      @stAttr.value.subscribe( (value) =>
        @inputValue(value)
        attrValue = value
      )
      if @device.config.boost?
        @boost = 1
      else
        @boost = 0
      if @device.config.showseason?
        @showseason = 1
      else
        @showseason = 0

      attribute = @getAttribute("result")
      @tempPresunta = ko.observable attribute.value()
      attribute.value.subscribe (newValue) =>
        @tempPresunta newValue

      attributetemperature = @getAttribute("realtemperature")
      @tempEffettiva = ko.observable attributetemperature.value()
      attributetemperature.value.subscribe (newValue) =>
        @tempEffettiva newValue

      attributeseason = @getAttribute("season")
      @season = ko.observable attributeseason.value()
      attributeseason.value.subscribe (newValue) =>
        @season newValue

      attributevalve = @getAttribute("valve")
      @valve = ko.observable attributevalve.value()
      attributevalve.value.subscribe (newValue) =>
        @valve newValue

      ko.computed( =>
        textValue = @inputValue()
        if textValue? and attrValue? and parseFloat(attrValue) isnt parseFloat(textValue)
          @changeTemperatureTo(parseFloat(textValue))
      ).extend({ rateLimit: { timeout: 1000, method: "notifyWhenChangesStop" } })

      @modo = "manu"

    afterRender: (elements) ->
      super(elements)

      @pulsmanu = $(elements).find('[name=pulsmanu]')
      @pulsboost = $(elements).find('[name=pulsboost]')
      @pulsoff = $(elements).find('[name=pulsoff]')
      @pulsseason = $(elements).find('[name=pulsseason]')
      @input = $(elements).find('.spinbox input')
      @input.spinbox()
      @updateButtons()
      @getAttribute('mode').value.subscribe( => @updateButtons() )
      # if @season is "winter" then @pulsseasonw.removeClass('nascondi')
      # if @season is "summer" then @pulsseasons.removeClass('nascondi')
      return
    manuMode: -> @changeModeTo "manu"
    offMode: -> @changeModeTo "off"
    boostMode: -> @changeModeTo "boost"
    setTemp: -> @changeTemperatureTo "#{@inputValue.value()}"
    seasonMode: ->
      if @season() is "winter"
        @changeSeasonTo "summer"
      else
        @changeSeasonTo "winter"
    changeSeasonTo: (season) ->
      @device.rest.changeSeasonTo({season}, global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
    changeModeTo: (mode) ->
      @device.rest.changeModeTo({mode}, global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
    changeTemperatureTo: (manuTemp) ->
      @device.rest.changeTemperatureTo({manuTemp}, global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
    updateButtons: ->
      modeAttr = @getAttribute('mode').value()
      switch modeAttr
        when 'manu'
          @pulsmanu.addClass('ui-btn-active')
          @pulsoff.removeClass('ui-btn-active')
          @pulsboost.removeClass('ui-btn-active')
        when 'off'
          @pulsmanu.removeClass('ui-btn-active')
          @pulsoff.addClass('ui-btn-active')
          @pulsboost.removeClass('ui-btn-active')
        when 'boost'
          @pulsmanu.removeClass('ui-btn-active')
          @pulsoff.removeClass('ui-btn-active')
          @pulsboost.addClass('ui-btn-active')
      return
    getConfig: (name) ->
      if @device.config[name]?
        return @device.config[name]
      else
        return @device.configDefaults[name]

  pimatic.templateClasses['ChronoThermManuDevice'] = ChronoThermManuItem
)
