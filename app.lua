id  = 0
sda = 1
scl = 2
led = 0 -- pin for GPIO 0 = blue LED

-- CCS811 constants
STATUS_REG = 0x00
MEAS_MODE_REG = 0x01
ALG_RESULT_DATA = 0x02
ENV_DATA = 0x05
THRESHOLDS = 0x10
BASELINE = 0x11
HW_ID_REG = 0x20
ERROR_ID_REG = 0xE0
APP_START_REG = 0xF4
SW_RESET = 0xFF
CCS_811_ADDRESS = 0x5A
GPIO_WAKE = 0x5
DRIVE_MODE_IDLE = 0x0
DRIVE_MODE_1SEC = 0x10
DRIVE_MODE_10SEC = 0x20
DRIVE_MODE_60SEC = 0x30
INTERRUPT_DRIVEN = 0x8
THRESHOLDS_ENABLED = 0x4 

-- SI7021 constants
SI7021_ADDRESS = 0x40
CMD_MEASURE_HUMIDITY_HOLD = 0xE5
CMD_MEASURE_TEMPERATURE_HOLD = 0xE3

-- get thingspeak api key: APIKEY
dofile("credentials.lua")

-- generic i2c read.
function read_reg(dev_addr, reg_addr, bytes)
    i2c.start(id)
    i2c.address(id, dev_addr, i2c.TRANSMITTER)
    i2c.write(id, reg_addr)
    i2c.stop(id)
    i2c.start(id)
    i2c.address(id, dev_addr, i2c.RECEIVER)
    c = i2c.read(id, bytes)
    i2c.stop(id)
    return c
end

-- generic i2c write.
function write_reg(dev_addr, data)
	i2c.start(id)
	i2c.address(id, dev_addr, i2c.TRANSMITTER)
    i2c.write(id, data)
    i2c.stop(id)
end

-- CCS811 setup
function ccs811_setup()
    -- initialize i2c, set pin1 as sda, set pin2 as scl
    i2c.setup(id, sda, scl, i2c.SLOW)

    hwid = read_reg(CCS_811_ADDRESS, HW_ID_REG, 1)
    print(string.format("HW_ID: 0x%x (expect: 0x81)", string.byte(hwid)))

    sta = read_reg(CCS_811_ADDRESS, STATUS_REG, 1)
    err = read_reg(CCS_811_ADDRESS, ERROR_ID_REG, 1)
    print(string.format("STATUS: 0x%x, ERROR: 0x%x (expect: 0x10, 0x0)", string.byte(sta), string.byte(err)))

    write_reg(CCS_811_ADDRESS, APP_START_REG)
    print("wrote to APP_START")
    tmr.delay(2000) -- wait for 2ms

    sta = read_reg(CCS_811_ADDRESS, STATUS_REG, 1)
    err = read_reg(CCS_811_ADDRESS, ERROR_ID_REG, 1)
    print(string.format("STATUS: 0x%x, ERROR: 0x%x (expect: 0x90, 0x0)", string.byte(sta), string.byte(err)))

    -- set drive mode w/ interrupt disabled
    i2c.start(id)
    i2c.address(id, CCS_811_ADDRESS, i2c.TRANSMITTER)
    i2c.write(id, MEAS_MODE_REG, DRIVE_MODE_1SEC)
    i2c.stop(id)
    print("set drive mode = 1sec")
    tmr.delay(2000000) -- wait for 2s

    print("check data ready:")
    sta = read_reg(CCS_811_ADDRESS, STATUS_REG, 1)
    print(string.format("STATUS: 0x%x (expect: 0x98)", string.byte(sta)))
end

 -- read humidity and temperature from si7021
function read_si7021()
    dataH = read_reg(SI7021_ADDRESS, CMD_MEASURE_HUMIDITY_HOLD, 2)
    UH = string.byte(dataH, 1) * 256 + string.byte(dataH, 2)
    h = ((UH*12500+65536/2)/65536 - 600) / 100
    dataT = read_reg(SI7021_ADDRESS, CMD_MEASURE_TEMPERATURE_HOLD, 2)
    UT = string.byte(dataT, 1) * 256 + string.byte(dataT, 2)
    t = ((UT*17572+65536/2)/65536 - 4685) / 100
    return h, t
end

-- read eCO2, eTVOC, raw data, baseline from CCS811
function read_ccs811()
	buf = read_reg(CCS_811_ADDRESS, ALG_RESULT_DATA, 8)
    eCO2 = string.byte(buf,1) * 256 + string.byte(buf,2)
    eTVOC = string.byte(buf,3) * 256 + string.byte(buf,4)
    rawI = math.floor(string.byte(buf,7) / 4)
    rawV = (string.byte(buf,7) % 4) * 256 + string.byte(buf,8)
    buf = read_reg(CCS_811_ADDRESS, BASELINE, 2)
    baseline = string.byte(buf,1) * 256 + string.byte(buf,2)
    return eCO2, eTVOC, rawI, rawV, baseline
end

-- collect data from all sensors
function read_sensors()
    gpio.write(led, gpio.LOW)
    eCO2, eTVOC, rawI, rawV, baseline = read_ccs811()
    h, t = read_si7021()
    print(string.format("%d, %.2f, %.2f, %d, %d, %d, %d, %d",
          tmr.time(), t, h, eCO2, eTVOC, rawI, rawV, baseline))
    gpio.write(led, gpio.HIGH)
    return tmr.time(), t, h, eCO2, eTVOC, rawI, rawV, baseline
end

-- send data to file and to net connection
function send_data()
    time, t, h, eCO2, eTVOC, rawI, rawV, baseline = read_sensors()
    -- write to file
    if file.exists("data.csv") then
        f = file.open("data.csv", "a+")
    else
        f = file.open("data.csv", "w")
        f.writeline("time(s), temp(C), hum(%), eCO2(ppm), eTVOC(ppb), rawI(uA), rawV, baseline")
    end
    f.writeline(string.format("%d, %.2f, %.2f, %d, %d, %d, %d, %d",
                tmr.time(), t, h, eCO2, eTVOC, rawI, rawV, baseline))
    f.close()
    -- send to thingspeak
    conn:send('GET /update?key='..APIKEY..
       '&headers=false'..
       '&field1='..t..
       '&field2='..h..
       '&field3='..eCO2..
       '&field4='..eTVOC..
       '&field5='..rawI..
       '&field6='..rawV..
       '&field7='..baseline..
       '\r\n\r\n')
end

-- callbacks to send data to thingspeak
function sendToThingspeak()
    conn = net.createConnection(net.TCP, 0)
    conn:on("connection", function(conn)
        send_data()
    end)
    conn:on("sent", function(conn)
    end)
    conn:on("receive", function(conn, payload)
        conn:close()
    end)

    conn:connect(80, 'api.thingspeak.com') 
end

-- MAIN --
ccs811_setup()
print("data collection:") 
print("time(s), temp(C), hum(%), eCO2(ppm), eTVOC(ppb), rawI(uA), rawV, baseline")
tmr.alarm(1, 60000, 1, sendToThingspeak) -- 1 min
