-- Plugin Version
local VERSION = "2.41"

-- Flags
local DEBUG_MODE = true
local INITIALIZED = false
local EVENTSTRING
local HEARTBEAT

--Conversions
local DAYS = {'Sun','Mon','Tue','Wed','Thu','Fri','Sat'}
local MONTHS = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'}

-- Constants
local ELK_SID   = "urn:micasaverde-com:serviceId:ElkAlarmPanel1"
local PART_SID  = "urn:micasaverde-com:serviceId:AlarmPartition2"
local SES_SID   = "urn:micasaverde-com:serviceId:SecuritySensor1"
local TEMP_SID  = "urn:upnp-org:serviceId:TemperatureSensor1"
local HVACO_SID = "urn:upnp-org:serviceId:HVAC_UserOperatingMode1"
local HVACF_SID  = "urn:upnp-org:serviceId:HVAC_FanOperatingMode1"
local HVACHEAT_SID = "urn:upnp-org:serviceId:TemperatureSetpoint1_Heat"
local HVACCOOL_SID = "urn:upnp-org:serviceId:TemperatureSetpoint1_Cool"
local HADEVICE_SID = "urn:micasaverde-com:serviceId:HaDevice1"
local HAD_COMM_FAILURE = "CommFailure"
local SWP_SID = "urn:upnp-org:serviceId:SwitchPower1"


local TASK_ERROR      = 2
local TASK_ERROR_PERM = -2
local TASK_SUCCESS    = 4
local TASK_BUSY       = 1
local MAX_RETRIES = 2
local MAX_READS = 3

-- Polling
local POLL_MIN_DELAY = 60 --"PollMinDelay"
local POLL_FREQUENCY = 30 --"PollFrequency"

-- Globals
local elk_device = nil
local g_taskHandle = -1
local g_errorMessage = nil
local g_nextThermostat = nil

local g_partitions  = {}
local g_zones       = {}
local g_users       = {}
local g_tempSensors = {}
local g_thermostats = {}
local g_outputs     = {}
local g_tasks       = {}
local g_keypads     = {}
local g_counters    = {}
local g_lights      = {}
local g_fnctkeys    = {}
local g_customs     = {}
local g_logFile     = {}
local g_pinCodes    = {}

local ZONE_DEVICE = {
  ['0'] = {},
  ['1'] = {type = "urn:schemas-micasaverde-com:device:DoorSensor:1", file = "D_DoorSensor1.xml", id = "elk_zone_"},
  ['2'] = {type = "urn:schemas-micasaverde-com:device:MotionSensor:1", file = "D_MotionSensor1.xml", id = "elk_zone_"},
  ['3'] = {type = "urn:schemas-micasaverde-com:device:SmokeSensor:1", file = "D_SmokeSensor1.xml", id = "elk_zone_"},
  ['4'] = {type = "urn:schemas-micasaverde-com:device:TemperatureSensor:1", file = "D_TemperatureSensor1.xml", id = "elk_temp_"},
  ['5'] = {type = "urn:schemas-micasaverde-com:device:TempLeakSensor:1", file = "D_TempLeakSensor1.xml", id = "elk_leak_"},
  ['6'] = {type = "urn:schemas-micasaverde-com:device:Scene:1", file = "D_Scene1.xml", id = "elk_fob_"}
}
-------------------------------------------------------------------------------
-- Panel Related Constants
-------------------------------------------------------------------------------
local CHIME_MODES = {
  ['0'] = "Off",
  ['1'] = "Chime only",
  ['2'] = "Voice only",
  ['3'] = "Chime and voice"
}

local ARM_UP_STATES = {
  ['0'] = "NotReady",
  ['1'] = "Ready",
  ['2'] = "ReadyForceArm",
  ['3'] = "ArmedWithExitTimer",
  ['4'] = "ArmedFully",
  ['5'] = "ForceArmed",
  ['6'] = "ArmedWithBypass"
}

local TROUBLES = {
  [1] = "AC Fail Trouble",
  [2] = "Box Tamper Trouble",
  [3] = "Fail To Communicate Trouble",
  [4] = "EProm Memory Error Trouble",
  [5] = "Low Battery Control Trouble",
  [6] = "Transmitter Low Battery Trouble",
  [7] = "Over Current Trouble",
  [8] = "Telephone Fault Trouble",
  [10] = "Output 2 Trouble",
  [11] = "Missing Keypad Trouble",
  [12] = "Zone Expander Trouble",
  [13] = "Output Expander Trouble",
  [15] = "ELKRP Remote Access Trouble",
  [17] = "Common Area Not Armed Trouble",
  [18] = "Flash Memory Error Trouble",
  [19] = "Security Alert Trouble",
  [20] = "Serial Port Expander Trouble",
  [21] = "Lost Transmitter Trouble",
  [22] = "GE Smoke CleanMe Trouble",
  [23] = "Ethernet Trouble",
  [32] = "Display Message In Keypad Line 1 Trouble",
  [33] = "Display Message In Keypad Line 2 Trouble",
  [34] = "Fire Trouble"
}

local ARMING_STATUSES = {
  ['0'] = "Disarmed",
  ['1'] = "Armed",
  ['2'] = "Stay",
  ['3'] = "StayInstant",
  ['4'] = "Night",
  ['5'] = "NightInstant",
  ['6'] = "Vacation"
}

local ALARM_STATES = {
  ['0'] = "No Alarm Active",
  ['1'] = "Entrance Delay is Active",
  ['2'] = "Alarm Abort Delay Active",
  ['3'] = "FireAlarm",
  ['4'] = "MedicalAlarm",
  ['5'] = "PoliceAlarm",
  ['6'] = "BurglarAlarm",
  ['7'] = "Aux1Alarm",
  ['8'] = "Aux2Alarm",
  ['9'] = "Aux3Alarm",  --not used
  [':'] = "Aux4Alarm",  --not used
  [';'] = "CarbonMonoxideAlarm",
  ['<'] = "EmergencyAlarm",
  ['='] = "FreezeAlarm",
  ['>'] = "GasAlarm",
  ['?'] = "HeatAlarm",
  ['@'] = "WaterAlarm",
  ['A'] = "FireSupervisory",
  ['B'] = "VerifyFire",
}

local ZONE_DEFINITIONS = {
  ['0'] = {discription = "Disabled", deviceType = '0'},
  ['1'] = {discription = "Burglar Entry/Exit 1", deviceType = '1'},
  ['2'] = {discription = "Burglar Entry/Exit 2", deviceType = '1'},
  ['3'] = {discription = "Burglar Perimeter Instant", deviceType = '1'},
  ['4'] = {discription = "Burglar Interior", deviceType = '2'},
  ['5'] = {discription = "Burglar Interior Follower", deviceType = '2'},
  ['6'] = {discription = "Burglar Interior Night", deviceType = '2'},
  ['7'] = {discription = "Burglar Interior Night Delay", deviceType = '2'},
  ['8'] = {discription = "Burglar 24 Hour", deviceType = '2'},
  ['9'] = {discription = "Burglar Box Tamper", deviceType = '2'},
  [':'] = {discription = "Fire Alarm", deviceType = '3'},
  [';'] = {discription = "Fire Verified", deviceType = '3'},
  ['<'] = {discription = "Fire Supervisory", deviceType = '3'},
  ['='] = {discription = "Aux Alarm 1", deviceType = '2'},
  ['>'] = {discription = "Aux Alarm 2", deviceType = '2'},
  ['?'] = {discription = "Keyfob", deviceType = '6'},
  ['@'] = {discription = "Non Alarm", deviceType = '2'},
  ['A'] = {discription = "Carbon Monoxide", deviceType = '5'},
  ['B'] = {discription = "Emergency Alarm", deviceType = '2'},
  ['C'] = {discription = "Freeze Alarm", deviceType = '5'},
  ['D'] = {discription = "Gas Alarm", deviceType = '5'},
  ['E'] = {discription = "Heat Alarm", deviceType = '5'},
  ['F'] = {discription = "Medical Alarm", deviceType = '2'},
  ['G'] = {discription = "Police Alarm", deviceType = '2'},
  ['H'] = {discription = "Police No Indication", deviceType = '2'},
  ['I'] = {discription = "Water Alarm", deviceType = '5'},
  ['J'] = {discription = "Key Momentary Arm / Disarm", deviceType = '2'},
  ['K'] = {discription = "Key Momentary Arm Away", deviceType = '2'},
  ['L'] = {discription = "Key Momentary Arm Stay", deviceType = '2'},
  ['M'] = {discription = "Key Momentary Disarm", deviceType = '2'},
  ['N'] = {discription = "Key On/Off", deviceType = '2'},
  ['O'] = {discription = "Mute Audibles", deviceType = '2'},
  ['P'] = {discription = "Power Supervisory", deviceType = '2'},
  ['Q'] = {discription = "Temperature", deviceType = '4'},
  ['R'] = {discription = "Analog Zone", deviceType = '0'},
  ['S'] = {discription = "Phone Key", deviceType = '0'},
  ['T'] = {discription = "Intercom Key", deviceType = '0'}
}

local ZONE_STATUSES = {
  ['0'] = "Normal", -- "Unconfigured"
  ['1'] = "Normal", -- "Open"
  ['2'] = "Normal", -- "EOL"
  ['3'] = "Normal", -- "Short"
  ['4'] = "N/A",
  ['5'] = "Trouble", -- "Open"
  ['6'] = "Trouble", -- "EOL"
  ['7'] = "Trouble", -- "Short"
  ['8'] = "N/A",
  ['9'] = "Violated", -- "Open"
  ['A'] = "Violated", -- "EOL"
  ['B'] = "Violated", -- "Short"
  ['C'] = "Bypassed",
  ['D'] = "Bypassed", -- "Open"
  ['E'] = "Bypassed", -- "EOL"
  ['F'] = "Bypassed"  -- "Short"
}

local LABEL_TYPES = {
  ["00"] = "Zone Name",
  ["01"] = "Area Name",
  ["02"] = "User Name",
  ["03"] = "Keypad Name",
  ["04"] = "Output Name",
  ["05"] = "Task Name",
  ["06"] = "Telephone Name",
  ["07"] = "Light Name",
  ["08"] = "Alarm Duration Name",
  ["09"] = "Custom Settings",
  ["10"] = "Counter Names",
  ["11"] = "Thermostat Names",
  ["12"] = "Function Key 1 Name",
  ["13"] = "Function Key 2 Name",
  ["14"] = "Function Key 3 Name",
  ["15"] = "Function Key 4 Name",
  ["16"] = "Function Key 5 Name",
  ["17"] = "Function Key 6 Name",
  ["18"] = "Audio Zone Name",
  ["19"] = "Audio Source Name"
}

local TSTAT_MODES = {
  ['0'] = "Off",
  ['1'] = "HeatOn",
  ['2'] = "CoolOn",
  ['3'] = "AutoChangeOver",
  ['4'] = "HeatOn"
}

local PLC_MODES = {
  ['01'] = 'X10_ALL_UNITS_OFF',  --in a House code
  ['02'] = 'X10_ALL_LIGHTS_ON',  --in a House code
  ['03'] = 'X10_UNIT_ON',
  ['04'] = 'X10_UNIT_OFF',
  ['05'] = 'X10_DIM',            --EE extended value holds number of dims
  ['06'] = 'X10_BRIGHT',         --EE extended value holds number of brights
  ['07'] = 'X10_ALL_LIGHTS_OFF', --in a House code
  ['08'] = 'X10_EXTENDED_CODE',
  ['09'] = 'X10_PRESET_DIM',     --EE extended value hold level 0 to 99%
  ['10'] = 'X10_EXTENDED_DATA',
  ['11'] = 'X10_STATUS_REQ',
  ['12'] = 'X10_HAIL_REQUEST',
  ['13'] = 'X10_HAIL_ACK',       --not used
  ['14'] = 'X10_STATUS_ON',      --not used
  ['15'] = 'X10_STATUS_OFF',     --not used
}

local DEVICETYPE_LIGHT = "urn:schemas-upnp-org:device:BinaryLight:1"
local DEVICEFILE_LIGHT = "D_BinaryLight1.xml"
----------------------------------------------------------------------------------------------------------------
-- Generic Utilities
----------------------------------------------------------------------------------------------------------------

--local log = luup.log

local function log (text,level)
  luup.log("ElkPlugin::" .. text,level or 50)
end

local function debug (text,level)
  if (DEBUG_MODE == true) then
    log(text,level or 2)
  end
end



function task (text, mode)
  log("task: ".. text)
  if (mode == TASK_ERROR_PERM) then
    luup.task(text, TASK_ERROR, "Elk Alarm Panel", g_taskHandle)
  else
    luup.task(text, mode, "Elk Alarm Panel", g_taskHandle)

    -- Clear the previous error, since they're all transient
    if (mode ~= TASK_SUCCESS) then
      luup.call_delay("clearStatusMessage", 30)
    end
  end
end

function clearStatusMessage()
  luup.task("Clearing...", TASK_SUCCESS, "ElkPlugin", g_taskHandle)
  return true
end

local function calculateChecksum (s)
  local total = 0
  for i = 1, #s do
    total = total + string.byte (s, i)
  end

  local checksum = 256 - (total % 256)
  if (checksum == 256) then
    checksum = 0
  end

  return checksum
end

function table.contains (t, item)
  for _, v in pairs(t) do
    if (v == item) then
      return true
    end
  end

  return false
end

function trim(s) 
    return (s:gsub("^%s*(.-)%s*$", "%1")) 
end

