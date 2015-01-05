aplist = {}

function do_scan(tries)
  if tries == 0 then
    print("Too many failed scans, reboot node.")
    node.restart()
  end

  aplist = {}

  print("Doing scan.")

  wifi.sta.getap(function (t)
    if t == nil then
      print("nil AP list, heap is: "..node.heap())
      tmr.stop(1)
      tmr.alarm(1, 3000, 0,
        function () do_scan(tries - 1) end)
      return nil
    end

    local k, v

    for k, v in pairs(t) do
      print(k.." : "..v)
      if string.sub(v,1,1) == "0" then
        print("Network "..k.." is open.")
        aplist = t
        tmr.alarm(1, 100, 0,
          function () connect_open_net(k) end)
        return nil
      end
    end
  end)

end

function connect_open_net(ssid)
  print("Trying to connect to open network "..ssid)
  wifi.sta.config(ssid, "")
  wifi.sta.connect()
  tmr.alarm(1, 250, 0, function  () send_data(10) end)
  return nil
end

function send_data(tries)
  scanid = tmr.now()
  while wifi.sta.getip() == nil and tries >= 1 do
    print("try "..tries..": no address")
    tmr.alarm(1, 300, 0, function () send_data(tries - 1) end)
    return nil
  end

  if wifi.sta.getip() == nil then
    print("Failed to get IP, return to scan state.")
    tmr.alarm(1, 1500, 0, function () do_scan(3) end)
    return nil
  end

  print("I can has IPv4: "..wifi.sta.getip())

  local k, v

  for k, v in pairs(aplist) do
    local enc, rssi, bssid, chan = string.match(v,
      "(%d),(-?%d+),([%x:]+),(%d+)")
    local dnsq = rssi.."."..bssid.gsub(bssid, ":", "") ..
      "."..scanid.."."..node.chipid()..".loc.sigint.cc"
    net.createConnection(net.UDP, false):dns(dnsq,
      function (s, i)
        print("Sent "..dnsq.." for "..bssid)
      end)
  end

  print("Resuming with scan in 10s.")
  tmr.alarm(1, 10000, function () do_scan(3) end)
  return nil
end

do_scan(3)
