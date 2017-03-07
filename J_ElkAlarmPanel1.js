// Device Service
var ELK_SID = "urn:micasaverde-com:serviceId:ElkAlarmPanel1";
var timerRunning = false;

MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

//local ip
ipaddress = data_request_url;

function layout()
{
  var html = "";
  html += '<!DOCTYPE html>';
  html += '<head>';
  html += '<style type="text/css">';
  html += 'div#divContainer';
  html += '{';
  html += 'max-width: 800px;';
  html += 'margin: 0 auto;';
  html += 'font-family: Calibri;';
  html += 'font-size:1em;';
  html += 'padding: 0.1em 0.1em 0.1em 0.1em;';
  //* rounded corners *//
  html += '-moz-border-radius: 10px;';
  html += '-webkit-border-radius: 10px;';
  html += 'border-radius: 10px;';
  //* add gradient *//
  html += 'background-color: #00CCEE;';
  html += 'background: -webkit-gradient(linear, left top, left bottom, from(#025CB6), to(#3295F8));';
  html += 'background: -moz-linear-gradient(top, #025CB6, #3295F8);';
  //* add box shadows *//
  html += '-moz-box-shadow: 5px 5px 10px rgba(0,0,0,0.3);';
  html += '-webkit-box-shadow: 5px 5px 10px rgba(0,0,0,0.3);';
  html += 'box-shadow: 5px 5px 10px rgba(0,0,0,0.3);';
  html += '}';
  
  //* header *//
  html += 'h1 {color:#FFE47A; font-size:1.5em;text-align:center;}';
  //* table *//
  html += 'table.formatLogPanel {';
  html += 'width: 100%;';
  html += 'border-collapse:collapse;';
  html += 'color: #606060;';
  html += '}';
  //* table's thead section, head row style *//
  html += 'table.formatLogPanel thead tr td';
  html += '{';
  html += 'background-color: White;';
  html += '}';
  //* table's thead section, coulmns header style *//
  html += 'table.formatLogPanel thead tr th';
  html += '{';
  html += 'text-align:left;';
  html += 'background-color: #808080;';
  html += 'background: -webkit-gradient(linear, left top, left bottom, from(#025CB6), to(#909090));';
  html += 'background: -moz-linear-gradient(top, #025CB6, #909090);';
  html += 'color: #dadada;';
  html += '}';
  //* table's tbody section, odd rows style *//
  html += 'table.formatLogPanel tbody tr:nth-child(odd) {';
  html += 'background-color: #fafafa;';
  html += '}';
  //* table's tbody section, even rows style *//
  html += 'table.formatLogPanel tbody tr:nth-child(even) {';
  html += 'background-color: #efefef;';
  html += '}';
  //* table's tbody section, last row style *//
  html += 'table.formatLogPanel tbody tr:last-child {';
  html += 'border-bottom: solid 1px #404040;';
  html += '}';
  //* table's tbody section, separator row pseudo-class *//
  html += 'table.formatLogPanel tbody tr.separator {';
  html += 'background-color: #808080;';
  html += 'background: -webkit-gradient(linear, left top, left bottom, from(#025CB6), to(#909090));';
  html += 'background: -moz-linear-gradient(top, #025CB6, #909090);';
  html += 'color: #dadada;';
  html += '}';
  //* table's td element, all section *//
  html += 'table.formatLogPanel td {';
  html += 'vertical-align:middle;';
  //html += 'padding: 0.5em;';
  html += '}';
  //* table's tfoot section *//
  html += 'table.formatLogPanel tfoot{';
  html += 'text-align:center;';
  html += 'color:#303030;';
  html += 'text-shadow: 0 1px 1px rgba(255,255,255,0.3);';
  html += '}';
  //* input *//
  html += 'input';
  html += '{';
  html += 'float:right;';
  html += 'width: 50px;';
  html += 'height:15px;';
  html += 'vertical-align:middle;';
  html += 'text-align: center;';
  html += '}';
  html += 'input.btn1';
  html += '{';
  html += 'width: 40px;';
  html += 'height:20px;';
  html += 'font-family: Calibri;';
  html += 'font-size: 0.95em;';
  html += 'vertical-align:middle;';
  html += 'text-align: center;';
  html += '} ';
  html += 'label';
  html += '{';
  html += 'font-family: Calibri;';
  html += 'vertical-align:middle;';
  html += 'float:left;';
  html += '} ';
  //******//
  html += '</style>';
  html += '</head>';
  html += '<body>';
  return html;
}

/**********
 * Trouble tab
 **********/