local function padLeft (s, length, char)
  s = tostring(s)
  length = length or 2
  char = char or '0'
  return char:rep (length - #s) .. s
end

local function padRight (s, length, char)
  s = tostring(s)
  length = length or 2
  char = char or '0'
  return s .. char:rep (length - #s)
end

local function setZoneState (zoneNo, variable, value)
  local device = g_zones[zoneNo].devId
  debug("setZoneState: Set variable '".. variable .."' = '".. value .."' for zone ".. zoneNo .." (device ".. device ..").")
  luup.variable_set(SES_SID, variable, value, device)
  if(variable == "Tripped" and value == "1") then
    luup.variable_set(SES_SID, "LastTrip", tostring(os.time()), device)
  end
end

local function getPartitionState (partNo, variable)
  local v = luup.variable_get(PART_SID, variable, g_partitions[partNo].devId) or ""
  debug("getPartitionState: Partition ".. partNo .." (device ".. g_partitions[partNo].devId .."), got variable '".. variable .."' = '".. v .."'.")
  if (v == "") then
    return nil
  end
  return v
end

local function setPartitionState (partNo, variable, value)
  debug("setPartitionState: Set variable '".. variable .."' = '".. (value or "no value") .."' for partition ".. (partNo or "no value") .." (device ".. (g_partitions[partNo].devId or "no value") ..").")
  luup.variable_set(PART_SID, variable, value, g_partitions[partNo].devId)
end

local function checkMessage (msg)
  if (not msg or msg == "") then
    log("checkMessage: ERROR: Empty message.")
    return nil
  end

  local length, msgType, data, misc, checksum = msg:match("^(%x%x)(%a%w)(.*)(%x%x)(%x%x)$")
  if ((length == nil) or (msgType == nil) or (checksum == nil)) then
    debug("checkMessage: Received message: " .. msg)
    log("checkMessage: ERROR: The received message has invalid format.")
    return nil
  end

  debug(string.format("checkMessage: length=%d(0x%s), message type=%s, data='%s', misc=%s, checksum=%s", tonumber(length, 16) or 0, length, msgType, tostring(data), misc, checksum))

  -- There is a bug in the version 5.1.20: the reported length for EE, which is 0F is incorrect.
  -- The correct length is 0E. This affects the checksum, so we bypass this message.
  if (msgType == "EE") then
    return "EE"
  end

  data = data or ""

  local calculatedLength = #msgType + #data + #misc + #checksum
  if (calculatedLength ~= tonumber(length, 16)) then
    log("checkMessage: ERROR: The received message length is incorrect.")
    return nil
  end

  local calculatedChecksum = calculateChecksum(length .. msgType .. data .. misc)
  if (calculatedChecksum ~= tonumber(checksum, 16)) then
    log("checkMessage: ERROR: The calculated checksum is incorrect.")
    debug("checkMessage: Calculated Check Sum:" .. calculatedChecksum ..".",1)
    return nil
  end

  return msgType, data
end

function commandRetry(func)
  local retry = 1
  while retry <= 3 do
    if (retry > 1) then
      debug(string.format("commandRetry: command sent %i times",retry))
      luup.sleep(400*(retry*2))
    end
    local status, data = func()
    if (status) then
      return status, data
    end
    retry = retry+1
  end
  debug("commandRetry: command failed")
  return false
end
----------------------------------------------------------------------------------------------------------------
-- Message Processing: Function Implementations
----------------------------------------------------------------------------------------------------------------

local function processArmingStatusReport (data)
  S = {} -- Arming statuses
  U = {} -- Arm up states
  A = {} -- Alarm states

  for i = 1, 8 do
    table.insert (S, data:sub(i, i))
  end
  for i = 9, 16 do
    table.insert (U, data:sub(i, i))
  end
  for i = 17, 24 do
    table.insert (A, data:sub(i, i))
  end

  for i in pairs(g_partitions) do
    g_partitions[i].armingStatus = ARMING_STATUSES[S[i]]
    g_partitions[i].armUpState = U[i]
    g_partitions[i].alarmState = A[i]

    if (A[i] >= '3') then -- We have an alarm.
      local message = string.format("ALARM: %s, %s", ALARM_STATES[A[i]], g_partitions[i].label or "")
      log(message)
      task(message, TASK_ERROR_PERM)

      setPartitionState (i, "Alarm", "Active")
      setPartitionState (i, "AlarmMemory", "1")
      setPartitionState (i, "LastAlarmActive", os.date())
    else
      if (getPartitionState (i, "AlarmMemory") == "1") then -- There was an alarm, but it has been deactivated.
        setPartitionState (i, "Alarm", "None")
        setPartitionState (i, "AlarmMemory", "0")
        clearStatusMessage()
      end
    end
  end

  for k, v in pairs(g_partitions) do
    local message = string.format("armingStatus=%s, armUpState=%s, alarmState=%s", v.armingStatus, v.armUpState, v.alarmState)
    debug("processArmingStatusReport: partition " .. tostring(k) .. ", " .. message)
    if (not v.armingStatus) then
      -- We don't have this partition's status. Consider it Disarmed and NotReady just to be safe.
      setPartitionState (k, "ArmMode", "Disarmed")
      setPartitionState (k, "DetailedArmMode", "NotReady")
    elseif (v.armingStatus ~= "Disarmed") then
      -- The partition is in one of the armed states.
      setPartitionState (k, "ArmMode", "Armed")
      setPartitionState (k, "DetailedArmMode", v.armingStatus)
    else
      -- The partition is disarmed.
      setPartitionState (k, "ArmMode", "Disarmed")
      if (v.armUpState == '0') then
        setPartitionState (k, "DetailedArmMode", "NotReady")
      elseif (v.armUpState <= '2') then
        setPartitionState (k, "DetailedArmMode", "Ready")
      else
        log("processArmingStatusReport: Impossible combination of 'armingStatus' and 'armUpState'.")
      end
    end
  end
end

local function processOutputReport (data)
  local outputNo, state = data:match("^(%d%d%d)(%d)")
  debug("processOutputReport: Output ".. outputNo .." is ".. (state == "1" and "On" or "Off") ..".")
  outputNo = tonumber(outputNo, 10)
  if(g_outputs[outputNo] ~= nil) then
    luup.variable_set(SWP_SID, "Status", state, g_outputs[outputNo].devId)
  end
end

local function updateTemperatureSensors ()
  -- Update the temperatures if the devices exist.
    for tempSensor, attr in pairs(g_tempSensors) do
    luup.variable_set(TEMP_SID, "CurrentTemperature", attr.temp, attr.devId)
    end
end

local function updateTemperature (data)

  local group, device, temp = data:match("^(%d)(%d%d)(%d%d%d)")

  if (group == "0") then  --Temperature probe
    temp = tonumber(temp, 10) - 60
    debug("updateTemperature: Temperature probe ".. device .." new temperature = ".. temp ..".")
    device = tonumber(device, 10) + 16
    if(g_tempSensors[device] 	~= nil) then
      luup.variable_set(TEMP_SID, "CurrentTemperature", tostring(temp), g_tempSensors[device].devId)
    end

  elseif (group == "1") then  --Keypad
    temp = tonumber(temp, 10) - 40
    debug("updateTemperature: Keypad ".. device .." new temperature = ".. temp ..".")
    device = tonumber(device, 10)
    if(g_tempSensors[device] ~= nil) then
      luup.variable_set(TEMP_SID, "CurrentTemperature", tostring(temp), g_tempSensors[device].devId)
    end

  elseif (group == "2") then  --Thermostat
    temp = tonumber(temp, 10)
    debug("updateTemperature: Thermostat ".. device .." new temperature = ".. temp ..".")
    device = tonumber(device, 10)
    luup.variable_set(TEMP_SID, "CurrentTemperature", tostring(temp), g_thermostats[device].devId)
  end
end

local function updateThermostat (data)

  local tnum, mode, fan, temp, hsp, csp = data:match("^(%d%d)(%d)%d(%d)(%d%d)(%d%d)(%d%d)")
  debug("updateThermostat: Update thermostat ".. tnum ..".")

  if (tnum ~= "00") then
    tnum = tonumber(tnum, 10)
    local devId = g_thermostats[tnum].devId
    if (devId == nil) then
      log("updateThermostat: ERROR: No device for thermostat ".. tnum ..".")
      return
    end

    mode = TSTAT_MODES[mode] or "nil"
    fan = (fan == "0") and "Auto" or "ContinuousOn"

    debug("updateThermostat: New values: temperature = ".. temp ..", mode status = ".. mode ..", fan mode = ".. fan ..", heat setpoint = ".. hsp ..", cool setpoint = ".. csp ..".")

    luup.variable_set(TEMP_SID,  "CurrentTemperature", temp, devId)
    luup.variable_set(HVACO_SID, "ModeStatus", mode, devId)
    luup.variable_set(HVACF_SID, "Mode", fan, devId)
    luup.variable_set(HVACHEAT_SID, "CurrentSetpoint", hsp, devId)
    luup.variable_set(HVACCOOL_SID, "CurrentSetpoint", csp, devId)
    luup.variable_set(HADEVICE_SID, "LastUpdate", tostring(os.time()), devId)
  end
end

local function processZoneChangeUpdate (data)
  local zoneNo, status = data:match("^(%d%d%d)(%x)$")
  zoneNo = tonumber(zoneNo, 10)
  local zs = ZONE_STATUSES[status]
  debug("processZoneChangeUpdate: Zone #"..zoneNo..", status = "..zs..".")
  if (zs == "Normal") then
    setZoneState(zoneNo, "Armed", "1")
    setZoneState(zoneNo, "Tripped", "0")
  elseif (zs == "Violated" or zs == "Trouble") then
    setZoneState(zoneNo, "Tripped", "1")
  elseif (zs == "Bypassed") then
    setZoneState(zoneNo, "Armed", "0")
  else -- Invalid state.
    setZoneState(zoneNo, "Armed", "0")
    setZoneState(zoneNo, "Tripped", "0")
  end
end

local function processZonePartitionReport (data)
  for i in pairs(g_zones) do
    local c = data:sub(i, i)
    if (c ~= '0') then
      p = tonumber(c)
      g_zones[i].partition = p;
      if (not g_partitions[p]) then
        g_partitions[p] = {}
        g_partitions[p].zones = {i}
        g_partitions[p].label = "Area " .. p
      else
        table.insert (g_partitions[p].zones, i)
      end
    else
      g_zones[i].partition = 1;
    end
  end
end

local function processZoneStatusReport (data)
  for i in pairs(g_zones) do
    local status = data:sub(i, i)
    debug("processZoneStatusReport: Zone ".. i .." status = ".. ZONE_STATUSES[c] ..".")
    if (ZONE_STATUSES[status] == "Normal") then
      setZoneState(i, "Armed", "1")
      setZoneState(i, "Tripped", "0")
    elseif (ZONE_STATUSES[status] == "Violated") then
      setZoneState(i, "Tripped", "1")
    elseif (ZONE_STATUSES[status] == "Bypassed") then
      setZoneState(i, "Armed", "0")
    else -- It's either in Trouble or in an invalid state.
      setZoneState(i, "Armed", "0")
      setZoneState(i, "Tripped", "0")
    end
  end
end

local function processTaskReport (data)
  local taskNo = tonumber(data:sub(1, 3),10)
  if (g_tasks[taskNo] ~=nil) then
    local taskDevNo = g_tasks[taskNo].dev
    luup.variable_set(SWP_SID, "Status", "1",  taskDevNo)
    luup.variable_set(HADEVICE_SID, "LastUpdate", tostring(os.time()), taskDevNo)
    debug("processTaskReport: Task ".. taskNo .." activated on " .. os.date() .. ".")
    luup.variable_set(SWP_SID, "Status", "0",  taskDevNo)
  else
    debug("processTaskReport: No device on Vera to present Task.")
  end
end

local function processFunctionKey (data)
  local chimeStatus = data:sub(4,4)
  local keypad = tonumber(data:sub(1,2))
  local functionKey = data:sub(3,3)
  debug("processFunctionKey:keypad number:" .. keypad .. " key:" .. functionKey .. ".")
  for i in pairs(g_partitions) do
    debug("processFunctionKey:chimeStatus " .. chimeStatus .. ".")
    local chimeEnabled = (chimeStatus == "0") and "0" or "1"
    setPartitionState (i, "ChimeEnabled", chimeEnabled)
  end
  return true
end

local function processKeypadKeyChangeUpdate (data)
  local chime = data:sub(12,19) -- Chime information.
  local keypad = tonumber(data:sub(1,2))
  local keynumber = data:sub(3,4)
  local ilumstatus = data:sub(5,10)
  local bypass = data:sub(10,10)
  for i in pairs(g_partitions) do
    local chimeEnabled = (chime:sub(i,i) == "0") and "0" or "1"
    setPartitionState (i, "ChimeEnabled", chimeEnabled)
  end
  return true
end
----------------------------------------------------------------------------------------------------------------
-- Reports
----------------------------------------------------------------------------------------------------------------
local function processSystemTroubleStatus (data)
  local data={data:byte(1,#data)}
  local troubleList={}
  for i = 1, #data do
    if (data[i] >= 49) then
      local message = (TROUBLES[i] or "N/A")
      if ((i == 2) or (i == 6) or (i == 19) or (i == 21) or (i == 34)) then
        message = message .. string.format(", Zone #%d", data[i] - 48)
      end
      log("TROUBLE: " .. message)
      task(message, TASK_ERROR_PERM)
      table.insert(troubleList, message)
    end
  end
  luup.variable_set(ELK_SID, "TroubleReport",(table.concat(troubleList,",")), elk_device)
end

function get_event_string(event)
    local EVENTS = {
    ['1000'] = 	{'No Event', '0'},
    ['1001'] = 	{'FIRE ALARM', '1'},
    ['1002'] = 	{'FIRE SUPERVISORY ALARM', '1'},
    ['1003'] = 	{'BURGLAR ALARM, ANY AREA', '1'},
    ['1004'] = 	{'MEDICAL ALARM, ANY AREA', '1'},
    ['1005'] = 	{'POLICE ALARM, ANY AREA', '1'},
    ['1006'] = 	{'AUX1 24 HR, ANY AREA', '1'},
    ['1007'] = 	{'AUX2 24 HR, ANY AREA', '1'},
    ['1008'] = 	{'CARBON MONOXIDE ALARM, ANY AREA', '1'},
    ['1009'] = 	{'EMERGENCY ALARM, ANY AREA', '1'},
    ['1010'] = 	{'FREEZE ALARM, ANY AREA', '1'},
    ['1011'] = 	{'GAS ALARM, ANY AREA', '1'},
    ['1012'] = 	{'HEAT ALARM, ANY AREA', '1'},
    ['1013'] = 	{'WATER ALARM, ANY AREA', '1'},
    ['1014'] = 	{'ALARM, ANY AREA', '1'},
    ['1015'] = 	{'BURGLAR ALARM IN AREA 1', '1'},
    ['1016'] = 	{'BURGLAR ALARM IN AREA 2', '1'},
    ['1017'] = 	{'BURGLAR ALARM IN AREA 3', '1'},
    ['1018'] = 	{'BURGLAR ALARM IN AREA 4', '1'},
    ['1019'] = 	{'BURGLAR ALARM IN AREA 5', '1'},
    ['1020'] = 	{'BURGLAR ALARM IN AREA 6', '1'},
    ['1021'] = 	{'BURGLAR ALARM IN AREA 7', '1'},
    ['1022'] = 	{'BURGLAR ALARM IN AREA 8', '1'},
    ['1023'] = 	{'MEDICAL ALARM IN AREA 1', '1'},
    ['1024'] = 	{'MEDICAL ALARM IN AREA 2', '1'},
    ['1025'] = 	{'MEDICAL ALARM IN AREA 3', '1'},
    ['1026'] = 	{'MEDICAL ALARM IN AREA 4', '1'},
    ['1027'] = 	{'MEDICAL ALARM IN AREA 5', '1'},
    ['1028'] = 	{'MEDICAL ALARM IN AREA 6', '1'},
    ['1029'] = 	{'MEDICAL ALARM IN AREA 7', '1'},
    ['1030'] = 	{'MEDICAL ALARM IN AREA 8', '1'},
    ['1031'] = 	{'POLICE ALARM IN AREA 1', '1'},
    ['1032'] = 	{'POLICE ALARM IN AREA 2', '1'},
    ['1033'] = 	{'POLICE ALARM IN AREA 3', '1'},
    ['1034'] = 	{'POLICE ALARM IN AREA 4', '1'},
    ['1035'] = 	{'POLICE ALARM IN AREA 5', '1'},
    ['1036'] = 	{'POLICE ALARM IN AREA 6', '1'},
    ['1037'] = 	{'POLICE ALARM IN AREA 7', '1'},
    ['1038'] = 	{'POLICE ALARM IN AREA 8', '1'},
    ['1039'] = 	{'AUX1 24 HR IN AREA 1', '1'},
    ['1040'] = 	{'AUX1 24 HR IN AREA 2', '1'},
    ['1041'] = 	{'AUX1 24 HR IN AREA 3', '1'},
    ['1042'] = 	{'AUX1 24 HR IN AREA 4', '1'},
    ['1043'] = 	{'AUX1 24 HR IN AREA 5', '1'},
    ['1044'] = 	{'AUX1 24 HR IN AREA 6', '1'},
    ['1045'] = 	{'AUX1 24 HR IN AREA 7', '1'},
    ['1046'] = 	{'AUX1 24 HR IN AREA 8', '1'},
    ['1047'] = 	{'AUX2 24 HR IN AREA 1', '1'},
    ['1048'] = 	{'AUX2 24 HR IN AREA 2', '1'},
    ['1049'] = 	{'AUX2 24 HR IN AREA 3', '1'},
    ['1050'] = 	{'AUX2 24 HR IN AREA 4', '1'},
    ['1051'] = 	{'AUX2 24 HR IN AREA 5', '1'},
    ['1052'] = 	{'AUX2 24 HR IN AREA 6', '1'},
    ['1053'] = 	{'AUX2 24 HR IN AREA 7', '1'},
    ['1054'] = 	{'AUX2 24 HR IN AREA 8', '1'},
    ['1055'] = 	{'CO ALARM IN AREA 1', '1'},
    ['1056'] = 	{'CO ALARM IN AREA 2', '1'},
    ['1057'] = 	{'CO ALARM IN AREA 3', '1'},
    ['1058'] = 	{'CO ALARM IN AREA 4', '1'},
    ['1059'] = 	{'CO ALARM IN AREA 5', '1'},
    ['1060'] = 	{'CO ALARM IN AREA 6', '1'},
    ['1061'] = 	{'CO ALARM IN AREA 7', '1'},
    ['1062'] = 	{'CO ALARM IN AREA 8', '1'},
    ['1063'] = 	{'EMERGENCY ALARM IN AREA 1', '1'},
    ['1064'] = 	{'EMERGENCY ALARM IN AREA 2', '1'},
    ['1065'] = 	{'EMERGENCY ALARM IN AREA 3', '1'},
    ['1066'] = 	{'EMERGENCY ALARM IN AREA 4', '1'},
    ['1067'] = 	{'EMERGENCY ALARM IN AREA 5', '1'},
    ['1068'] = 	{'EMERGENCY ALARM IN AREA 6', '1'},
    ['1069'] = 	{'EMERGENCY ALARM IN AREA 7', '1'},
    ['1070'] = 	{'EMERGENCY ALARM IN AREA 8', '1'},
    ['1071'] = 	{'FREEZE ALARM IN AREA 1', '1'},
    ['1072'] = 	{'FREEZE ALARM IN AREA 2', '1'},
    ['1073'] = 	{'FREEZE ALARM IN AREA 3', '1'},
    ['1074'] = 	{'FREEZE ALARM IN AREA 4', '1'},
    ['1075'] = 	{'FREEZE ALARM IN AREA 5', '1'},
    ['1076'] = 	{'FREEZE ALARM IN AREA 6', '1'},
    ['1077'] = 	{'FREEZE ALARM IN AREA 7', '1'},
    ['1078'] = 	{'FREEZE ALARM IN AREA 8', '1'},
    ['1079'] = 	{'GAS ALARM IN AREA 1', '1'},
    ['1080'] = 	{'GAS ALARM IN AREA 2', '1'},
    ['1081'] = 	{'GAS ALARM IN AREA 3', '1'},
    ['1082'] = 	{'GAS ALARM IN AREA 4', '1'},
    ['1083'] = 	{'GAS ALARM IN AREA 5', '1'},
    ['1084'] = 	{'GAS ALARM IN AREA 6', '1'},
    ['1085'] = 	{'GAS ALARM IN AREA 7', '1'},
    ['1086'] = 	{'GAS ALARM IN AREA 8', '1'},
    ['1087'] = 	{'HEAT ALARM IN AREA 1', '1'},
    ['1088'] = 	{'HEAT ALARM IN AREA 2', '1'},
    ['1089'] = 	{'HEAT ALARM IN AREA 3', '1'},
    ['1090'] = 	{'HEAT ALARM IN AREA 4', '1'},
    ['1091'] = 	{'HEAT ALARM IN AREA 5', '1'},
    ['1092'] = 	{'HEAT ALARM IN AREA 6', '1'},
    ['1093'] = 	{'HEAT ALARM IN AREA 7', '1'},
    ['1094'] = 	{'HEAT ALARM IN AREA 8', '1'},
    ['1095'] = 	{'WATER ALARM IN AREA 1', '1'},
    ['1096'] = 	{'WATER ALARM IN AREA 2', '1'},
    ['1097'] = 	{'WATER ALARM IN AREA 3', '1'},
    ['1098'] = 	{'WATER ALARM IN AREA 4', '1'},
    ['1099'] = 	{'WATER ALARM IN AREA 5', '1'},
    ['1100'] = 	{'WATER ALARM IN AREA 6', '1'},
    ['1101'] = 	{'WATER ALARM IN AREA 7', '1'},
    ['1102'] = 	{'WATER ALARM IN AREA 8', '1'},
    ['1103'] = 	{'ANY ALARM IN AREA 1', '1'},
    ['1104'] = 	{'ANY ALARM IN AREA 2', '1'},
    ['1105'] = 	{'ANY ALARM IN AREA 3', '1'},
    ['1106'] = 	{'ANY ALARM IN AREA 4', '1'},
    ['1107'] = 	{'ANY ALARM IN AREA 5', '1'},
    ['1108'] = 	{'ANY ALARM IN AREA 6', '1'},
    ['1109'] = 	{'ANY ALARM IN AREA 7', '1'},
    ['1110'] = 	{'ANY ALARM IN AREA 8', '1'},
    ['1111'] = 	{'CODE LOCKOUT, ANY KEYPAD', '0'},
    ['1112'] = 	{'KEYPAD 01 CODE-LOCKOUT', '0'},
    ['1113'] = 	{'KEYPAD 02 CODE-LOCKOUT', '0'},
    ['1114'] = 	{'KEYPAD 03 CODE-LOCKOUT', '0'},
    ['1115'] = 	{'KEYPAD 04 CODE-LOCKOUT', '0'},
    ['1116'] = 	{'KEYPAD 05 CODE-LOCKOUT', '0'},
    ['1117'] = 	{'KEYPAD 06 CODE-LOCKOUT', '0'},
    ['1118'] = 	{'KEYPAD 07 CODE-LOCKOUT', '0'},
    ['1119'] = 	{'KEYPAD 08 CODE-LOCKOUT', '0'},
    ['1120'] = 	{'KEYPAD 09 CODE-LOCKOUT', '0'},
    ['1121'] = 	{'KEYPAD 10 CODE-LOCKOUT', '0'},
    ['1122'] = 	{'KEYPAD 11 CODE-LOCKOUT', '0'},
    ['1123'] = 	{'KEYPAD 12 CODE-LOCKOUT', '0'},
    ['1124'] = 	{'KEYPAD 13 CODE-LOCKOUT', '0'},
    ['1125'] = 	{'KEYPAD 14 CODE-LOCKOUT', '0'},
    ['1126'] = 	{'KEYPAD 15 CODE-LOCKOUT', '0'},
    ['1127'] = 	{'KEYPAD 16 CODE-LOCKOUT', '0'},
    ['1128'] = 	{'FIRE TROUBLE, ANY ZONE', '1'},
    ['1129'] = 	{'BURGLAR TROUBLE, ANY ZONE', '1'},
    ['1130'] = 	{'FAIL TO COMMUNICATE TROUBLE', '0'},
    ['1131'] = 	{'RF SENSOR LOW BATTERY TROUBLE', '1'},
    ['1132'] = 	{'LOST ANC MODULE TROUBLE', '3'},
    ['1133'] = 	{'LOST KEYPAD TROUBLE', '3'},
    ['1134'] = 	{'LOST INPUT EXPANDER TROUBLE', '3'},
    ['1135'] = 	{'LOST OUTPUT EXPANDER TROUBLE', '3'},
    ['1136'] = 	{'EEPROM MEMORY ERROR TROUBLE', '4'},
    ['1137'] = 	{'FLASH MEMORY ERROR TROUBLE', '0'},
    ['1138'] = 	{'AC FAILURE TROUBLE', '0'},
    ['1139'] = 	{'CONTROL LOW BATTERY TROUBLE', '0'},
    ['1140'] = 	{'CONTROL OVER CURRENT TROUBLE', '0'},
    ['1141'] = 	{'EXPANSION MODULE TROUBLE', '3'},
    ['1142'] = 	{'OUTPUT 2 SUPERVISORY TROUBLE', '0'},
    ['1143'] = 	{'TELEPHONE LINE FAULT TROUBLE1', '0'},
    ['1144'] = 	{'RESTORE FIRE ZONE', '1'},
    ['1145'] = 	{'RESTORE FIRE SUPERVISORY ZONE', '1'},
    ['1146'] = 	{'RESTORE BURGLAR ZONE', '1'},
    ['1147'] = 	{'RESTORE MEDICAL ZONE', '1'},
    ['1148'] = 	{'RESTORE POLICE ZONE', '1'},
    ['1149'] = 	{'RESTORE AUX1 24 HR ZONE', '1'},
    ['1150'] = 	{'RESTORE AUX2 24 HR ZONE', '1'},
    ['1151'] = 	{'RESTORE CO ZONE', '1'},
    ['1152'] = 	{'RESTORE EMERGENCY ZONE', '1'},
    ['1153'] = 	{'RESTORE FREEZE ZONE', '1'},
    ['1154'] = 	{'RESTORE GAS ZONE', '1'},
    ['1155'] = 	{'RESTORE HEAT ZONE', '1'},
    ['1156'] = 	{'RESTORE WATER ZONE', '1'},
    ['1157'] = 	{'COMMUNICATION FAIL RESTORE', '0'},
    ['1158'] = 	{'AC FAIL RESTORE', '0'},
    ['1159'] = 	{'LOW BATTERY RESTORE', '0'},
    ['1160'] = 	{'CONTROL OVER CURRENT RESTORE', '3'},
    ['1161'] = 	{'EXPANSION MODULE RESTORE', '0'},
    ['1162'] = 	{'OUTPUT2 RESTORE', '0'},
    ['1163'] = 	{'TELEPHONE LINE RESTORE', '0'},
    ['1164'] = 	{'ALARM MEMORY, ANY AREA', '0'},
    ['1165'] = 	{'ALARM MEMORY, AREA 1', '0'},
    ['1166'] = 	{'ALARM MEMORY, AREA 2', '0'},
    ['1167'] = 	{'ALARM MEMORY, AREA 3', '0'},
    ['1168'] = 	{'ALARM MEMORY, AREA 4', '0'},
    ['1169'] = 	{'ALARM MEMORY, AREA 5', '0'},
    ['1170'] = 	{'ALARM MEMORY, AREA 6', '0'},
    ['1171'] = 	{'ALARM MEMORY, AREA 7', '0'},
    ['1172'] = 	{'ALARM MEMORY, AREA 8', '0'},
    ['1173'] = 	{'AREA ARMED', '2'},
    ['1174'] = 	{'AREA DISARMED', '2'},
    ['1175'] = 	{'AREA 1 ARM STATE', '2'},
    ['1176'] = 	{'AREA 2 ARM STATE', '2'},
    ['1177'] = 	{'AREA 3 ARM STATE', '2'},
    ['1178'] = 	{'AREA 4 ARM STATE', '2'},
    ['1179'] = 	{'AREA 5 ARM STATE', '2'},
    ['1180'] = 	{'AREA 6 ARM STATE', '2'},
    ['1181'] = 	{'AREA 7 ARM STATE', '2'},
    ['1182'] = 	{'AREA 8 ARM STATE', '2'},
    ['1183'] = 	{'AREA 1 IS ARMED AWAY', '2'},
    ['1184'] = 	{'AREA 2 IS ARMED AWAY', '2'},
    ['1185'] = 	{'AREA 3 IS ARMED AWAY', '2'},
    ['1186'] = 	{'AREA 4 IS ARMED AWAY', '2'},
    ['1187'] = 	{'AREA 5 IS ARMED AWAY', '2'},
    ['1188'] = 	{'AREA 6 IS ARMED AWAY', '2'},
    ['1189'] = 	{'AREA 7 IS ARMED AWAY', '2'},
    ['1190'] = 	{'AREA 8 IS ARMED AWAY', '2'},
    ['1191'] = 	{'AREA 1 IS ARMED STAY', '2'},
    ['1192'] = 	{'AREA 2 IS ARMED STAY', '2'},
    ['1193'] = 	{'AREA 3 IS ARMED STAY', '2'},
    ['1194'] = 	{'AREA 4 IS ARMED STAY', '2'},
    ['1195'] = 	{'AREA 5 IS ARMED STAY', '2'},
    ['1196'] = 	{'AREA 6 IS ARMED STAY', '2'},
    ['1197'] = 	{'AREA 7 IS ARMED STAY', '2'},
    ['1198'] = 	{'AREA 8 IS ARMED STAY', '2'},
    ['1199'] = 	{'AREA 1 IS ARMED STAY INSTANT', '2'},
    ['1200'] = 	{'AREA 2 IS ARMED STAY INSTANT', '2'},
    ['1201'] = 	{'AREA 3 IS ARMED STAY INSTANT', '2'},
    ['1202'] = 	{'AREA 4 IS ARMED STAY INSTANT', '2'},
    ['1203'] = 	{'AREA 5 IS ARMED STAY INSTANT', '2'},
    ['1204'] = 	{'AREA 6 IS ARMED STAY INSTANT', '2'},
    ['1205'] = 	{'AREA 7 IS ARMED STAY INSTANT', '2'},
    ['1206'] = 	{'AREA 8 IS ARMED STAY INSTANT', '2'},
    ['1207'] = 	{'AREA 1 IS ARMED NIGHT', '2'},
    ['1208'] = 	{'AREA 2 IS ARMED NIGHT', '2'},
    ['1209'] = 	{'AREA 3 IS ARMED NIGHT', '2'},
    ['1210'] = 	{'AREA 4 IS ARMED NIGHT', '2'},
    ['1211'] = 	{'AREA 5 IS ARMED NIGHT', '2'},
    ['1212'] = 	{'AREA 6 IS ARMED NIGHT', '2'},
    ['1213'] = 	{'AREA 7 IS ARMED NIGHT', '2'},
    ['1214'] = 	{'AREA 8 IS ARMED NIGHT', '2'},
    ['1215'] = 	{'AREA 1 IS ARMED NIGHT INSTANT', '2'},
    ['1216'] = 	{'AREA 2 IS ARMED NIGHT INSTANT', '2'},
    ['1217'] = 	{'AREA 3 IS ARMED NIGHT INSTANT', '2'},
    ['1218'] = 	{'AREA 4 IS ARMED NIGHT INSTANT', '2'},
    ['1219'] = 	{'AREA 5 IS ARMED NIGHT INSTANT', '2'},
    ['1220'] = 	{'AREA 6 IS ARMED NIGHT INSTANT', '2'},
    ['1221'] = 	{'AREA 7 IS ARMED NIGHT INSTANT', '2'},
    ['1222'] = 	{'AREA 8 IS ARMED NIGHT INSTANT', '2'},
    ['1223'] = 	{'AREA 1 IS ARMED VACATION', '2'},
    ['1224'] = 	{'AREA 2 IS ARMED VACATION', '2'},
    ['1225'] = 	{'AREA 3 IS ARMED VACATION', '2'},
    ['1226'] = 	{'AREA 4 IS ARMED VACATION', '2'},
    ['1227'] = 	{'AREA 5 IS ARMED VACATION', '2'},
    ['1228'] = 	{'AREA 6 IS ARMED VACATION', '2'},
    ['1229'] = 	{'AREA 7 IS ARMED VACATION', '2'},
    ['1230'] = 	{'AREA 8 IS ARMED VACATION', '2'},
    ['1231'] = 	{'AREA 1 IS FORCE ARMED', '2'},
    ['1232'] = 	{'AREA 2 IS FORCE ARMED', '2'},
    ['1233'] = 	{'AREA 3 IS FORCE ARMED', '2'},
    ['1234'] = 	{'AREA 4 IS FORCE ARMED', '2'},
    ['1235'] = 	{'AREA 5 IS FORCE ARMED', '2'},
    ['1236'] = 	{'AREA 6 IS FORCE ARMED', '2'},
    ['1237'] = 	{'AREA 7 IS FORCE ARMED', '2'},
    ['1238'] = 	{'AREA 8 IS FORCE ARMED', '2'},
    ['1239'] = 	{'ZONE BYPASSED', '1'},
    ['1240'] = 	{'ZONE UNBYPASSED', '1'},
    ['1241'] = 	{'ANY BURGLAR ZONE IS FAULTED', '0'},
    ['1242'] = 	{'BURGLAR STATUS OF ALL AREAS', '0'},
    ['1243'] = 	{'AREA 1 BURGLAR STATUS', '0'},
    ['1244'] = 	{'AREA 2 BURGLAR STATUS', '0'},
    ['1245'] = 	{'AREA 3 BURGLAR STATUS', '0'},
    ['1246'] = 	{'AREA 4 BURGLAR STATUS', '0'},
    ['1247'] = 	{'AREA 5 BURGLAR STATUS', '0'},
    ['1248'] = 	{'AREA 6 BURGLAR STATUS', '0'},
    ['1249'] = 	{'AREA 7 BURGLAR STATUS', '0'},
    ['1250'] = 	{'AREA 8 BURGLAR STATUS', '0'},
    ['1251'] = 	{'AREA 1 CHIME MODE', '0'},
    ['1252'] = 	{'AREA 2 CHIME MODE', '0'},
    ['1253'] = 	{'AREA 3 CHIME MODE', '0'},
    ['1254'] = 	{'AREA 4 CHIME MODE', '0'},
    ['1255'] = 	{'AREA 5 CHIME MODE', '0'},
    ['1256'] = 	{'AREA 6 CHIME MODE', '0'},
    ['1257'] = 	{'AREA 7 CHIME MODE', '0'},
    ['1258'] = 	{'AREA 8 CHIME MODE', '0'},
    ['1259'] = 	{'AREA 1 CHIME ALERT', '0'},
    ['1260'] = 	{'AREA 2 CHIME ALERT', '0'},
    ['1261'] = 	{'AREA 3 CHIME ALERT', '0'},
    ['1262'] = 	{'AREA 4 CHIME ALERT', '0'},
    ['1263'] = 	{'AREA 5 CHIME ALERT', '0'},
    ['1264'] = 	{'AREA 6 CHIME ALERT', '0'},
    ['1265'] = 	{'AREA 7 CHIME ALERT', '0'},
    ['1266'] = 	{'AREA 8 CHIME ALERT', '0'},
    ['1267'] = 	{'ENTRY DELAY, ANY AREA', '0'},
    ['1268'] = 	{'AREA 1 ENTRY DELAY', '0'},
    ['1269'] = 	{'AREA 2 ENTRY DELAY', '0'},
    ['1270'] = 	{'AREA 3 ENTRY DELAY', '0'},
    ['1271'] = 	{'AREA 4 ENTRY DELAY', '0'},
    ['1272'] = 	{'AREA 5 ENTRY DELAY', '0'},
    ['1273'] = 	{'AREA 6 ENTRY DELAY', '0'},
    ['1274'] = 	{'AREA 7 ENTRY DELAY', '0'},
    ['1275'] = 	{'AREA 8 ENTRY DELAY', '0'},
    ['1276'] = 	{'EXIT DELAY, ANY AREA', '0'},
    ['1277'] = 	{'AREA 1 EXIT DELAY', '0'},
    ['1278'] = 	{'AREA 2 EXIT DELAY', '0'},
    ['1279'] = 	{'AREA 3 EXIT DELAY', '0'},
    ['1280'] = 	{'AREA 4 EXIT DELAY', '0'},
    ['1281'] = 	{'AREA 5 EXIT DELAY', '0'},
    ['1282'] = 	{'AREA 6 EXIT DELAY', '0'},
    ['1283'] = 	{'AREA 7 EXIT DELAY', '0'},
    ['1284'] = 	{'AREA 8 EXIT DELAY', '0'},
    ['1285'] = 	{'AREA 1 EXIT DELAY ENDS', '0'},
    ['1286'] = 	{'AREA 2 EXIT DELAY ENDS', '0'},
    ['1287'] = 	{'AREA 3 EXIT DELAY ENDS', '0'},
    ['1288'] = 	{'AREA 4 EXIT DELAY ENDS', '0'},
    ['1289'] = 	{'AREA 5 EXIT DELAY ENDS', '0'},
    ['1290'] = 	{'AREA 6 EXIT DELAY ENDS', '0'},
    ['1291'] = 	{'AREA 7 EXIT DELAY ENDS', '0'},
    ['1292'] = 	{'AREA 8 EXIT DELAY ENDS', '0'},
    ['1293'] = 	{'AUTOMATIC CLOSING', '0'},
    ['1294'] = 	{'EARLY CLOSING', '2'},
    ['1295'] = 	{'CLOSING TIME EXTENDED', '2'},
    ['1296'] = 	{'FAIL TO CLOSE', '0'},
    ['1297'] = 	{'LATE TO CLOSE', '2'},
    ['1298'] = 	{'KEYSWITCH CLOSING', '1'},
    ['1299'] = 	{'DURESS', '2'},
    ['1300'] = 	{'EXCEPTION OPENING', '2'},
    ['1301'] = 	{'EARLY OPENING', '2'},
    ['1302'] = 	{'FAIL TO OPEN', '0'},
    ['1303'] = 	{'LATE TO OPEN', '2'},
    ['1304'] = 	{'KEYSWITCH OPENING', '1'},
    ['1305'] = 	{'AREA 1 CLOSING RING BACK', '0'},
    ['1306'] = 	{'AREA 2 CLOSING RING BACK', '0'},
    ['1307'] = 	{'AREA 3 CLOSING RING BACK', '0'},
    ['1308'] = 	{'AREA 4 CLOSING RING BACK', '0'},
    ['1309'] = 	{'AREA 5 CLOSING RING BACK', '0'},
    ['1310'] = 	{'AREA 6 CLOSING RING BACK', '0'},
    ['1311'] = 	{'AREA 7 CLOSING RING BACK', '0'},
    ['1312'] = 	{'AREA 8 CLOSING RING BACK', '0'},
    ['1313'] = 	{'ACCESS KEYPAD 01', '2'},
    ['1314'] = 	{'ACCESS KEYPAD 02', '2'},
    ['1315'] = 	{'ACCESS KEYPAD 03', '2'},
    ['1316'] = 	{'ACCESS KEYPAD 04', '2'},
    ['1317'] = 	{'ACCESS KEYPAD 05', '2'},
    ['1318'] = 	{'ACCESS KEYPAD 06', '2'},
    ['1319'] = 	{'ACCESS KEYPAD 07', '2'},
    ['1320'] = 	{'ACCESS KEYPAD 08', '2'},
    ['1321'] = 	{'ACCESS KEYPAD 09', '2'},
    ['1322'] = 	{'ACCESS KEYPAD 10', '2'},
    ['1323'] = 	{'ACCESS KEYPAD 11', '2'},
    ['1324'] = 	{'ACCESS KEYPAD 12', '2'},
    ['1325'] = 	{'ACCESS KEYPAD 13', '2'},
    ['1326'] = 	{'ACCESS KEYPAD 14', '2'},
    ['1327'] = 	{'ACCESS KEYPAD 15', '2'},
    ['1328'] = 	{'ACCESS KEYPAD 16', '2'},
    ['1329'] = 	{'ACCESS ANY KEYPAD', '2'},
    ['1330'] = 	{'BEEP AREA 1 KEYPAD(S)', '0'},
    ['1331'] = 	{'BEEP AREA 2 KEYPAD(S)', '0'},
    ['1332'] = 	{'BEEP AREA 3 KEYPAD(S)', '0'},
    ['1333'] = 	{'BEEP AREA 4 KEYPAD(S)', '0'},
    ['1334'] = 	{'BEEP AREA 5 KEYPAD(S)', '0'},
    ['1335'] = 	{'BEEP AREA 6 KEYPAD(S)', '0'},
    ['1336'] = 	{'BEEP AREA 7 KEYPAD(S)', '0'},
    ['1337'] = 	{'BEEP AREA 8 KEYPAD(S)', '0'},
    ['1338'] = 	{'AREA 1 EXIT ERROR', '0'},
    ['1339'] = 	{'AREA 2 EXIT ERROR', '0'},
    ['1340'] = 	{'AREA 3 EXIT ERROR', '0'},
    ['1341'] = 	{'AREA 4 EXIT ERROR', '0'},
    ['1342'] = 	{'AREA 5 EXIT ERROR', '0'},
    ['1343'] = 	{'AREA 6 EXIT ERROR', '0'},
    ['1344'] = 	{'AREA 7 EXIT ERROR', '0'},
    ['1345'] = 	{'AREA 8 EXIT ERROR', '0'},
    ['1346'] = 	{'AUDIO AMPLIFIER STATUS', '0'},
    ['1347'] = 	{'CONTROL POWER STATUS', '0'},
    ['1348'] = 	{'LIGHT', '0'},
    ['1349'] = 	{'DARK', '0'},
    ['1350'] = 	{'SECURITY (DAY) ALERT', '1'},
    ['1351'] = 	{'DIALER ABORT', '2'},
    ['1352'] = 	{'DIALER CANCEL', '2'},
    ['1353'] = 	{'DIALER AUTO TEST', '0'},
    ['1354'] = 	{'LOCAL PROGRAMMING', '0'},
    ['1355'] = 	{'LOCAL PROGRAMMING ENDS', '0'},
    ['1356'] = 	{'KEYSWITCH ZN TAMPER ALERT', '1'},
    ['1357'] = 	{'EVENT LOG, 80% FULL', '0'},
    ['1358'] = 	{'TELEPHONE LINE IS RINGING', '0'},
    ['1359'] = 	{'TELEPHONE LINE SEIZE', '0'},
    ['1360'] = 	{'TELEPHONE LINE OFF/ON HOOK', '0'},
    ['1361'] = 	{'TELEPHONE LOCAL ACCESS', '0'},
    ['1362'] = 	{'TELEPHONE REMOTE ACCESS', '0'},
    ['1363'] = 	{'REMOTE PROGRAMMING', '0'},
    ['1364'] = 	{'REMOTE PROGRAMMING ENDS', '0'},
    ['1365'] = 	{'AC FAIL TBL - POWER SUPV ZN', '1'},
    ['1366'] = 	{'LOW BATTERY TBL - POWER SUPV ZN', '1'},
    ['1367'] = 	{'SYSTEM START UP', '3'},
    ['1368'] = 	{'CONTROL LOW VOLTAGE SHUTDOWN', '0'},
    ['1369'] = 	{'RF KEYFOB BUTTON 1', '0'},
    ['1370'] = 	{'RF KEYFOB BUTTON 2', '0'},
    ['1371'] = 	{'RF KEYFOB BUTTON 3', '0'},
    ['1372'] = 	{'RF KEYFOB BUTTON 4', '0'},
    ['1373'] = 	{'RF KEYFOB BUTTON 5', '0'},
    ['1374'] = 	{'RF KEYFOB BUTTON 6', '0'},
    ['1375'] = 	{'RF KEYFOB BUTTON 7', '0'},
    ['1376'] = 	{'RF KEYFOB BUTTON 8', '0'},
    ['1377'] = 	{'LOST SERIAL PORT EXPANDER TROUBLE', '3'},
    ['1378'] = 	{'RULE TRIGGERED VOICE TELEPHONE DIAL', '5'},
    ['1379'] = 	{'DIALER REPORT CLEARED', '2'},
    ['1380'] = 	{'CENTRAL STATION KISSOFF', '0'},
    ['1381'] = 	{'TRANSMITTER SUPERVISION LOSS', '1'},
    ['1382'] = 	{'2-WIRE SMOKE DET. CLEAN TRBL', '1'},
    ['1383'] = 	{'ETHERNET TROUBLE', '0'},
    ['1384'] = 	{'ETHERNET RESTORE', '0'},
    ['1385'] = 	{'RESTORE REMOTE AC POWER', '1'},
    ['1386'] = 	{'RESTORE REMOTE BATTERY', '1'},
  }

  if (EVENTS[event]) then 
    return EVENTS[event]
  else
    event = tonumber(event)
    if event >= 2001 and event <=2032 then
      return ({"AUTOMATION TASK " .. (tostring(event):sub(3,4)),'0'})
    elseif event >= 3001 and event <=3096 then
      local keypadFunc = event-3000
      keypad = math.ceil(keypadFunc/6)
      f_key = ((keypadFunc % 6) == 0) and 6 or (keypadFunc  % 6)
      return ({"KEYPAD " .. keypad .. " FUNCTION KEY " .. f_key,'1'})
    elseif event >= 4001 and event <=4208 then
      return ({"AREA VIOLATED",'1'})      
    elseif event >= 5001 and event <=5208 then
      return ({"AREA BYPASSED",'1'})          
    elseif event >= 6001 and event <=6208 then
      return ({"AREA ALARM ACTIVATED",'1'})         
    elseif event >= 7001 and event <=7208 then  
      return ({"OUTPUT STATUS ON",'1'})
    else
      return ({"UNKNOWN RESPONSE",'0'})
    end
  end
end

function data_logger(data)
  local Inter_table = {
    ['0'] = {
      description = "Interpretation of Ext Info Field in Log Entry, type 0",
      handlerFunc = function (self, data, area)
      return ""
      end
    },
  
    ['1'] = {
      description = "Interpretation of Ext Info Field in Log Entry, type 1",
      handlerFunc = function (self, data, area)
        debug(self.description)
        if (data >= 1 and data <=208) then
          return "AREA " .. area  .. " ZONE " .. data
        elseif(data > 400) then
          local keypadFunc = data-400
          keypad = math.ceil(keypadFunc/6)
          fKey = ((keypadFunc % 6) == 0) and 6 or (keypadFunc  % 6)
          return " AREA " .. area .. "KEYPAD " .. keypad .. " FUNCTION KEY " .. fKey
        else
          return ""
        end
      end
    },
  
    ['2'] = {
      description = "Interpretation of Ext Info Field in Log Entry, type 2",
      handlerFunc = function (self, data, area)
        debug(self.description)
        if (data >= 1 and data <=199) then
          local user = g_users[data] and g_users[data].label:upper() or data
          return "AREA " .. area .. " USER " .. user
        elseif (data == 201) then
          return "AREA " ..  area .. " INSTALLER"
        elseif (data == 202) then
          return "AREA " .. area ..  " ELKRP"
        elseif (data == 203) then
          return "AREA " ..  area .. " NO_CODE/QUICKARM"
        else
          return ""
        end
      end
    },
  
    ['3'] = {
      description = "Interpretation of Ext Info Field in Log Entry, type 3",
      handlerFunc = function (self, data, area, event)
        debug(self.description)
        if (data == 0 or event == '1367') then
          return "CONTROLLER"
        elseif (data == 1) then
          return "KEYPAD "..  data
        elseif (data == 2) then
          return "INPUT EXPANDER " ..  data
        elseif (data == 3) then
          return "OUTPUT EXPANDER " ..  data
        elseif (data  == 4) then
          return "RESERVED " ..  data
        elseif (data == 5) then
          return "SERIAL EXPANDER " ..  data
        else
          return ""
        end
      end
    },
  
    ['4'] = {
      description = "Interpretation of Ext Info Field in Log Entry, type 4",
      handlerFunc = function (self, data, area)
        debug(self.description)
        return "EEPROM ADDRESS " .. data
      end
    },
  
    ['5'] = {
      description = "Interpretation of Ext Info Field in Log Entry, type 5",
      handlerFunc = function (self, data, area)
        debug(self.description)
        if(data == 0) then
          return "VOICE MESSAGE VM278"
        elseif(data >= 209 and data <= 323) then
          return "VOICE MESSAGE VM" .. data
        else
          return ""
        end
      end
  },
  
  }
  
  local event = data:sub(1,4)
  local event_ext = tonumber(data:sub(5,7))
  local area = tonumber(data:sub(8,8))
  local response = get_event_string(event)
  local event_description
  
  if (response == nil) then
    debug("data_logger: Unhandled message type '"..event.."'")
    return false
  end

  if (type(response) == "table") then
    event_description = (response[1] or "UNKNOWN RESPONSE")
  end
  
  if (type(Inter_table[response[2]].handlerFunc) ~= "function") then
    log("processMessage: ERROR: Unknown message type, or message type handled incorrectly.")
    return false
  end
  
  local log_extension = Inter_table[response[2]]:handlerFunc(event_ext, area, event) or ""
  
  return event_description .. " " .. log_extension .. "."
  
end 


local function processElkLog (data)
  local event_string = data_logger(data)
  local time = data:sub(9,10)..":"..data:sub(11,12)
  local index = tonumber(data:sub(17,19))
  local day = DAYS[tonumber(data:sub(20,20))] .. " " .. data:sub(15,16) .. " " .. 
    MONTHS[tonumber(data:sub(13,14))] .. " " .. tonumber(data:sub(21,22))
  table.insert(g_logFile,"{" ..
    "\"index\": \"" .. index .. "\"," ..
    "\"eventType\": \"" .. event_string .. "\"," ..
    "\"time\": \"" .. time .. "\"," ..
    "\"day\": \"" .. day .. "\"" ..
    "}")
  debug("processElkLog: processing log index ".. data:sub(17,19) .. ".")
  return true
end



function processRTC(data)
  local sec = data:sub(1,2)
  local min = data:sub(3,4)
  local hour = data:sub(5,6)
  local wday = DAYS[tonumber(data:sub(7,7))]
  local dayOfMonth = data:sub(8,9)
  local month = MONTHS[tonumber(data:sub(10,11))]
  local year = string.format("2%03i",data:sub(12,13))
  local daylightSaving = data:sub(14,14)
  local clockMode = data:sub(15,15)
  local displayMode = data:sub(15,16)
  local ElkRTC = month .. " " .. dayOfMonth ..", " .. year .. " " .. hour .. ":" .. min .. ":" .. sec
  luup.variable_set(ELK_SID, "ElkRTC", ElkRTC, elk_device)
end
----------------------------------------------------------------------------------------------------------------
-- Initialisation
----------------------------------------------------------------------------------------------------------------
local function getTemperatureSensors (data)

  local si = 0

  -- Extract the temperatures from the data.
  for t in data:gmatch("%d%d%d") do
    si = si + 1
    local temp = tonumber(t, 10) or 0
    if (temp > 0) then
      g_tempSensors[si] = {}
      g_tempSensors[si].type = (si <= 16) and "Keypad" or "Zone Sensor" -- First 16 sensors are from the keypads.
      g_tempSensors[si].temp = (si <= 16) and temp - 40 or temp - 60 -- First 16 subtract 40 than 60 after that as indicated in the manual.
    end
  end

  -- Get the device IDs for the temperature sensors.
  for dev, attr in pairs(luup.devices) do
    if (attr.device_num_parent == elk_device) then
      si = attr.id:match("elk_temp_(%d+)") or attr.id:match("elk_keypad_sensor_(%d+)")
      if (si ~= nil) then
        si = ("elk_temp_" == attr.id:match("^elk_temp_")) and (tonumber(si, 10)+16) or (tonumber(si, 10))
        if (g_tempSensors[si] ~=nil) then
          g_tempSensors[si].devId = dev
        end
      end
    end
  end
end

local function initThermostats (data)
  local tnum, mode, hold, fan, temp, hsp, csp, hum = data:match("^(%d%d)(%d)(%d)(%d)(%d%d)(%d%d)(%d%d)(%d%d)")

  tnum = tonumber(tnum, 10)
  task("reading thermostat ".. tnum .."/16", TASK_BUSY)
  if (data:sub(3,13) ~= 0 and g_thermostats[tnum] ~= nil) then
    g_thermostats[tnum].mode = TSTAT_MODES[mode]
    g_thermostats[tnum].fan  = (fan == "0") and "Auto" or "ContinuousOn"
    g_thermostats[tnum].hold = hold
    g_thermostats[tnum].temp = temp
    g_thermostats[tnum].hsp  = hsp
    g_thermostats[tnum].csp  = csp
    g_thermostats[tnum].hum  = hum
  end

  -- Update the thermostats.
  for ti, tstat in pairs(g_thermostats) do
    luup.variable_set(TEMP_SID,  "CurrentTemperature", tstat.temp, tstat.devId)
    luup.variable_set(HVACO_SID, "ModeStatus", tstat.mode, tstat.devId)
    luup.variable_set(HVACF_SID, "Mode", tstat.fan, tstat.devId)
    luup.variable_set(HVACHEAT_SID, "CurrentSetpoint", tstat.hsp, tstat.devId)
    luup.variable_set(HVACCOOL_SID, "CurrentSetpoint", tstat.csp, tstat.devId)
    luup.variable_set(HADEVICE_SID, "LastUpdate", tostring(os.time()), tstat.devId)
  end

  luup.call_delay("pollNextThermostat", POLL_FREQUENCY)
end

local function plcChangeUpdate(data)
  local houseCode = data:sub(1, 1)
  local unitCode = tonumber(data:sub(2, 3))
  local ll = data:sub(4, 5)
  local status
  if(unitCode == 0) then
    status = PLC_MODES[ll]
  else
    local houseCodeTable = {A=0,B=1,C=2,D=3,E=4,F=5,G=6,H=7,I=8,J=9,K=10,L=11,M=12,N=13,O=14,P=15}
    status = tonumber(ll,10)
    local deviceNo = tonumber((string.format('%X',houseCodeTable[houseCode]) .. string.format('%X',unitCode-1))+1,16)
    luup.variable_set(SWP_SID, "Status", statusCode, g_lights[deviceNo].devId)
  end
  
  unitCode = (unitCode == 0) and "All Units " or ("Unit " .. unitCode .. " ")
  debug("plcChangeUpdate: House Code ".. houseCode ..", ".. unitCode .. "set too " .. status)
end

local function plcStatus(data)
  local bankTable = {65,69,73,77}
  local bank = bankTable[(tonumber(data:sub(1, 1))+1)]
  local plcStatus = data:sub(2, 65)
  for i=1,#plcStatus do
    local convertBank = string.format("%02X",tonumber(i-1))
    local houseCode = string.char(bank + convertBank:sub(1,1))
    local PLCUnit = (tonumber(convertBank:sub(2,2),16)+1)
    local status = tonumber(((plcStatus:sub(i, i)):byte())-48)
    
    if status == 0 then
      status = "Off 0%"
    elseif status == 1 then
      status = "On  100%"
    else
      status = "On  " .. status .. "%"
    end
    debug("plcStatus: House Code ".. houseCode ..", PLC Unit ".. string.format("%02i",PLCUnit) .. " " .. status)
  end
end

local function processLabels (data)
  local labelId = data:sub(1, 2)
  debug("processLabels: Label type: " .. tostring(LABEL_TYPES[labelId]))
  data = data:gsub("(%s+)$", "") -- Remove the trailing whitespace from the label.
  local num = tonumber(data:sub(3, 5))

  if (num == 0) then
    log("processLabels: Label type: " .. tostring(LABEL_TYPES[labelId]) .. " No processing.")
    return
  else
    if (labelId == "00") then
      g_zones[num].label = data:sub(6)
    elseif (labelId == "01") then
      g_partitions[num].label = data:sub(6)
    elseif (labelId == "03") then
      --g_keypads[num].label = data:sub(6)
      if (g_tempSensors[num] ~= nil) then
        g_tempSensors[num].label = data:sub(6)
      end
    else
      debug("processLabels: Label type: " .. tostring(LABEL_TYPES[labelId]) .. " No processing.")
    end
  end
end

local function updateOutputs (data)
  for outputNo, attr in pairs(g_outputs) do
    local state = data:sub(outputNo, outputNo)
    local device = g_outputs[outputNo].devId
    luup.variable_set(SWP_SID, "Status", state,  device)
    debug("updateOutputs: Output ".. outputNo .." is ".. (state == "1" and "On" or "Off") .. " (device " .. device .. ").")
  end
end

local function updateCounters (data)
  local counterNo = tonumber(data:sub(1, 2),10)
  if (g_counters[counterNo] ~=nil) then
    g_counters[counterNo].value = tonumber(data:sub(3, 7),10)
  end
end

local function updateCustomValue(data)
    debug("updateCustomValue: Incoming data ".. data ..".")
    local customValue = tonumber(data:sub(1, 2),10)
    if (g_customs[customValue] ~=nil) then
      g_customs[customValue].value = tonumber(data:sub(3, 7),10)
      g_customs[customValue].format = tonumber(data:sub(8, 8),10)
    end
end

local function updateCustomValues(data)
  if (#data > 8) then
    data = data:sub(3)
    for i=1,20 do
      local value1 = ((i*6)-5)
      local value2 = ((i*6)-5)+5
      local index = string.format("%02i",i)
      local customValue = index .. data:sub(value1,value2)
      updateCustomValue(customValue)
    end
  else
    updateCustomValue(data)
  end
end

local function checkValidUserCode(data)
  debug("checkValidUserCode: Got expected message.")
  local code, codeNo, keypadNo = data:match("^(%x+)(%d%d%d)(%d%d)$")
  if (tonumber(code,16) == 0) then
    debug("checkValidUserCode: Valid PIN.")
    if (tonumber(codeNo) ~= 0) then
      debug("checkValidUserCode: Valid User.")
      debug("checkValidUserCode: waiting for request response.")
      luup.io.intercept()
      return true
    else
      debug("checkValidUserCode: Invalid User.")
      return false
    end
  else
    debug("checkValidUserCode: incorrect PIN:" .. code ..  " or incorrect user:" .. codeNo .. ".")
    return false
  end
end
----------------------------------------------------------------------------------------------------------------
-- Message Processing
----------------------------------------------------------------------------------------------------------------

local PANEL_RESPONSES = {
  ["AS"] = {
    description = "Arming Status Report",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    if (INITIALIZED == false) then
                      debug(self.description .. ":Plugin not initialized")
                      return true
                    else
                      processArmingStatusReport(data)
                      return true
                    end
                  end
  },
  ["CC"] = {
    description = "Output Change Update",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    if (INITIALIZED == false) then
                      debug(self.description .. ":Plugin not initialized")
                      return true
                    else
                      processOutputReport(data)
                      return true
                    end
                  end
  },
  ["CR"] = {
    description = "Read Custom Value",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    updateCustomValues(data)
                    return true
                  end
  },
  ["CS"] = {
    description = "Control Output Status Report",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    updateOutputs(data)
                    return true
                  end
  },
  ["CV"] = {
    description = "Read Counter Value",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    updateCounters(data)
                    return true
                  end
  },
  ["IC"] = {
    description = "PIN Code Feedback",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    return checkValidUserCode(data)

                  end
  },
  ["IE"] = {
    description = "Installer Program Mode Terminated",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    task("Installer Program Mode Terminated.", TASK_ERROR)
                    return true
                  end
  },
  ["KA"] = {
    description = "Request Keypad Area Assignments",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    local kp = 0 -- kepad Index
                    for p in data:gmatch("%d") do
                      kp = kp + 1
                      local partition = tonumber(p, 10) or 0
                      if (partition > 0 and (g_keypads[kp] ~= nil)) then
                        g_keypads[kp].partition = partition
                      end
                    end
                    return true
                  end
  },
  ["KC"] = {
    description = "Keypad KeyChange Update",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    return processKeypadKeyChangeUpdate (data)
                  end
  },
  ["KF"] = {
    description = "Keypad Function Key Press",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    return processFunctionKey (data)
                  end
  },
  ["LD"] = {
    description = "Request System Log Data",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    return processElkLog (data)
                  end
  },
  ["LW"] = {
    description = "Zone Temperature and Keypad Temperature",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    getTemperatureSensors(data)
                    return true
                  end
  },
  ["PC"] = {
    description = "PLC Change Update",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    plcChangeUpdate(data)
                    return true
                  end
  },
  ["PS"] = {
    description = "Returned PLC status",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    plcStatus(data)
                    return true
                  end
  },
  ["RP"] = {
    description = "ELKRP Connected",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    local status = data:sub(1,2)
                    if(status == "00") then
                      debug("ELKRP: Disconnected")
                      clearStatusMessage()
                    elseif(status == "01") then
                      debug("ELKRP: Connected")
                      task("ELKRP is connected.", TASK_ERROR_PERM)
                    elseif(status == "02") then
                      debug("M1XEP: Initializing")
                      task("M1XEP is initializing.", TASK_ERROR)
                    end

                    return true
                  end
  },
  ["RR"] = {
    description = "Request Real Time Clock Data",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    processRTC(data)
                    return true
                  end
  },
  ["SD"] = {
    description = "ASCII String Text Descriptions",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    processLabels(data)
                    return true, data
                  end
  },
  ["SS"] = {
    description = "System Trouble Status",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    processSystemTroubleStatus(data)
                    return true
                  end
  },
  ["ST"] = {
    description = "Requested Temperature",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    updateTemperature(data)
                    return true
                  end
  },
  ["TC"] = {
    description = "Task Change Update",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    processTaskReport(data)
                    return true
                  end
  },
  ["TR"] = {
    description = "Thermostat Data",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    if (INITIALIZED == false) then
                        debug(self.description .. ":Plugin not initialized")
                        initThermostats(data)
                    else
                        updateThermostat(data)
                    end
                    return true
                  end
  },
  ["VN"] = {
    description = "M1 Version Number",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    local uver, mver, lver = data:match("^(%x%x)(%x%x)(%x%x)")
                    return string.format("%d.%d.%d", tonumber(uver, 16), tonumber(mver, 16), tonumber(lver, 16))
                  end
  },
  ["XK"] = {
    description = "Ethernet Module Test",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    HEARTBEAT = os.time()
                    return true
                  end
  },
  ["ZB"] = {
    description = "Bypassed Zone State",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    local zone, status = data:match("^(%d%d%d)(%d)$")
                    if (status == "1") then
                      return "bypassed"
                    end
                    return "unbypassed"
                  end
  },
  ["ZC"] = {
    description = "Zone Change Update",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    if (INITIALIZED == false) then
                      debug(self.description .. ":Plugin not initialized")
                      return true
                    else
                    processZoneChangeUpdate(data)
                    end
                    return true
                  end
  },
  ["ZD"] = {
    description = "Zone Definition Data",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    for i = 1, #data do
                      c = data:sub(i, i)
                      if (c ~= '0') then
                        g_zones[i] = {} -- Create zone.
                        g_zones[i].label = "Zone " .. i
                         g_zones[i].alarmtype = c
                      end
                    end
                    return true
                  end
  },
  ["ZP"] = {
    description = "Zone Partition Report",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    processZonePartitionReport(data)
                    return true
                  end
  },
  ["ZS"] = {
    description = "Zone Status Report",
    handlerFunc = function (self, data)
                    debug("handlerFunc Message type description: ".. self.description)
                    processZoneStatusReport(data)
                    return true
                  end
  }
}

function processMessage (data, msgType)
  if (not msgType) then -- We called this function from the <incoming> handler, so we check the message.
    msgType, data = checkMessage(data)
    if (not msgType or msgType == "") then
      return false
    end
  end

  local response = PANEL_RESPONSES[msgType]
  if (response == nil) then
    debug("processMessage: Unhandled message type '"..msgType.."'")
    return false
  end

  if (type(response.handlerFunc) ~= "function") then
    log("processMessage: ERROR: Unknown message type, or message type handled incorrectly.")
    return false
  end

  return response:handlerFunc(data)
end

local function readResponse (expectedMsgType, functionName, errorMsg)

  local msgType, rx = checkMessage(luup.io.read())
  
  if (not msgType) then
    log(functionName..": ERROR: "..errorMsg)
    g_errorMessage = errorMsg
    return false
  end

  local status, data = processMessage(rx, msgType)

  if (msgType == expectedMsgType) then -- We received the expected message.
    debug("readResponse: Got expected message '"..msgType.."'.")
    if (not status) then
    log(functionName..": ERROR: "..errorMsg)
      g_errorMessage = errorMsg
    end
    return status, data
  end

  -- We received other message. Process it and read the next message.
  local retryCount = 0
  while (retryCount <= MAX_RETRIES) do
    luup.io.intercept()
    debug("readResponse: Unexpected response type. Intercept next message.")
    retryCount = retryCount + 1

    msgType, data = checkMessage(luup.io.read())
    if (not msgType) then
    log(functionName..": ERROR: "..errorMsg)
      g_errorMessage = errorMsg
      return false
    end

    status, data = processMessage(data, msgType)

    if (msgType == expectedMsgType) then -- We received the expected message.
      debug("readResponse: Got expected message.")
      if (not status) then
    log(functionName..": ERROR: "..errorMsg)
        g_errorMessage = errorMsg
      end
      return status, data
    end
  end

  -- Shouldn't get here.
  return nil
end



local function readArmRequestResponse()

  local readCnt = 0

  while (readCnt <= MAX_READS) do
    local msgType, data = checkMessage(luup.io.read())
    if (not msgType) then
      return false
    end

    if (msgType == "AS") then
      debug("readArmRequestResponse: Got expected message.")
      return true
    elseif (msgType == "IC") then
      if(checkValidUserCode(data) == false) then return "IC" end
    else
      debug("readArmRequestResponse: Got unexpected message. Process it and intercept the next one.")
      --debug("readArmRequestResponse: Got unexpected message. Ignore it.")
      readCnt = readCnt + 1
      if (readCnt < MAX_READS) then
        luup.io.intercept()
      end
      processMessage(data, msgType)
    end
  end

  return false
end



local function readBypassRequestResponse()

  local readCnt = 0

  while (readCnt <= MAX_READS) do
    local msgType, data = checkMessage(luup.io.read())
    if (not msgType) then
      return false
    end

    if (msgType == "ZB") then
      debug("readBypassRequestResponse: Got expected message.")
      return processMessage(data, msgType)
    elseif (msgType == "IC") then
      if(checkValidUserCode(data) == false) then return "IC" end
    else
      debug("readBypassRequestResponse: Got unexpected message. Process it and intercept the next one.")
      readCnt = readCnt + 1
      if (readCnt < MAX_READS) then
        luup.io.intercept()
      end
      processMessage(data, msgType)
    end
  end

  return false
end



local function sendCommand (command, data)
  data = data or ""

  local length = 2 + #data + 2 + 2 -- command length + data length + 00 length + checksum length
  local checksum = calculateChecksum( string.format("%0.2X%s%s00", length, command, data) )
  local cmd = string.format("%0.2X%s%s00%0.2X", length, command, data, checksum)
  debug("sendCommand: Send command: '".. cmd .."'.")
  if (not luup.io.write(cmd)) then
    log("sendCommand: ERROR: Failed to send command: '".. cmd .."'.")
    return false
  end

  return true
end



local function sendIntercepted (msgType, functionName, errorMsg, data)
  luup.io.intercept()
  if (not sendCommand(msgType, data)) then
    log(functionName..": ERROR: "..errorMsg)
    g_errorMessage = errorMsg
    return false
  end

  return true
end



----------------------------------------------------------------------------------------------------------------
-- Action Implementations
----------------------------------------------------------------------------------------------------------------
function storePinCode (device, pinCode)

  local partitionNo = luup.devices[device].id:match("^elk_partition_(%d+)")
  if (partitionNo == nil) then
    log("storePinCode: ERROR: Invalid partition number. The altid of device ".. device .." is '".. luup.devices[device].id .."'.")
    task("Error storing the PIN code.", TASK_ERROR)
    return
  end

  pinCode = pinCode or ""
  if (pinCode == "") then
    log("storePinCode: ERROR: Empty PIN code field.")
    task("Empty PIN code field.", TASK_ERROR)
    return
  end

  pinCode = padLeft(pinCode, 6)
  if (pinCode:match("^%d%d%d%d%d%d$") == nil) then
    log("storePinCode: ERROR: Invalid PIN code.")
    task("Invalid PIN code.", TASK_ERROR)
    return
  end

  g_pinCodes[tonumber(partitionNo, 10)] = pinCode
  debug("storePinCode: PIN code stored for partition " .. partitionNo .. ".")
end



function clearPinCode (device)
  local partitionNo = luup.devices[device].id:match("^elk_partition_(%d+)")
  if (partitionNo == nil) then
    log("storePinCode: ERROR: Invalid partition number. The altid of device ".. device .." is '".. luup.devices[device].id .."'.")
    task("Error storing the PIN code.", TASK_ERROR)
    return
  end

  g_pinCodes[tonumber(partitionNo, 10)] = nil
  debug("clearPinCode: PIN code cleared for partition " .. partitionNo .. ".")
end

function clearTask()
    clearStatusMessage()
end

function requestArmMode (device, state, pinCode)
  local functionName = "requestArmMode"
  local errorMessage = "Failed to go into the requested arm mode."

  local partitionNo = luup.devices[device].id:match("^elk_partition_(%d+)")
  if (partitionNo == nil) then
    log("requestArmMode: ERROR: Invalid partition number. The altid of device ".. device .." is '".. luup.devices[device].id .."'.")
    task("Error invalid partition number.", TASK_ERROR)
    return
  end

  debug("requestArmMode: Request to arm partition ".. partitionNo .." (device ".. device ..") to state '".. state .."'.")

  partitionNo = tonumber(partitionNo)

  pinCode = tonumber(pinCode) or g_pinCodes[partitionNo]
  if (not pinCode) then
    log("requestArmMode: ERROR: PIN code required.")
    task("PIN code required.", TASK_ERROR)
    return false
  end

  -- All the arming commands are implicitly 'forced',
  -- so for the 'Force' request use 'Away' instead.
  state = (state == "Force") and "Armed" or state

  local command
  if (state == "Disarmed") then
    command = "a0" -- Disarm
  elseif ((state == "Armed") or (state == "Force")) then
    command = "a1" -- Arm Away
  elseif (state == "Stay") then
    command = "a2" -- Arm Stay
  elseif (state == "StayInstant") then
    command = "a3" -- Arm Stay Instant
  elseif (state == "Night") then
    command = "a4" -- Arm Night
  elseif (state == "NightInstant") then
    command = "a5" -- Arm Night Instant
  elseif (state == "Vacation") then
    command = "a6" -- Arm Vacation
  else
    log("requestArmMode: ERROR: Invalid state requested.")
    task("Invalid state requested.", TASK_ERROR)
    return false
  end

  local data
  if (pinCode and pinCode ~= "") then
    data = partitionNo .. padLeft(pinCode, 6, '0')
  else
    data = partitionNo .. g_pinCodes
  end

  local status = sendIntercepted(command, functionName, errorMessage, data)
  if (not status) then
    task("Failed to send command.", TASK_ERROR)
    return false
  end

  local status = readArmRequestResponse()
  if (not status) then
    log("requestArmMode: ERROR: " .. errorMessage)
    task(errorMessage, TASK_ERROR)
    return false
  elseif (status == "IC") then
    log("requestArmMode: ERROR: Invalid PIN or user.")
    task("Invalid PIN or User code.", TASK_ERROR)
    return false
  end

  g_pinCodes[partitionNo] = pinCode
  debug("requestArmMode: SUCCESS: Succesfully changed to the requested arm mode.")
  task("SUCCESS: Arm mode succesfully changed.")
  return true
end

function requestQuickArmMode (device, state)
  --Pseudo quickarm, ELK does not support quickarm via RS232, so will only work if PIN already stored.
  local functionName = "requestQuickArmMode"
  local errorMessage = "Failed to go into the requested arm mode."

  local partitionNo = luup.devices[device].id:match("^elk_partition_(%d+)")
  if (partitionNo == nil) then
    log("requestQuickArmMode: ERROR: Invalid partition number. The altid of device ".. device .." is '".. luup.devices[device].id .."'.")
    task("Error invalid partition number.", TASK_ERROR)
    return
  end

  debug("requestQuickArmMode: Request to arm partition ".. partitionNo .." (device ".. device ..") to state '".. state .."'.")
  partitionNo = tonumber(partitionNo)
  pinCode = g_pinCodes[partitionNo]

  if (not pinCode) then
    log("requestQuickArmMode: ERROR: Stored PIN code required.")
    task("Stored PIN code required for quickarm.", TASK_ERROR)
    return false
  end

   -- All the arming commands are implicitly 'forced',
  -- so for the 'Force' request use 'Away' instead.

  state = (state == "Force") and "Armed" or state
  local command
  if ((state == "Armed") or (state == "Force")) then
    command = "a1" -- Arm Away
  elseif (state == "Stay") then
    command = "a2" -- Arm Stay
  else
    log("requestQuickArmMode: ERROR: Invalid state requested.")
    task("Invalid state requested.", TASK_ERROR)
    return false
  end

  local data
  if (pinCode and pinCode ~= "") then
    data = partitionNo .. g_pinCodes
  end

  local status = sendIntercepted(command, functionName, errorMessage, data)
  if (not status) then
    task("Failed to send command.", TASK_ERROR)
    return false
  end

  local status = readArmRequestResponse()
  if (not status or status =="IC") then
    log("requestQuickArmMode: ERROR: die quietly.")
    return false
  end

  debug("requestArmMode: SUCCESS: Succesfully changed to the requested arm mode.")
  task("SUCCESS: Arm mode successfully changed.")
  return true

end



function requestPanicMode (device, state)
  log("requestPanicMode: Panic Modes not supported.")
  task("Panic Modes not supported.", TASK_ERROR)
  return false
end



local function unbypassZone (zoneNo, pinCode, tryCount)
  local errorMessage = string.format("Failed to unbypass zone %d.", zoneNo)

  debug("unbypassZone: tryCount=" .. tostring(tryCount))

  local data = string.format("%s%d%s", padLeft(zoneNo, 3, '0'), g_zones[zoneNo].partition, padLeft(pinCode, 6, '0'))
  local status = sendIntercepted("zb", "unbypassZone", errorMessage, data)
  if (not status) then
    task(errorMessage, TASK_ERROR)
    return false
  end

  local status = readBypassRequestResponse()
  debug("unbypassZone: status=" .. tostring(status))
  if (not status) then
    log("unbypassZone: ERROR: " .. errorMessage)
    task(errorMessage, TASK_ERROR)
    return false
  elseif (status == "IC") then
    log("unbypassZone: ERROR: Invalid PIN or user.")
    task("Invalid PIN or User code.", TASK_ERROR)
    return false
  elseif (status == "unbypassed") then
    debug("unbypassZone: SUCCESS: Unbypass successful.")
    return true
  end

  tryCount = (tryCount or 0) + 1
  if (tryCount >= MAX_RETRIES) then
    log("unbypassZone: ERROR: " .. errorMessage)
    task(errorMessage, TASK_ERROR)
    return false
  end

  debug("unbypassZone: Unbypass failed, trying again...")
  return unbypassZone(zoneNo, pinCode, tryCount)
end



local function bypassZone (zoneNo, pinCode, tryCount)
  local errorMessage = string.format("Failed to bypass zone %d.", zoneNo)

  debug("bypassZone: tryCount=" .. tostring(tryCount))

  local data = string.format("%s%d%s", padLeft(zoneNo, 3, '0'), g_zones[zoneNo].partition, padLeft(pinCode, 6, '0'))
  local status = sendIntercepted("zb", "bypassZone", errorMessage, data)
  if (not status) then
    task(errorMessage, TASK_ERROR)
    return false
  end

  local status = readBypassRequestResponse()
  debug("bypassZone: status=" .. tostring(status))
  if (not status) then
    log("bypassZone: ERROR: " .. errorMessage)
    task(errorMessage, TASK_ERROR)
    return false
  elseif (status == "IC") then
    log("bypassZone: ERROR: Invalid PIN or user.")
    task("Invalid PIN or User code.", TASK_ERROR)
    return false
  elseif (status == "bypassed") then
    debug("bypassZone: SUCCESS: Bypass successful.")
    return true
  end

  tryCount = (tryCount or 0) + 1
  if (tryCount >= MAX_RETRIES) then
    log("bypassZone: ERROR: " .. errorMessage)
    task(errorMessage, TASK_ERROR)
    return false
  end

  debug("bypassZone: Bypass failed, trying again...")
  return bypassZone(zoneNo, pinCode, tryCount)
end

function setArmed (device, newArmedValue)
  debug("setArmed: Device = "..device..", newArmedValue = "..newArmedValue)
  local zoneNo = luup.devices[device].id:match("^elk_zone_(%d+)$")
  if (not zoneNo) then
    log("setArmed: ERROR: Found unexpected child.")
    task("Found unexpected child device.", TASK_ERROR)
    return false
  end

  zoneNo = tonumber(zoneNo, 10)
  local pinCode = g_pinCodes[g_zones[zoneNo].partition]
  if (not pinCode) then
    log("setArmed: ERROR: Pin code required.")
    task("Pin code required.", TASK_ERROR)
    return false
  end

  if (newArmedValue == "0") then
    return bypassZone(zoneNo, pinCode)
  else
    return unbypassZone(zoneNo, pinCode)
  end
end



function activateTask (taskNo)
  debug("activateTask: Activate task " .. taskNo .. ".")
  if (sendCommand("tn", padLeft(taskNo, 3)) ~= false) then
    task("Activate ELK/NESS task ".. taskNo .. " " .. g_tasks[taskNo].label..".", TASK_ERROR)
    return
  else
    log("activateTask: Failed to activate task " .. taskNo ..".")
    task("Error sending command.", TASK_ERROR)
    return
  end
end



function toggleOutput(device, newTargetValue)
  local outputNo = luup.devices[device].id:match("^elk_output_(%d+)")
  if (outputNo == nil) then
    debug("toggleOutput: ERROR: Invalid control output. The altid of device ".. device .." is '".. luup.devices[device].id .."'.")
    task("Error sending command.", TASK_ERROR)
    return
  end

  if (not sendCommand("ct", padLeft(outputNo, 3))) then
    task("Error sending command.", TASK_ERROR)
  end
end



function setTarget (device, newTargetValue)
  local deviceId, deviceNo = luup.devices[device].id:match("^(elk_%a+_)(%d+)")
  local command, status
  local activeSeconds = ""

  if (deviceId == nil or deviceNo == nil) then
    debug("setTarget: ERROR: Invalid control output/task number/plc unit. The altid of device ".. device .." is '".. luup.devices[device].id .."'.")
    return false
  end

  debug("setTarget: Turn ".. ((newTargetValue == "1") and "on" or "off") .." control output/task/plc ".. deviceNo .." (device ".. device ..").")

  if deviceId == 'elk_output_' then
    command = (newTargetValue == "1") and "cn" or "cf"
    data = padLeft(deviceNo, 3) .. ((newTargetValue == "1") and padLeft((luup.variable_get(SWP_SID,"timeOutputActive",device) or "0"),5)  or "")
  elseif deviceId == 'elk_task_' then
  	command = "tn"
    data = padLeft(deviceNo, 3)
  elseif deviceId == 'elk_plc_' then
    local houseCodeTable = {'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P'}
    hexString = string.format("%02X",deviceNo-1)
    houseCode = houseCodeTable[(tonumber(hexString:sub(1,1),16)+1)]
    unitCode = string.format("%02i",(tonumber(hexString:sub(2,2),16)+1))
    command = (newTargetValue == "1") and "pn" or "pf"
    data = houseCode ..unitCode
  else
    debug("setTarget: ERROR: Invalid device ID. The altid of device ".. device .." is '".. luup.devices[device].id .."'.")
    return false
  end

  status = sendCommand(command, data)
  if (not status) then
    debug("setTarget: ERROR: Could not send command.")
  end

end

local function speak(device, MessageType, message)
  debug("speak: System Word Messages")
  MessageType = MessageType:lower()
  local command = ""
  if(MessageType == "word") then
    command = "sw"
  elseif(MessageType == "phrase") then
    command = "sp"
  else
    return false
  end
  for msg in string.gmatch(message, "%d+") do
  	if (sendCommand(command, padLeft(msg, 3)) ~= false) then
    	task("System Word Messages ".. MessageType .. " " .. msg..".", TASK_ERROR)
  	else
    	debug(string.format("speak: System Word Messages"))
    	task("Error sending command.", TASK_ERROR)
    	return false
  	end
  end
  return true
end

function setModeTarget (device, newModeTarget)

  local tnum = luup.devices[device].id:match("^elk_tstat_(%d+)")

  if (tnum == nil) then
    log("setModeTarget: ERROR: Invalid thermostat number. The altid of device ".. device .." is '".. luup.devices[device].id .."'.")
    task("Error sending command.", TASK_ERROR)
    return
  end

  debug("setModeTarget: Set thermostat ".. tnum .." (device ".. device ..") mode to '".. newModeTarget .."'.")

  if (newModeTarget == "Off") then
    newModeTarget = "00"
  elseif (newModeTarget == "HeatOn") then
    newModeTarget = "01"
  elseif (newModeTarget == "CoolOn") then
    newModeTarget = "02"
  elseif (newModeTarget == "AutoChangeOver") then
    newModeTarget = "03"
  else
    log("setModeTarget: Unsupported mode '".. newModeTarget .."'.")
    task("Unsupported mode '".. newModeTarget .."'.", TASK_ERROR)
    return
  end

  -- Last parameter is 0, which means 'Mode'.
  local data = padLeft(tnum) .. newModeTarget .. "0"
  if (sendCommand("ts", data) == false) then
    task("Error sending command.", TASK_ERROR)
  end
end



function setFanMode (device, newMode)

  local tnum = luup.devices[device].id:match("^elk_tstat_(%d+)")
  if (tnum == nil) then
    log("setFanMode: ERROR: Invalid thermostat number. The altid of device ".. device .." is '".. luup.devices[device].id .."'.")
    task("Error sending command.", TASK_ERROR)
    return
  end

  debug("setFanMode: Set thermostat ".. tnum .." (device ".. device ..") fan mode to '".. newMode .."'.")

  if (newMode == "Auto") then
    newMode = "00"
  elseif (newMode == "ContinuousOn") then
    newMode = "01"
  else
    log("setFanMode: Unsupported fan mode '".. newMode .."'.")
    task("Unsupported fan mode '".. newMode .."'.", TASK_ERROR)
    return
  end

  -- Last parameter is 2, which means 'Fan'.
  local data = padLeft(tnum) .. newMode .. "2"
  if (sendCommand("ts", data) == false) then
    task("Error sending command.", TASK_ERROR)
  end
end



function setThermostatSetpoint (device, setpointType, newCurrentSetpoint)

  local tnum = luup.devices[device].id:match("^elk_tstat_(%d+)")
  if (tnum == nil) then
    log("setFanMode: ERROR: Invalid thermostat number. The altid of device ".. device .." is '".. luup.devices[device].id .."'.")
    task("Error sending command.", TASK_ERROR)
    return
  end

  debug("setFanMode: Set thermostat ".. tnum .." (device ".. device ..") ".. setpointType .." setpoint to ".. newCurrentSetpoint ..".")

  newCurrentSetpoint = tonumber(newCurrentSetpoint, 10)
  if (newCurrentSetpoint < 0) then
    newCurrentSetpoint = 0
  elseif (newCurrentSetpoint > 99) then
    newCurrentSetpoint = 99
  end

  -- Last parameter is 4/5, which means 'Cool/Heat Setpoint'.
  local data = padLeft(tnum) .. padLeft(newCurrentSetpoint) .. ((setpointType == "cool") and "4" or "5")
  if (sendCommand("ts", data) == false) then
    task("Error sending command.", TASK_ERROR)
  end
end

-- Cycle through all the thermostats and poll them.
function pollNextThermostat()
  g_nextThermostat = next(g_thermostats, g_nextThermostat)
  if (g_nextThermostat == nil) then
    g_nextThermostat = next(g_thermostats, g_nextThermostat)
  end

  local lastUpdate = luup.variable_get(HADEVICE_SID, "LastUpdate", g_thermostats[g_nextThermostat].devId) or 0
  if (os.time() - lastUpdate > POLL_MIN_DELAY) then
    sendCommand("tr", padLeft(g_nextThermostat))
  end

  luup.call_delay("pollNextThermostat", POLL_FREQUENCY)
end



function display(lul_device, lul_settings)
  local functionName = "Display text"
  local errorMessage = "Failed"
  --Keypad Area, 1 to 8
  local KeypadArea = (tonumber(lul_settings.KeypadArea)) or 1
  KeypadArea = (KeypadArea >= 1 and KeypadArea <= 8) and KeypadArea or 1
 
  --Clear, 0=clear message, 1=clear message with * key, 2=Display until timeout
  local Clear = (tonumber(lul_settings.Clear)) or 1
  Clear = (Clear >= 0 and Clear <= 2) and Clear or 1
 
  --Beep Keypad, 0=no beep, 1=beep
  local Beep = (tonumber(lul_settings.Beep)) or 1
  Beep = (Beep == 0) and Beep or 1
    
  --TTTTT - Display time in decimal seconds, 0=No timeout, 1 - 65535 seconds
   local DisplayTime = tonumber(lul_settings.DisplayTime) or 0
   DisplayTime = (DisplayTime >= 0 and DisplayTime <= 65535) and DisplayTime or 0
   DisplayTime = padLeft(DisplayTime,5)
   
  --L1 16 ASCII characters for first line
  --L2 16 ASCII characters for second line, alternately scrolled with first line
  local L1 = trim(lul_settings.L1 or "")
  local L2 = trim(lul_settings.L2 or "")
  L1 = (#L1 < 16) and padRight((L1 .. "^"), 16) or L1:sub(1,16)
  L2 = (#L2 < 16) and padRight((L2 .. "^"), 16) or L2:sub(1,16)
  sendCommand('dm', KeypadArea .. Clear .. Beep .. DisplayTime .. L1 .. L2)
end

local function functionKey(device, lul_settings)
  local functionName = "function key press"
  local errorMessage = "No keypad associated with partition"
  local key = lul_settings.FunctionKeyNo
  local partitionNo = tonumber(luup.devices[device].id:match("^elk_partition_(%d+)"))

  for k,v in ipairs(g_keypads) do
    --Get first keypad associated with partition.
    if (v.partition == partitionNo) then
      debug(functionName .. ": Function Key:" .. key .. " Partition:" .. partitionNo .. " Keypad:" .. k .. ".")
      local keypad = padLeft(k,2)
      sendCommand('kf', keypad .. key )
      return true
    end
  end
  debug(functionName .. ":" .. errorMessage .. " with partition " .. (partitionNo or "") .. ".")
end

local function changeCounter(counter, value)
 debug("This is a stub")
end
----------------------------------------------------------------------------------------------------------------
-- Initialization Functions
----------------------------------------------------------------------------------------------------------------
local function autoConfig()
  local socket = require "socket"
  local udp = socket.udp()
  local broadcast_ip = '255.255.255.255'
  local port = 2362
  local hello = 'XEPID'
  local remotePort = ''

  udp:setoption('broadcast', true)
  udp:settimeout(4)
  udp:sendto(hello, broadcast_ip, port)
  local response, remoteIP, _port = udp:receivefrom()

  if(response ~= nil) then
    if(response:match("^M1XEP*") == "M1XEP") then
	    for i = 17,16,-1 do
		    remotePort = string.format("%02X",response:byte(i)) .. remotePort
	    end
	    remotePort = tonumber(remotePort,16)
      return remoteIP
    end
    return false
  end
end



local function uiVersionCheck()
  local ui7Check = luup.variable_get(ELK_SID, "UI7Check", elk_device) or ""
  debug("uiVersionCheck:Version:" .. ui7Check ..".")
	
	if ui7Check == "" then
		luup.variable_set(ELK_SID, "UI7Check", "false", elk_device)
		ui7Check = "false"
	end
	
	if( luup.version_branch == 1 and luup.version_major == 7 and ui7Check == "false") then
		luup.variable_set(ELK_SID, "UI7Check", "true", elk_device)
		for k, v in pairs(g_partitions) do
	    luup.attr_set("device_json", "D_ElkAlarmPartition1_UI7.json", g_partitions[k].devId)
	    debug("Setting partition " .. k .. " with static json file for UI7.")
	  end
		luup.attr_set("device_json", "D_ElkAlarmPanel1_UI7.json", elk_device)
		debug("Setting ELK/NESS panel device " .. elk_device .. " with static json file for UI7.")
		luup.reload()
	end
end



local function checkConnectionType()
  ip = (luup.devices[elk_device].ip or "")

  if (ip == "") then
    debug("checkConnectionType: No IP address trying auto configuration")
    ip = autoConfig()
  end

  if (not ip or ip == "") then
    log("checkConnectionType: Running on Serial.")
  else
    local ipAddress, port = ip:match("^([^:]+):?(%d-)$")
    if (ipAddress and ipAddress ~= "") then
      if (not port or port == "") then
        port = 2101
      else
        port = tonumber(port, 10)
      end
      debug("checkConnectionType: ipAddress = "..(ipAddress or "nil")..", port = "..(port or "nil")..".")
      log("checkConnectionType: Running on Ethernet.")
      luup.io.open(elk_device, ipAddress, port)
    end
  end

  if( luup.io.is_connected(elk_device)==false ) then
    debug("checkConnectionType: Alarm panel is not connected.")
    return false
  end

  return true
end



local function getVersion()
  local functionName = "getVersion"
  local errorMessage = "Failed to get version."

  local status = sendIntercepted("vn", functionName, errorMessage)
  if (status) then
    return readResponse("VN", functionName, errorMessage)
  end

  return false
end



local function getDebugMode()
  local debugMode = luup.variable_get(ELK_SID, "DebugMode", elk_device) or ""
  if (debugMode ~= "") then
    DEBUG_MODE = (debugMode == "1") and true or false
  else
    luup.variable_set(ELK_SID, "DebugMode", (DEBUG_MODE and "1" or "0"), elk_device)
  end
  log("getDebugMode: Debug mode "..(DEBUG_MODE and "enabled" or "disabled")..".")
end

local function get_device_type (zoneNo)
  local alarmType = g_zones[zoneNo].alarmtype or ""
  if (ZONE_DEFINITIONS[alarmType]) then
    local alarm_desc = ZONE_DEFINITIONS[alarmType].discription or ""
    local device_type = ZONE_DEFINITIONS[alarmType].deviceType or ""
    ZONE_DEVICE[device_type].alarmtype = alarm_desc
    return ZONE_DEVICE[device_type]
  else
    return false
  end
end



local function getZoneType()
  for k, v in pairs(g_zones) do
	  local id = g_zones[k].devId or "none"
	  local alarmType = g_zones[k].alarmtype or ""
    debug("getZoneType: Getting type for zone "..id.. " with alarm type " .. alarmType .. ".")
    luup.variable_set(ELK_SID, "zone_type",(ZONE_DEFINITIONS[alarmType].discription or ""), id)
  end
end


local function getZoneStatuses()
  local functionName = "getZoneStatuses"
  local errorMessage = "Failed to get zone statuses."
  local status = sendIntercepted("zs", functionName, errorMessage)

  if (status) then
    return readResponse("ZS", functionName, errorMessage)
  end
  return false
end



local function getZoneNames()
  local functionName = "getZoneNames"
  local errorMessage = "Failed to get zone names."

  for i in pairs(g_zones) do
    local status = sendIntercepted("sd", functionName, errorMessage, string.format("00%03d", i))
    if (status) then
      status = readResponse("SD", functionName, errorMessage)
      if (not status) then
        return false
      end
    end
  end

  return true
end



local function getPartitionNames()
  local functionName = "getPartitionNames"
  local errorMessage = "Failed to get partition names."

  for i in pairs(g_partitions) do
    local status = sendIntercepted("sd", functionName, errorMessage, string.format("01%03d", i))
    if (status) then
      status = readResponse("SD", functionName, errorMessage)
      if (not status) then
        return false
      end
    end
  end

  return true
end

local function getZonesAndPartitions()
  local functionName = "getZonesAndPartitions"

  -- Get zone information.
  local errorMessage = "Failed to get zones."
  local status = sendIntercepted("zd", functionName, errorMessage)
  if (not status) then
    return false
  end

  status = readResponse("ZD", functionName, errorMessage)
  if (not status) then
    return false
  end

  -- Get partition information.
  errorMessage = "Failed to get partitions."
  status = sendIntercepted("zp", functionName, errorMessage)
  if (status) then
    return readResponse("ZP", functionName, errorMessage)
  end

  return false
end



local function createUsers()
  local functionName = "createUsers"
  local errorMessage = "Failed to create user"



  local i = 1
  while (i >=1 and i <=199) do
    local status = sendIntercepted("sd", functionName, errorMessage, string.format("02%03d", i))
    if (status) then
      status, data = readResponse("SD", functionName, errorMessage .. " " .. i)
      if (not status) then
        return false
      end

      data = data:gsub("(%s+)$", "")

      if (data:sub(6,13) == string.format("USER %03i",i)) then
        debug("createUsers: Completed.")
        return true
      end

      local labelId = data:sub(1, 2)
      local label = data:sub(6)
      debug("createUsers: Creating user ".. i ..".")

      g_users[i] = {}
      debug(string.format("createUsers: Adding name %s to user %03i.",label,i))
      g_users[i].label = label
    end
    i=i+1
  end

  return true
end




local function createTasks()
  local functionName = "createTasks"
  local errorMessage = "Failed to create task"

  local i = 1
  while (i >=1 and i <=32) do
    local status = sendIntercepted("sd", functionName, errorMessage, string.format("05%03d", i))
    if (status) then
      status, data = readResponse("SD", functionName, errorMessage .. " " .. i)
      if (not status) then
        return false
      end

      data = data:gsub("(%s+)$", "")
      local labelId = data:sub(1, 2)
      i = tonumber(data:sub(3,5))
      if i == 0 then
        debug("createTasks: Completed.")
        return true
      end
      debug("createTasks: Creating task ".. i ..".")
      g_tasks[i] = {}
      local label = (data:sub(6) or "")
      debug(string.format("createTasks: Adding name %s to task %03i.",label,i))
      g_tasks[i].label = label
    end
    i=i+1
  end

  return true
end



local function createOutputs()
  local functionName = "createOutputs"
  local errorMessage = "Failed to create output"

  local i = 1
  while (i >=1 and i <=64) do
    local status = sendIntercepted("sd", functionName, errorMessage, string.format("04%03d", i))
    if (status) then
      status, data = readResponse("SD", functionName, errorMessage .. " " .. i)
      if (not status) then
        return false
      end

      data = data:gsub("(%s+)$", "")
      local labelId = data:sub(1, 2)
      i = tonumber(data:sub(3,5))
      if i == 0 then
        debug("createOutputs: Completed.")
        return true
      end
      debug("createOutputs: Creating output ".. i ..".")
      g_outputs[i] = {}
      local label = (data:sub(6) or "")
      debug(string.format("createOutputs: Adding name %s to output %03i.",label,i))
      g_outputs[i].label = label
    end
    i=i+1
  end

  return true
end



local function getOutputs()
   -- OutputControls is a list of CSV for outputs from 65-208
  local outputs = luup.variable_get(ELK_SID, "OutputControls", elk_device) or ""
  if (outputs == "") then
    luup.variable_set(ELK_SID, "OutputControls", "none", elk_device)
    log("(ElkPlugin::getOutputs) No output controls.")
    return
  elseif (outputs == "none") then
    log("(ElkPlugin::getOutputs) No output controls.")  
    return
  end

  for outputNo in outputs:gmatch("%d+") do
    debug("getOutputs: Creating output ".. outputNo ..".")
    outputNo = tonumber(outputNo)
    g_outputs[outputNo] = {}
      local label = "Output "..outputNo
      debug(string.format("createOutputs: Adding name %s to output %03i.",label,outputNo))
      g_outputs[outputNo].label = label
  end
end



local function createThermostats()
  local functionName = "createThermostats"
  local errorMessage = "Failed to create thermostats"

  local i = 1
  while (i >=1 and i <=16) do
    local status = sendIntercepted("sd", functionName, errorMessage, string.format("11%03d", i))
    if (status) then
      status, data = readResponse("SD", functionName, errorMessage .. " " .. i)
      if (not status) then
        return false
      end

      data = data:gsub("(%s+)$", "")
      local labelId = data:sub(1, 2)
      i = tonumber(data:sub(3,5))
      if i == 0 then
        debug("createThermostats: Completed.")
        return true
      end
      debug("createThermostats: Creating thermostat ".. i ..".")
      g_thermostats[i] = {}
      local label = (data:sub(6) or "")
      debug(string.format("(createThermostats: Adding name %s to thermostat %03i.",label,i))
      g_thermostats[i].label = label
    end
    i=i+1
  end

  return true
end



local function getThermostatData(i)
  local functionName = "getThermostatData"
  local errorMessage = "Failed to get temperature data for thermostat #".. i .."."
  local status = sendIntercepted("tr", functionName, errorMessage, padLeft(i))
  if (status) then
    return readResponse("TR", functionName, errorMessage)
  end
  return false
end

local function createKeypads()
  local functionName = "createKeypads"
  local errorMessage = "Failed to create keypad"

  local i = 1
  while (i >=1 and i <=8) do
    local status = sendIntercepted("sd", functionName, errorMessage, string.format("03%03d", i))
    if (status) then
      status, data = readResponse("SD", functionName, errorMessage .. " " .. i)
      if (not status) then
        return false
      end

      data = data:gsub("(%s+)$", "")
      local labelId = data:sub(1, 2)
      i = tonumber(data:sub(3,5))
      if i == 0 then
        debug("createKeypads: Completed.")
        return true
      end
      debug("createKeypads: Creating output ".. i ..".")
      g_keypads[i] = {}
      local label = (data:sub(6) or "")
      debug(string.format("createKeypads: Adding name %s to keypad %03i.",label,i))
      g_keypads[i].label = label
    end
    i=i+1
  end

  return true
end



local function createCounters()
  local functionName = "createCounters"
  local errorMessage = "Failed to create Counter"

  local i = 1
  while (i >=1 and i <=64) do
    local status = sendIntercepted("sd", functionName, errorMessage, string.format("10%03d", i))
    if (status) then
      status, data = readResponse("SD", functionName, errorMessage .. " " .. i)
      if (not status) then
        return false
      end

      data = data:gsub("(%s+)$", "")
      local labelId = data:sub(1, 2)
      i = tonumber(data:sub(3,5))
      if i == 0 then
        debug("createCounters: Completed.")
        return true
      end
      debug("createCounters: Creating counter ".. i ..".")
      g_counters[i] = {}
      local label = (data:sub(6) or "")
      debug(string.format("createCounters: Adding name %s to counter at %03i.",label,i))
      g_counters[i].label = label
    end
    i=i+1
  end

  return true
end



local function createCustomValues()
  local functionName = "createCustomValues"
  local errorMessage = "Failed to create custom value"

  local i = 1
  while (i >=1 and i <=20) do
    local status = sendIntercepted("sd", functionName, errorMessage, string.format("09%03d", i))
    if (status) then
      status, data = readResponse("SD", functionName, errorMessage .. " " .. i)
      if (not status) then
        return false
      end

      data = data:gsub("(%s+)$", "")
      local labelId = data:sub(1, 2)
      local index = (tonumber(data:sub(6)) == 0) and 0 or tonumber(data:sub(3,5))

      if index ~= 0 then
        debug("createCustomValues: Creating custom  at index ".. index ..".")
        g_customs[index] = {}
        local label = (data:sub(6) or "")
        debug(string.format("createCustomValues: Adding name %s to custom at %03i.",label,index))
        g_customs[index].label = label
      end
    end
    i=i+1
  end
  debug("createCustomValues Completed.")
  return true
end

local function createLights()
  local functionName = "createLights"
  local errorMessage = "Failed to create lights"
  local i = 1
  while (i >=1 and i <=256) do
    local status = sendIntercepted("sd", functionName, errorMessage, string.format("07%03d", i))
    if (status) then
      status, data = readResponse("SD", functionName, errorMessage .. " " .. i)
      if (not status) then
        return false
      end
      
      data = data:gsub("(%s+)$", "")  
      local labelId = data:sub(1, 2)
      local index = (tonumber(data:sub(6)) == 0) and 0 or tonumber(data:sub(3,5))
    
      if index == 0 then
        debug("createLights: Completed.")
        return true
      else
        g_lights[index] = {}
        debug("createLights: Creating light at index ".. index ..".")
        local label = (data:sub(6) or "")
        debug(string.format("createLights: Adding name %s to light at %03i.",label,index))
        g_lights[index].label = label
      end
      
    end
    i=i+1
  end
end



local function appendZones (rootPtr)
  for k, v in pairs(g_zones) do
    debug("appendZones: Appending zone "..k..".")
    local device = get_device_type(k)
    luup.chdev.append(elk_device, rootPtr, device.id..k, "Zone "..k..": "..(v.label or ""), device.type, device.file, nil, nil, false)
  end
end



local function appendPartitions (rootPtr)
  for k, v in pairs(g_partitions) do
    debug("appendPartitions: Appending partition "..k..".")
    luup.chdev.append(elk_device, rootPtr, "elk_partition_"..k, "Partition "..k..": "..(v.label or ""), "urn:schemas-micasaverde-com:device:ElkAlarmPartition:1", "D_ElkAlarmPartition1.xml", nil, nil, false)
  end
end



local function appendOutputs (rootPtr)
  for k, v in pairs(g_outputs) do
    debug("appendOutputs: Appending output "..k..".")
    luup.chdev.append(elk_device, rootPtr, "elk_output_".. k, "Elk Output "..k..": "..(v.label or ""), DEVICETYPE_LIGHT, DEVICEFILE_LIGHT, "", false, false)
  end
end


local function appendTasks (rootPtr)
  for k, v in pairs(g_tasks) do
    debug("appendTasks: Appending task "..k..".")
    luup.chdev.append(elk_device, rootPtr, "elk_task_".. k, "Elk Task "..k..": "..(v.label or ""), DEVICETYPE_LIGHT, DEVICEFILE_LIGHT, "", false, false)
  end
end



local function appendKeypadSensors(rootPtr)
  for k, v in pairs(g_tempSensors) do
    if (k <= 16) then
      debug("appendKeypadSensors: Appending keypad sensor "..k..".")
      luup.chdev.append(elk_device, rootPtr, "elk_keypad_sensor_".. k, "Elk Keypad Sensor "..k..": "..(v.label or ""), "urn:schemas-micasaverde-com:device:TemperatureSensor:1", "D_TemperatureSensor1.xml", "", false, false)
    end
  end
end



local function appendThermostats (rootPtr)
  for k, v in pairs(g_thermostats) do
    debug("appendThermostats: Appending thermostat "..k..".")
    local commands = "hvac_off,hvac_auto,hvac_cool,hvac_heat,heating_setpoint,cooling_setpoint,fan_auto,fan_on"
    local parameters = HADEVICE_SID ..",Commands=".. commands
    luup.chdev.append(elk_device, rootPtr, "elk_tstat_".. k, "Thermostat ".. k..": "..(v.label or ""), "urn:schemas-upnp-org:device:HVAC_ZoneThermostat:1", "D_HVAC_ZoneThermostat1.xml", "", parameters, false, false)
  end
end



local function appendLights (rootPtr)
  for k, v in pairs(g_lights) do
    debug("appendLights: Appending light "..k..".")
    luup.chdev.append(elk_device, rootPtr, "elk_plc_".. k, "PLC ".. k ..": "..(v.label or ""), DEVICETYPE_LIGHT, DEVICEFILE_LIGHT, "", false, false)
  end
end


local function addLuupDevice()
  for dev, attr in pairs(luup.devices) do
    if (attr.device_num_parent == elk_device) then

      local zoneNo = attr.id:match("^elk_zone_(%d+)") or attr.id:match("^elk_temp_(%d+)")
      local partitionNo = attr.id:match("^elk_partition_(%d+)")
      local outputNo = attr.id:match("^elk_output_(%d+)")
      local taskNo = attr.id:match("^elk_task_(%d+)")
      local sensorNo = attr.id:match("elk_temp_(%d+)") or attr.id:match("elk_keypad_sensor_(%d+)")
      local thermostatNo = attr.id:match("elk_tstat_(%d+)")
      local plcNo = attr.id:match("elk_plc_(%d+)")

      if (zoneNo ~= nil) then
        zoneNo = tonumber(zoneNo, 10)
        debug("addLuupDevice: adding device id "..dev.." to zone "..zoneNo ..".")
        local lastTrip = luup.variable_get(SES_SID, "LastTrip", dev) or ""
        if (lastTrip == "") then
          luup.variable_set(SES_SID, "LastTrip","0",dev)
        end
        g_zones[zoneNo].devId = dev

      elseif (partitionNo ~= nil) then
        partitionNo = tonumber(partitionNo, 10)
        debug("addLuupDevice: adding device id "..dev.." to partition "..partitionNo ..".")
        g_partitions[partitionNo].devId = dev

      elseif (outputNo ~= nil) then
        outputNo = tonumber(outputNo, 10)
        debug("addLuupDevice: adding device id "..dev.." to output "..outputNo ..".")
        if (luup.variable_get(SWP_SID,"timeOutputActive",dev) == nil) then
          luup.variable_set(SWP_SID,"timeOutputActive","0",dev)
        end
        if (g_outputs[outputNo] ~= nil) then
          g_outputs[outputNo].devId = dev
        end

      elseif(taskNo ~= nil) then
        taskNo = tonumber(taskNo, 10)
        debug("addLuupDevice: adding device id "..dev.." to task "..taskNo ..".")
        if (g_tasks[taskNo] ~= nil) then
          g_tasks[taskNo].devId = dev
        end

      elseif(sensorNo ~= nil) then
        sensorNo = ("elk_temp_" == attr.id:match("^elk_temp_")) and (tonumber(sensorNo, 10)+16) or (tonumber(sensorNo, 10))
        debug("addLuupDevice: adding device id "..dev.." to sensor "..sensorNo ..".")
        g_tempSensors[sensorNo].devId = dev

      elseif (thermostatNo ~= nil) then
        thermostatNo = tonumber( thermostatNo, 10)
        debug("addLuupDevice: adding device id "..dev.." to thermostat "..thermostatNo..".")
        g_thermostats[thermostatNo].devId = dev
        if (g_thermostats[thermostatNo] ~= nil) then
          g_thermostats[thermostatNo].devId = dev
        end

      elseif(plcNo ~= nil) then
        plcNo = tonumber(plcNo, 10)
        debug("addLuupDevice: adding device id "..dev.." to PLC Unit "..plcNo..".")
        g_lights[plcNo].devId = dev

      end



    end
  end
end

local function getChimeModes()
  local functionName = "getChimeModes"
  local errorMessage = "Failed to get chime modes."

  for i in pairs(g_keypads) do
    local status = sendIntercepted("kf", functionName, errorMessage,padLeft(i,2).."0")
    if (status) then
      status = readResponse("KF", functionName, errorMessage)
      if (not status) then
        return false
      end
    end
  end

  return true
end



local function getPartitionStatuses()
  local functionName = "getPartitionStatuses"
  local errorMessage = "Failed to get partition statuses."

  local status = sendIntercepted("as", functionName, errorMessage)
  if (status) then
    return readResponse("AS", functionName, errorMessage)
  end

  return false
 end



local function getKeypadPartAssign()
  local functionName = "getKeypadPartAssign"
  local errorMessage = "Failed to get partition assignment for keypads"

  local status = sendIntercepted("ka", functionName, errorMessage)
  if (status) then
    return readResponse("KA", functionName, errorMessage)
  end

  return false
end


local function getTempSensors()
  local functionName = "getTempSensors"
  local errorMessage = "Failed to get temperature data for keypads and zones."

  local status = sendIntercepted("lw", functionName, errorMessage)
  if (status) then
    return readResponse("LW", functionName, errorMessage)
  end

  return false
end



local function getOutputStatus()
  local functionName = "getOutputStatus"
  local errorMessage = "Failed to update the output controls."

  local status = sendIntercepted("cs", functionName, errorMessage)
  if (status) then
    return readResponse("CS", functionName, errorMessage)
  end

  return false
end



local function setStatusTasks ()
  for taskNo, attr in pairs(g_tasks) do
    local device = g_tasks[taskNo].devId
    luup.variable_set(SWP_SID, "Status", "0",  device)
    debug("setStatusTasks: Task ".. taskNo .." set to off (device " .. device .. ").")
  end

  return true
end


function getTroubleReport()
  local functionName = "getTroubleReport"
  local errorMessage = "Failed to update the system trouble status."

  local status = sendIntercepted("ss", functionName, errorMessage)
  if (status) then
    return readResponse("SS", functionName, errorMessage)
  end

  return false
end



local function getCounters()
  local functionName = "getCounters"
  local errorMessage = "Failed to get counters."

  for i in pairs(g_counters) do
    local status = sendIntercepted("cv", functionName, errorMessage,padLeft(i,2).."0")
    if (status) then
      status = readResponse("CV", functionName, errorMessage)
      if (not status) then
        return false
      end
    end
  end

  return true
end



local function getCustomValues()
  local functionName = "getCustomValues"
  local errorMessage = "Failed to get custom values."

    local status = sendIntercepted("cp", functionName, errorMessage)
    if (status) then
      status = readResponse("CR", functionName, errorMessage)
      if (not status) then
        return false
      end
    end

  return true
end



-------------------------------------------------------------------------------
--Testing
-------------------------------------------------------------------------------
function setElkRTC(device, time)
  local functionName = "setRTC"
  local errorMessage = "Failed to set real time clock."

  time = (tonumber(time))/1000
  wd =  os.date("%w",time)+1
  yy =  os.date("%Y",time):sub(3,4)
  time = (os.date("%S%M%H" .. wd ..  "%d%m" .. yy,time))

  local status = sendIntercepted("rw", functionName, errorMessage, time)

  if (status) then
    debug("systemLog: setting elk rtc " .. time .. ".")
    readResponse("RR", functionName, errorMessage)
    return luup.variable_get(ELK_SID, "ElkRTC", elk_device)
  end

  return false
end



function getEventJob(lul_device, LogStart, lul_job )

  LogStart = (LogStart ~= nil) and tonumber(LogStart) or 1
  local LogEnd = 20

  if (LogStart > 1 and LogStart <=511) then
    LogEnd = ((LogStart+19) <= 511) and (LogStart+19) or 511
  end

  if LogStart > 511 then return false end

  debug("systemLog: getting settings " .. LogStart.." to "..LogEnd)
  g_logFile = {}

  for i=LogStart,LogEnd do
    luup.sleep(150)
    debug("systemLog: getting log event " .. i .. ".")
    if (sendCommand ("ld", padLeft(i,3)) ~= false) then
    else
      log("systemLog: Failed to get log event " .. i ..".")
    end
  end
    return
end



function incomingGetLog(lul_device, LogStart, lul_job, lul_data)
  local command = lul_data:sub(3,4)

  if(command == "LD") then
    local incomingLogNumber = tonumber(lul_data:sub(21,23))
    LogStart = (LogStart~= nil) and tonumber(LogStart) or 1
    local LogEnd = 20
    if (incomingLogNumber > 1 and incomingLogNumber <=511) then
      LogEnd = ((LogStart+19) <= 511) and (LogStart+19) or 511
    end
    debug("incomingJobHandler: processing event " .. incomingLogNumber.." of "..LogEnd .. ".")
    if(incomingLogNumber < LogEnd) then
      return 5, 10, processMessage (lul_data, msgType, lul_job, lul_device)
    elseif(incomingLogNumber >= LogEnd) then
      debug("incomingJobHandler: getting last event, job finished.")
      return 4, nil, processMessage (lul_data, msgType, lul_job, lul_device)
    end

  end
  return 5, 10, false
end



function tablePrint(table)
  local counterString = "["
  for k1, v1 in pairs(table) do
    counterString = counterString .. "{\"index\":" .. "\"" ..  string.format("%03i",k1) .. "\","
    if(type(v1) == "table") then
      for k2, v2 in pairs(v1) do
        counterString = counterString .. "\"" .. k2 .. "\": \"" .. v2 .. "\","
      end
      counterString = counterString:sub(1,-2) .. "},"
    end
  end
  counterString = (counterString:sub(1,-2):len() == 0) and counterString .. "]" or counterString:sub(1,-2) .. "]"
  return counterString
end



function callbackHandler(lul_request, lul_parameters, lul_outputformat)
  local functionName = "callbackHandler"

  if (lul_request == "ElkEvent" and lul_outputformat == "json") then
    return "[" .. table.concat(g_logFile,",") .. "]"
  elseif (lul_request == "ElkRTC" and lul_outputformat == "json") then
    local errorMessage = "Failed to request real time clock."
    local status = sendIntercepted("rr", functionName, errorMessage)
    if (status) then
      readResponse("RR", functionName, errorMessage)
      return luup.variable_get(ELK_SID, "ElkRTC", elk_device)
    end
    return errorMessage
  elseif (lul_request == "ElkCounters" and lul_outputformat == "json") then
    return tablePrint(g_counters)
  elseif (lul_request == "ElkCustom" and lul_outputformat == "json") then
    return tablePrint(g_customs)
  else
    debug("callbackHandler:" .. tostring(lul_outputformat) .. " currently not supported.")
    return tostring(lul_outputformat) .." currently not supported."
  end

end



function getHeartbeat()
  luup.call_timer("getHeartbeat", 1, "5m", "", "")
  local heartbeat = (os.difftime(os.time(), HEARTBEAT) or 0)
  debug("getHeartbeat: OK " .. heartbeat .. " sec since last ping.", 1)
  local lastHeartbeat = tonumber(luup.variable_get(ELK_SID, "Heartbeat", elk_device),  10) or 0
  if heartbeat > 300 then
    if (not luup.io.is_connected(elk_device)) then
      debug( "io failure - Panel no longer connected, attempting to reconnect")
      local status = checkConnectionType()
      if (status == true) then
        debug( "Re-connect attempt successful")
        luup.set_failure(false,elk_device)
        clearStatusMessage()
      end
    else
      log("getHeartbeat: ERROR: Communications lost.")
      local message = "Communications lost"
      task(message, TASK_ERROR_PERM)
      --luup.set_failure(true,elk_device)
    end
  elseif (heartbeat < 300 and lastHeartbeat > 300) then
    luup.set_failure(false,elk_device)
    clearStatusMessage()
  end
  luup.variable_set(ELK_SID, "Heartbeat", heartbeat, elk_device)
  return
end



function setCounter(device, counter, value)
  local functionName = "setCounter"
  local errorMessage = "Failed to set counter."
  counter = tonumber(counter)
  value = tonumber(value)
  if(counter >= 1 and counter <= 64 and value >= 0 and value <= 65535) then
    local counterValue = padLeft(counter,2)..padLeft(value,5)
    local status = sendIntercepted("cx", functionName, errorMessage, counterValue)
    if (status) then
      debug(string.format("setCounter: setting elk counter %i to value %i.",counter,value))
      readResponse("CV", functionName, errorMessage)
      return counter, value
    end
  end
  return false
end



function setCustom(device, custom, value)
  local functionName = "setCustom"
  local errorMessage = "Failed to set custom."
  custom = tonumber(custom)
  value = tonumber(value)
  if(custom >= 1 and custom <= 20 and value >= 0 and value <= 65535) then
    local customValue = padLeft(custom,2)..padLeft(value,5)
    local status = sendIntercepted("cw", functionName, errorMessage, customValue)
    if (status) then
      debug(string.format("setCustom: setting elk custom %i to value %i.",custom,value))
      readResponse("CR", functionName, errorMessage)
      return custom, value
    end
  end
  return false
end
-------------------------------------------------------------------------------
-- Main
-------------------------------------------------------------------------------
function elkStartup (lul_device)

  log(":M1 Panel Plugin version " .. VERSION .. ".")
  luup.variable_set(ELK_SID, "PluginVersion", VERSION, lul_device)

  g_taskHandle = luup.task("starting up...", TASK_BUSY, "Elk Alarm Panel", g_taskHandle)
  elk_device = lul_device
  luup.call_delay("clearStatusMessage", 1)

  getDebugMode()

  -- Check if the panel is connected through the USB port, or via Ethernet.
  if (not checkConnectionType()) then
    return false, "Communications error", "Elk Alarm Panel"
  else
    luup.set_failure(false, elk_device)
  end

  -- Get panel version.
  local version = commandRetry(getVersion)
  if (version) then
    log(":M1 version " .. (version or "N/A"))
    luup.variable_set(ELK_SID, "FirmwareVersion", version, lul_device)
  else
    return false, "No version returned", "Elk Alarm Panel"
  end

  getOutputs()
  createOutputs()
  createTasks()
  createUsers()
  createThermostats()
  createKeypads()
  createCounters()
  createCustomValues()
  createLights()

  -- Get all the zones and active partitions.
  if(not commandRetry(getZonesAndPartitions)) then
    return false, "No zones and partitions returned", "Elk Alarm Panel"
  end

  -- Get all connected temp sensors
  if(not commandRetry(getTempSensors)) then
    return false, "No temperature sensors returned", "Elk Alarm Panel"
  end

  -- Get all connected keypads
  if(not commandRetry(getKeypadPartAssign)) then
    return false, "No keypads returned", "Elk Alarm Panel"
  end

  -- Get names for partitions
  if(not commandRetry(getPartitionNames)) then
    return false, "No partitions returned", "Elk Alarm Panel"
  end

  -- Get names for zones
  if(not commandRetry(getZoneNames)) then
    return false, "No zones returned", "Elk Alarm Panel"
  end

  rootPtr = luup.chdev.start(lul_device)
  appendPartitions(rootPtr)
  appendZones(rootPtr)
  appendOutputs(rootPtr)
  appendTasks(rootPtr)
  appendKeypadSensors(rootPtr)
  appendThermostats(rootPtr)
  appendLights(rootPtr)
  luup.chdev.sync(lul_device, rootPtr)

  -- Get a list with the created child devices.
  addLuupDevice()
  
  uiVersionCheck()

  INITIALIZED = true

  getCounters()
  getCustomValues()

  -- Get each Partition's status.
  commandRetry(getPartitionStatuses)

  -- Get each Zone's types.
  getZoneType()

  -- Get each Zone's status.
  commandRetry(getZoneStatuses)

  -- Get the Chime Mode for each partition.
  commandRetry(getChimeModes)

  -- Get status of outputs.
  commandRetry(getOutputStatus)

  -- Set task status.
  setStatusTasks()

  -- Get each temperature from temperature sensors.
  updateTemperatureSensors()

  -- Get each temperature from thermostats.
  for thermostatNo,v in pairs(g_thermostats) do
    getThermostatData(thermostatNo)
  end

  -- Get the poll frequency and the minimum delay between polls for a device.
  POLL_MIN_DELAY = tonumber(luup.variable_get(HADEVICE_SID, "PollMinDelay", 1),  10)
  POLL_FREQUENCY = tonumber(luup.variable_get(HADEVICE_SID, "PollFrequency", 1), 10)

  HEARTBEAT = os.time()

  luup.call_delay("getTroubleReport", 5, "")
  luup.call_delay("getHeartbeat", 10, "")

  luup.register_handler("callbackHandler", "ElkEvent")
  luup.register_handler("callbackHandler", "ElkRTC")
  luup.register_handler("callbackHandler", "ElkCounters")
  luup.register_handler("callbackHandler", "ElkCustom")

  luup.set_failure(false, lul_device)
  debug("Elk Plugin Startup SUCCESS: Startup successful.")

  return true, "Startup successful.", "Elk Alarm Panel"

end


