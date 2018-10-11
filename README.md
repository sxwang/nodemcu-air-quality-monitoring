nodemcu-air-quality-monitoring
==============================

A small project to monitor indoor air quality with an ESP8266 microcontroller and CJMCU8128 sensor board.

The current setup collects temperature, humidity, eCO2, eTVOC, and a few other internal metrics on a regular interval, and saves the data to onboard flash as well as upload them to thingspeak.com. 

Getting Started
---------------

1. Download and install the USB-serial driver [Silabs](https://www.silabs.com/products/development-tools/software/usb-to-uart-bridge-vcp-drivers). Note for macOS driver: clicking the 'Allow' button from the 'Security & Privacy' requires exiting Chrome.

1. Install node.js with homebrew. Then use npm to install [NodeMCU-Tool](https://github.com/andidittrich/NodeMCU-Tool).

   Set the following for `.nodemcutool` config:

    ```shell
    $ cat .nodemcutool
    {
        "baudrate": "115200",
        "port": "/dev/tty.SLAB_USBtoUART",
        "minify": false,
        "compile": false,
        "keeppath": false
    }
    ```

1. Flash the firmware on the ESP8266:

    1. build w/ cloud service: http://nodemcu-build.com/.
included modules: bme280, bme680, encoder, file, gpio, http, i2c, net, node, si7021, tmr, uart, wifi. Will receive an email w/ links to 2 .bin files. I used the float one.

    1. pip install esptool.py, then:
`./Library/Python/3.7/bin/esptool.py write_flash 0x00000 ~/Downloads/nodemcu-master-13-modules-2018-10-10-17-16-51-float.bin`

1. For development: update `credentials.lua` as needed. Then upload the `app.lua` and `credentials.lua` files with `nodemcu-tool upload`. Use `nodemcu-tool terminal` to test changes on device.

1. For deployment: update `init.lua` to run `dofile("app.lua")` after wifi setup completes. Update all files on device, and power-on the device at the desired measurement location. The device will run `init.lua` automatically and start the data collection.

Note: If `init.lua` runs a `dofile("app.lua")` and `app.lua` is set to  take data indefinitely, it seems not possible to interact with the device in this state using nodemcu-tool. The solution I've used is to reset the device (usually by unplugging) and then run `nodemcu-tool remove init.lua` immediately after power-on before `init.lua` starts executing. See this [FAQ entry](https://nodemcu.readthedocs.io/en/master/en/lua-developer-faq/#how-do-i-avoid-a-panic-loop-in-initlua) in the NodeMCU docs.

Data Analysis
-------------

Download the data from the device:

```shell
$ nodemcu-tool download data.csv
```

Or from Thingspeak with curl (look up the correct channel id):
```shell
$ curl 'https://api.thingspeak.com/channels/CHANNEL_ID/feeds.json?results=2&timezone=America%2FLos_Angeles'
```

Typical values for CO2 and TVOC concentration in homes:

- CO2: 350-1,000ppm ( [kane](https://www.kane.co.uk/knowledge-centre/what-are-safe-levels-of-co-and-co2-in-rooms) )
- TVOC: 0-65 ppb ( [sensirion](https://www.repcomsrl.com/wp-content/uploads/2017/06/Environmental_Sensing_VOC_Product_Brochure_EN.pdf) )

CCS811 measurement range (from datasheet):

- eCO2: 400-32768 ppm
- eTVOC: 0-32768 ppb

References
----------

* [CCS811 datasheet](http://ams.com/documents/20143/36005/CCS811_DS000459_6-00.pdf)
* [CCS811 programming guide](https://ams.com/documents/20143/36005/CCS811_AN000369_2-00.pdf/25d0db9a-92b9-fa7f-362c-a7a4d1e292be)
* [CCS811 Application Note: Baseline save & restore](https://ams.com/documents/20143/36005/CCS811_AN000370_2-00.pdf/ee95d147-0bca-dbbb-51a6-c6fd32ce4b28)
* [nodemcu-tool command reference](https://github.com/AndiDittrich/NodeMCU-Tool/blob/master/docs/CommandReference.md)
* [NodeMCU docs](https://nodemcu.readthedocs.io/en/master/), [i2c reference](https://nodemcu.readthedocs.io/en/master/en/modules/i2c/)

I've borrowed code liberally from the following places for inspiration:

* [Strawdogs blogpost w/ link to python library](https://www.strawdogs.co/2018/07/Using-the-CJMCU-8128-Breakout-Environment-Sensor-Board/)
* [Sparkfun tutorial](https://learn.sparkfun.com/tutorials/ccs811-air-quality-breakout-hookup-guide)
* [Send live data to thingspeak example](https://github.com/nodemcu/nodemcu-firmware/issues/762)
* [A discussion on calibration and stability of the CCS811](https://github.com/NordicSemiconductor/Nordic-Thingy52-FW/issues/21)