function troubleTab(device)
{
  var troubleReportList = get_device_state(device, ELK_SID, "TroubleReport", 1);
  var trouble = troubleReportList.split(';');
  var html = layout();
  //<!-- CENTTERED COLUMN ON THE PAGE-->/
  html += '<div id="divContainer">';
  html += '<h1>ELK/NESS ALARM PANEL TROUBLE</h1>';
  //<!-- HTML5 TABLE FORMATTED VIA CSS3-->
  html += '<table class="formatLogPanel" >';
  //<!-- TABLE HEADER-->
  html += '<thead>';
  html += '<tr>';
  html += '<th>TROUBLE DISCRIPTION</th>';
  html += '</tr>';
  html += '</thead>';
  //<!-- TABLE BODY: MAIN CONTENT-->
  html += '<tbody id="troubleTable" >';
  html += '</tbody>';
  //<!-- TABLE FOOTER-->
  html += '<tfoot>';
  html += '<tr><td id="status"></td></tr>';
  html += '</tfoot>';
  html += '</table>';
  html += '</div>';
  html += '</body>';
  html += '</html>';
  set_panel_html(html);
  troubleReport($('troubleTable'), trouble, device, $('status'));
}

function troubleReport(table, trouble, device, status)
{
  if (trouble.length > 0)
  {
    for (var i = 0; i < trouble.length; i++)
    {
      var row = table.insertRow(-1);
      var index = row.insertCell(0);
      index.innerHTML = trouble[i];
    }
    status.innerHTML = '<td>Completed</td>';
  }
  else
  {
    status.innerHTML = '<td>Completed - no trouble reports</td>';
  }
}


/**********
 * Event Log tab
 **********/
function logTab(device)
{
  var html = layout();
  var LogStart;
  //<!-- CENTTERED COLUMN ON THE PAGE-->/
  html += '<div id="divContainer">';
  html += '<h1>ELK/NESS ALARM PANEL LOG</h1>';
  //<!-- HTML5 TABLE FORMATTED VIA CSS3-->
  html += '<table class="formatLogPanel" id="logTableTop" >';
  //<!-- TABLE HEADER-->
  html += '<thead>';
  //html += '<tr><td colspan=4>+ + + Disclaimer + + +</td></tr>';
  html += '<tr>';
  html += '<th>INDEX</th><th>DESCRIPTION EXTENDED INFO</th><th>DATE</th><th>TIME</th>';
  html += '</tr>';
  html += '</thead>';
  html += '<tbody id="logTable" >';
  html += '</tbody>';
  //<!-- TABLE FOOTER-->
  html += '<tfoot>';
  html +=
    '<tr><td colspan=4><input id="elk_getForwardLogButton" type="submit" value="More" class="btn1" onclick="tableStatus($(\'logTable\'),' + device + ',$(\'status\'))"></input></td></tr>';
  html += '<tr><td colspan=4 id="status"></td></tr>';
  html += '</tfoot>';
  html += '</table>';
  html += '</div>';
  html += '</body>';
  html += '</html>';
  set_panel_html(html);
  scanLogEvent($('logTable'), device, LogStart, $('status'));
}

function scanLogEvent(table, device, LogStart, status)
{
  var row = table.insertRow(-1);
  status.innerHTML = '<td colspan="4">...Creating job to retrieve log...</td>';
  new Ajax.Request("../port_3480/data_request",
  {
    method: "get",
    parameters:
    {
      id: "lu_action",
      serviceId: ELK_SID,
      action: "GetEventJob",
      DeviceNum: device,
      LogStart: LogStart,
      output_format: "json"
    },
    onSuccess: function (response)
    {
      var jobId = response.responseText.evalJSON()["u:GetEventJobResponse"]["JobID"];
      if (jobId == undefined)
      {
        status.innerHTML = '<td colspan="4">...Failed to create job...</td>';
      }
      else
      {
        waitForScanLogEventJob.delay(0.5, jobId, table, row, device, status);
      }
    },
    onFailure: function ()
    {
      status.innerHTML = '<td colspan="4">...Failed to create job...</td>';
    }
  });
}

