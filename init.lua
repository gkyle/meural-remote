-- A simple HTTP-based remote for 1 or more Meural Canvases.

local AP_SSID = "" -- TODO
local AP_PASSWORD = "" -- TODO
local ALARM_CONNECT_STATUS_LOOP = 0

local frames = {
-- List the IP addrsses of your Meural canvases here.
}

--

local requests = {} -- Queue for HTTP requests.
local debounce = false

function clearDebounce()
  debounce = false
  gpio.write(6, 0);
end

function resume()
  if (debounce == false) then
    debounce = true
    gpio.write(6, 1)
    print("resume")
    for host in values(frames) do
      request(host, "resume")
    end
    tmr.alarm(1, 100, 1, function() clearDebounce() end)
  end
end

function suspend()
  if (debounce == false) then
    gpio.write(6, 1)
    debounce = true
    print("suspend")
    for host in values(frames) do
      request(host, "suspend")
    end
    tmr.alarm(1, 100, 1, function() clearDebounce() end)
  end
end

function left()
  if (debounce == false) then
    debounce = true
    gpio.write(6, 1)
    print("left")
    for host in values(frames) do
      request(host, "set_key/left/")
    end
    tmr.alarm(1, 100, 1, function() clearDebounce() end)
  end
end

function right()
  if (debounce == false) then
    debounce = true
    gpio.write(6, 1)
    print("right")
    for host in values(frames) do
      request(host, "set_key/right/")
    end
    tmr.alarm(1, 100, 1, function() clearDebounce() end)
  end
end

-- io12: LED
gpio.mode(6, gpio.OUTPUT)

-- io13: resume
gpio.mode(7, gpio.INT,  gpio.PULLUP)
gpio.trig(7, "down", resume)

-- io10: left
gpio.mode(12, gpio.INT,  gpio.PULLUP)
gpio.trig(12, "down", left)

-- io4: right
gpio.mode(2, gpio.INT,  gpio.PULLUP)
gpio.trig(2, "down", right)

-- io0: suspend
gpio.mode(3, gpio.INT,  gpio.PULLUP)
gpio.trig(3, "down", suspend)


function values(t)
  local i = 0
  return function() i = i + 1; return t[i] end
end

local fetching = false
function fetch()
  if (fetching == false) then
    fetching = true
    local url = table.remove(requests, 1)
    print("fetching...")
    if (url) then
      print("URL: " .. url)
      http.get(url, nil, function(code, data)
        if (code < 0) then
          print("HTTP request failed: " .. url)
        else
          print(code, data)
        end
        fetching = false
        bump()
      end)
    else
      fetching = false
    end
  end
end

function request(host, cmd)
  url = "http://" .. host .. "/remote/control_command/" .. cmd
  table.insert(requests, url)
  bump()
end

function bump()
  if (table.getn(requests) > 0) then
    tmr.alarm(2, 1, tmr.ALARM_SINGLE, function() fetch() end)
  end
end

function setupWIFI()
  uart.write(0, "Connecting.")

  wifi.setmode(wifi.STATION);
  station_cfg={}
  station_cfg.ssid=AP_SSID
  station_cfg.pwd=AP_PASSWORD
  wifi.sta.config(station_cfg)

  wifi.sleeptype(wifi.NONE_SLEEP)
  wifi.sta.sethostname("meural-remote")
  wifi.sta.connect()
  checkWIFI()
end

function checkWIFI()
  local ipAddr = wifi.sta.getip()
  if ((ipAddr ~= nil) and (ipAddr ~= "0.0.0.0")) then
    wifi.sta.sethostname("meural-remote")
    uart.write(0, "Current hostname is: \""..wifi.sta.gethostname().."\"\n")
    uart.write(0, "IP Address: " .. ipAddr .. "\n")
  else
    gpio.write(6, 1);
    uart.write(0, ".")
    tmr.alarm(ALARM_CONNECT_STATUS_LOOP, 1000, 0, checkWIFI )
    tmr.alarm(1, 500, 1, function() clearDebounce() end)
  end
end

setupWIFI()
