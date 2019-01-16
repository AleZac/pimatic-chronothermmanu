module.exports = {
  title: "pimatic-chronothermmanu device config schemas"
  ChronoThermManuDevice: {
    title: "ChronoThermManuDevice config options"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:
      showseason:
        description: "Show the season interface"
        type: "boolean"
        default: false
        required: false
      realtemperature:
        description: "variable with the real temperature"
        type: "string"
      boost:
        description: "boost mode"
        type: "boolean"
        required: false
      interval:
        description: "time in seconds to refresh the schedule"
        type: "number"
      offwintemp:
        description: "the winter temperature for the off button"
        type: "number"
      offsummtemp:
        description: "the summer temperature for the off button"
        type: "number"
  }
}
