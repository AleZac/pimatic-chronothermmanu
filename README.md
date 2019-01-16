#Pimatic ChronoTherm
Manual thermostat plugin for the Pimatic

![alt tag](https://github.com/AleZac/pimatic-chronothermmanu/blob/master/screenshot/ChronoThermManu.png)


This is the same version of ChronoTherm but I have eliminated all the automatic part leaving only the manual mode.
For information, read the readme of the ChronoTherm plugin

###Configuration
To include the plugin in pimatic add the device to plugin section with...
```
{
  "plugin": "chronothermmanu"
},
```
then add device to config.json
```
{
  "id": "room",
  "class": "ChronoThermDevice",
  "name": "Room",
  "realtemperature": "$switch.manuTemp",
  "interval": 240,
  "showseason": false,
  "offwintemp": 4,
  "offsummtemp": 31
}
```

###WEB INTERFACE

***The green circle*** indicates the actual temperature detected

***The blue circle*** indicates the supposed temperature programming

When the border of ***The blue circle*** is ***green*** the valve variable is true

When the border of ***The blue circle*** is ***white*** the valve variable is false

***On*** indicates that the supposed temperature will be to set manually

***OFF*** will set the supposed temperature to ***"offtemperature"***

***winter or summer*** show the season current

### API
To set mode from API
  http://host:port/api/device/ROOM/changeModeTo?mode=MODE
    ROOM = Id of the room
    MODE = on, off
To set mintoautomode
  http://host:port/api/device/ROOM/changeMinToAutoModeTo?mintoautomode=XXX
    XXX = minute tu turn to automode(Normal schedule)
  TRICK:  if you want to set mintoautomode to End of Day, XXX = 0.307
          if you want to set mintoautomode to End of Schedule, XXX = 0.305
To set season
  http://host:port/api/device/ROOM/changeSeasonTo?season=SEASON
    SEASON = winter, summer
To change manual temperature
  http://host:port/api/device/ROOM/changeTemperatureTo?manuTemp=TEMPERATURE