function waitForScanLogEventJob(jobId, table, row, device, status)
{
  status.innerHTML = '<td colspan="4">...Waiting for job status...</td>';
  new Ajax.Request("../port_3480/data_request",
  {
    method: "get",
    parameters:
    {
      id: "jobstatus",
      job: jobId,
      output_format: "json"
    },
    onSuccess: function (response)
    {
      var jobStatus = response.responseText.evalJSON()["status"];
      if (jobStatus === 0 || jobStatus === 1 || jobStatus === 5)
      {
        // Repeat.  Hopefully not so many times as to overflow the stack.
        status.innerHTML = '<td colspan="5">...Waiting for job status...</td>';
        waitForScanLogEventJob.delay(0.5, jobId, table, row, device, status);
      }
      else if (jobStatus == 2)
      {
        status.innerHTML = '<td colspan="4">...Failed to get job status...</td>';
      }
      else if (jobStatus == 4)
      {
        // Success.  Now get the result of the scan.
        status.innerHTML = '<td colspan="4">Successful...</td>';
        getScanLogEventResult.delay(0.5, table, row, device, status);
      }
    },
    onFailure: function ()
    {
      status.innerHTML = '<td colspan="4">...Failed to get log events...</td>';
    }
  });
}


function getScanLogEventResult(table, row, device, status)
{
  status.innerHTML = '<td colspan="4">...Getting response...</td>';
  new Ajax.Request("../port_3480/data_request",
  {
    method: "get",
    parameters:
    {
      id: "lr_ElkEvent",
      rand: Math.random(),
      output_format: "json"
    },
    onSuccess: function (response)
    {
      status.innerHTML = '<td colspan="4">...Response received...</td>';
      var Log = response.responseText.evalJSON();

      for (var i = 0; i < Log.length; i++)
      {
        html = '';
        row = table.insertRow(-1);
        var index = row.insertCell(0);
        var eventType = row.insertCell(1);
        var day = row.insertCell(2);
        var time = row.insertCell(3);
        index.innerHTML = Log[i].index;
        eventType.innerHTML = Log[i].eventType;
        day.innerHTML = Log[i].day;
        time.innerHTML = Log[i].time;
      }

      status.innerHTML = '<td colspan="4">Completed</td>';
    },
    onFailure: function ()
    {
      status.innerHTML = '<td colspan="4">...Failed to get log events...</td>';
    }

  });

}


function tableStatus(table, device, status)
{
  var i = table.rows.length - 1;
  while (typeof (table.rows[i].cells[0]) === 'undefined' && i >= 0)
  {
    i--;
  }
  index = (i === 0) ? 1 : (parseInt((table.rows[i].cells[0].innerHTML), 10)) + 1;
  scanLogEvent(table, device, index, status);
}




/**********
 * Time tab
 **********/
function timeTab(device)
{
  var html = layout();
  html += '<div id="divContainer">';
  html += '<h1>ELK/NESS ALARM PANEL RTC</h1>';
  //<!-- HTML5 TABLE FORMATTED VIA CSS3-->
  html += '<table class="formatLogPanel" >';
  //<!-- TABLE HEADER-->
  html += '<thead>';
  html += '<tr>';
  html += '<th colspan="2">REAL TIME CLOCK</th>';
  html += '</tr>';
  html += '</thead>';
  //<!-- TABLE BODY: MAIN CONTENT-->
  html += '<tbody>';
  html += '<tr>';
  //html += '<td>REAL TIME CLOCK</td>';
  html += '<td id="clockCell"></td>';
  html +=
    '<td><input id="elk_getForwardLogButton" type="submit" value="Set" class="btn1" title="Set Elk Real Time Clock from your device" onclick="setElkRTC(' + device + ',$(\'clockCell\'),$(\'status\'))"></input></td>';
  html += '</tr>';
  html += '</tbody>';
  //<!-- TABLE FOOTER-->
  html += '<tfoot>';
  html += '<tr><td colspan=2 id="status"></td></tr>';
  html += '</tfoot>';
  html += '</table>';
  html += '</div>';
  html += '</body>';
  html += '</html>';
  set_panel_html(html);
  getElkRTC(device, $('clockCell'), $('status'));
}


function showtime(time, cell, offset, status)
{
  var timeValue = '';
  var now = new Date();
  time = new Date(time);
  offset = new Date(offset === undefined ? now - time : offset);
  var elkTime = new Date(now - offset);
  var hours = elkTime.getHours();
  var minutes = elkTime.getMinutes();
  var seconds = elkTime.getSeconds();
  var date = elkTime.getDate();
  var month = MONTHS[elkTime.getMonth()];
  var year = elkTime.getFullYear();
  timeValue += date + ' ' + month + ' ' + year + ' ' + hours;
  timeValue += ((minutes < 10) ? ":0" : ":") + minutes;
  timeValue += ((seconds < 10) ? ":0" : ":") + seconds;
  cell.innerHTML = timeValue;
  setTimeout(function ()
  {
    showtime(timeValue, cell, offset);
  }, 1000);
}


function getElkRTC(device, cell, status)
{
  new Ajax.Request("../port_3480/data_request",
  {
    method: "get",
    parameters:
    {
      id: "lr_ElkRTC",
      rand: Math.random(),
      output_format: "json"
    },
    onSuccess: function (response)
    {
      var time = response.responseText;
      status.innerHTML = '<td colspan="3">Completed</td>';
      showtime(time, cell, null, status);
    },
    onFailure: function ()
    {
      status.innerHTML = '<td colspan="2">Failed to get Elk time</td>';
    }
  });
}


function setElkRTC(device, cell, status)
{
  var time = +new Date;
  new Ajax.Request("../port_3480/data_request",
  {
    method: "get",
    parameters:
    {
      id: "lu_action",
      serviceId: ELK_SID,
      action: "SetElkRTC",
      DeviceNum: device,
      Time: time,
      output_format: "json"
    },
    onSuccess: function (response)
    {
      var time = response.responseText.evalJSON();
      getElkRTC(device, cell, status);
    },
    onFailure: function () {}
  });
}

/**********
 * Counter tab
 **********/
function counterTab(device)

{
  var html = layout();

  html += '<div id="divContainer">';
  html += '<h1>ELK/NESS ALARM PANEL COUNTERS</h1>';

  //<!-- HTML5 TABLE FORMATTED VIA CSS3-->
  html += '<table class="formatLogPanel" >';

  //<!-- TABLE HEADER-->
  html += '<thead>';
  //html += '<tr><td colspan=3>+ + + Disclaimer + + +</td></tr>';
  html += '<tr>';
  html += '<th>INDEX</th><th>DESCRIPTION</th><th colspan="2">COUNTER VALUE</th>';
  html += '</tr>';
  html += '</thead>';

  //<!-- TABLE BODY: MAIN CONTENT-->
  html += '</thead>';

  html += '<tbody id="counterTable" >';

  html += '</tbody>';

  //<!-- TABLE FOOTER-->
  html += '<tfoot>';
  html += '<tr><td colspan=4 id="status"></td></tr>';
  html += '</tfoot>';
  html += '</table>';

  html += '</div>';
  html += '</body>';
  html += '</html>';

  set_panel_html(html);

  getCounters($('counterTable'), device, $('status'));
}

function getCounters(table, device, status)
{
  new Ajax.Request("../port_3480/data_request",
  {
    method: "get",
    parameters:
    {
      id: "lr_ElkCounters",
      rand: Math.random(),
      output_format: "json"
    },
    onSuccess: function (response)
    {
      status.innerHTML = '<td colspan="3">...Response received...</td>';
      var Counters = response.responseText.evalJSON();
      if (Counters.length > 0)
      {
        for (var i = 0; i < Counters.length; i++)
        {
          html = '';
          row = table.insertRow(-1);
          var index = row.insertCell(0);
          var label = row.insertCell(1);
          var value = row.insertCell(2);
          var counterUpdate = row.insertCell(3);
          var counterIndex = Counters[i].index;
          index.innerHTML = Counters[i].index;
          label.innerHTML = Counters[i].label;
          value.innerHTML = '<form name ="' + counterIndex + '"><input name=counterValue type="text" value=' + Counters[i].value + '></input>';
          counterUpdate.innerHTML = '<input type="submit" value="Set" class="btn1" onclick="setCounter(' + device + ',' + '\'' + counterIndex + '\'' + ',$(\'counterTable\'))"></input></<form>';
        }
        status.innerHTML = '<td colspan="4">Completed</td>';
      }
      else
      {
        status.innerHTML = '<td colspan="4">Completed - no counters</td>';
      }
    },
    onFailure: function ()
    {
      status.innerHTML = '<td colspan="4">Failed to get counters</td>';
    }
  });
}

function setCounter(device, counter, table)
{

  //var value = table.rows[counter].cells[2].children[0].value
  var value = document.forms[counter].counterValue.value;
  new Ajax.Request("../port_3480/data_request",
  {
    method: "get",
    parameters:
    {
      id: "lu_action",
      serviceId: ELK_SID,
      action: "SetCounter",
      DeviceNum: device,
      Counter: counter,
      Value: value,
      output_format: "json"
    },
    onSuccess: function (response)
    {
      var time = response.responseText.evalJSON();
      //getCounters(table, device)
    },
    onFailure: function () {}
  });
}

/**********
 * Custom tab
 **********/
function customTab(device)
{
  var html = layout();
  html += '<div id="divContainer">';
  html += '<h1>ELK/NESS ALARM PANEL CUSTOM SETTINGS</h1>';
  //<!-- HTML5 TABLE FORMATTED VIA CSS3-->
  html += '<table class="formatLogPanel" >';
  //<!-- TABLE HEADER-->
  html += '<thead>';
  html += '<tr>';
  html += '<th>INDEX</th><th>DESCRIPTION</th><th colspan="3">CUSTOM VALUE</th>';
  html += '</tr>';
  html += '</thead>';
  //<!-- TABLE BODY: MAIN CONTENT-->
  html += '</thead>';
  html += '<tbody id="customTable" >';
  html += '</tbody>';
  //<!-- TABLE FOOTER-->
  html += '<tfoot>';
  html += '<tr><td colspan=5 id="status"></td></tr>';
  html += '</tfoot>';
  html += '</table>';
  html += '</div>';
  html += '</body>';
  html += '</html>';
  set_panel_html(html);
  getCustomValue($('customTable'), device, $('status'));
}

function getCustomValue(table, device, status)
{
  new Ajax.Request("../port_3480/data_request",
  {
    method: "get",
    parameters:
    {
      id: "lr_ElkCustom",
      rand: Math.random(),
      output_format: "json"
    },
    onSuccess: function (response)
    {
      status.innerHTML = '<td colspan="3">...Response received...</td>';
      var Custom = response.responseText.evalJSON();
      if (Custom.length > 0)
      {
        for (var i = 0; i < Custom.length; i++)
        {
          html = '';
          row = table.insertRow(-1);
          var index = row.insertCell(0);
          var label = row.insertCell(1);
          var value = row.insertCell(2);
          //var format = row.insertCell(3);
          var customUpdate = row.insertCell(3);
          var customIndex = Custom[i].index;
          var customValue = Custom[i].value;
          var type = Custom[i].format;
          if (type === 0)
          {
            type = "Number";
          }
          else if (type == 1)
          {
            type = "Timer";
          }
          else if (type == 2)
          {
            type = "Time Of Day";
            //offset === undefined ? now - time : offset
            if(customValue.length == 1)
            {
              pad(customValue,2);
            }
            else if (customValue.length == 3)
            {
              pad(customValue,4);
            }
            customValue = pad(parseInt(customValue, 10).toString(16),4);
            var hour = pad(parseInt(customValue.substr(0, 2), 16),2);
            var min = pad(parseInt(customValue.substr(2, 3), 16),2);
            customValue = hour + ":" + min;
          }
          index.innerHTML = customIndex;
          label.innerHTML = Custom[i].label;
          value.innerHTML = '<label>' + type + ' </label><form name ="' + customIndex + '"><input type="text" value=' + customValue + ' name="' + type + '"></input>';
          customUpdate.innerHTML = '<input type="submit" value="Set" class="btn1" onclick="setCustom(' + device + ',' + '\'' + customIndex + '\'' + ',$(\'customTable\'))"></input></<form>';
        }
        status.innerHTML = '<td colspan="5">Completed</td>';
      }
      else
      {
        status.innerHTML = '<td colspan="5">Completed - no custom settings</td>';
      }
    },
    onFailure: function ()
    {
      status.innerHTML = '<td colspan="5">Failed to get custom values</td>';
    }
  });
}

function setCustom(device, custom, table)
{
  var value = document.forms[custom].elements[0].value;
  var type = document.forms[custom].elements[0].name;

  if(type == "Time Of Day")
    {
      value = formatTime(value);
      var hour = pad(parseInt(value.substr(0, 2),10).toString(16),2);
      var min = pad(parseInt(value.substr(3, 5),10).toString(16),2);
      value = pad(parseInt((hour + min),16),4);
    }
  new Ajax.Request("../port_3480/data_request",
  {
    method: "get",
    parameters:
    {
      id: "lu_action",
      serviceId: ELK_SID,
      action: "SetCustom",
      DeviceNum: device,
      Custom: custom,
      Value: value,
      output_format: "json"
    },
    onSuccess: function (response)
    {
      var custom = response.responseText.evalJSON();
    },
    onFailure: function () {}
  });
}

function pad(n, width, z)
{
  z = z || '0';
  n = n + '';
  return n.length >= width ? n : new Array(width - n.length + 1).join(z) + n;
}

function formatTime(time)
{
  var result = false, m;
  var re = /^\s*([01]?\d|2[0-3]):?([0-5]\d)\s*$/;
  if ((m = time.match(re)))
  {
    result = (m[1].length == 2 ? "" : "0") + m[1] + ":" + m[2];
  }
  return result;
}
