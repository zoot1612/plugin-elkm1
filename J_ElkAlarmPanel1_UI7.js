var Elk = (function(api)
{
	// unique identifier for this plugin...
  var uuid = 'BC1E7E18-4488-4DEE-A133-1A7097F22127';
  var myModule = {};
  var device = api.getCpanelDeviceId();
  var ELK_SID = "urn:micasaverde-com:serviceId:ElkAlarmPanel1";
  var timerRunning = false;

  MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  ipaddress = getDataRequestURL;
  
  function onBeforeCpanelClose(args)
  {
    // do some cleanup...
    console.log('handler for before cpanel close');
  }

  function init()
	{
    // register to events...
    api.registerEventHandler('on_ui_cpanel_before_close', myModule,	'onBeforeCpanelClose');
  }

  function newLayout()
  {
    var html = "";
    html += '<!DOCTYPE html>';
    html += '<head>';

    html += '<style type="text/css">';

    html += 'h1 {';
    html += 'color: #006f44;';
    html += 'font-family: \'open_sanslight\';';
    html += 'font-size: 40px;';
    html += 'text-align: center;';
    html += '}';

    html += 'h3 {';
    html += 'color: #006f44;';
    html += 'font-family: \'open_sanslight\';';
    html += 'font-size: 25px;';
    html += 'text-align: left;';
    html += '}';

  html += 'table {';
  html += 'width: 100%;';
  html += 'border-collapse:collapse;';
  html += '}';

  html += '</style>';

  html += '</head>';
  html += '<body>';
  return html;
}

/**********
 * Trouble tab
 **********/
function troubleTab(device) {
  var troubleReportList = get_device_state(device, ELK_SID, "TroubleReport", 1);
  var trouble = troubleReportList.split(',');
  var html = newLayout();
  html += '<div class="clearfix">';
  html += '<h1>ELK/NESS ALARM PANEL TROUBLE</h1>';

  html += '<thead>';
  html += '<tr>';
  html += '<th>TROUBLE DISCRIPTION</th>';
  html += '</tr>';
  html += '</thead>';

  html += '<tbody id="troubleTable" >';
  html += '</tbody>';

  html += '<tfoot>';
  html += '<tr><td id="status"></td></tr>';
  html += '</tfoot>';
  html += '</table>';

  html += '</div>';
  html += '</body>';
  html += '</html>';
  setCpanelContent(html);
  troubleReport(jQuery("#troubleTable"), trouble, device, jQuery("#status"));
}

function troubleReport(table, trouble, device, status) {
  if (trouble.length > 0) {
    for (var i = 0; i < trouble.length; i++) {
      var row = jQuery("<tr>").appendTo(table);
      row.append('<td>' + trouble[i] + '</td>');
    }
    status.html("Completed");
  } else {
    status.html("Completed - no trouble reports");
  }
}


/**********
 * Event Log tab
 **********/
function logTab(device) {
  var html = newLayout();
  var LogStart;
  html += '<div class="clearfix">';
  html += '<h1>ELK/NESS ALARM PANEL LOG</h1>';
  html += '<table class="table" >';

  html += '<thead>';
  html += '<tr>';
  html += '<th>INDEX</th><th>DESCRIPTION EXTENDED INFO</th><th>DATE</th><th>TIME</th>';
  html += '</tr>';
  html += '</thead>';

  html += '<tbody id="logTable" >';
  html += '</tbody>';

  html += '<tfoot>';
  html += '<tr><td colspan=4><input id="elk_getForwardLogButton" type="submit" value="More" class="btn1" onclick="tableStatus(jQuery(\'#logTable\'),' + device + ',jQuery(\'#status\'))"></input></td></tr>';
  html += '<tr><td colspan=4 id="status"></td></tr>';
  html += '</tfoot>';
  html += '</table>';

  html += '</div>';
  html += '</body>';
  html += '</html>';
  setCpanelContent(html);
  scanLogEvent(jQuery("#logTable"), device, LogStart, jQuery("#status"));
}

function scanLogEvent(table, device, LogStart, status) {
  var row = jQuery("<tr>").appendTo(table);
  status.html("Creating job to retrieve log");
  new Ajax.Request("../port_3480/data_request", {
    method: "get",
    parameters: {
      id: "lu_action",
      serviceId: ELK_SID,
      action: "GetEventJob",
      DeviceNum: device,
      LogStart: LogStart,
      output_format: "json"
    },
    onSuccess: function(response) {
      var jobId = response.responseText.evalJSON()["u:GetEventJobResponse"]["JobID"];
      if (jobId == undefined) {
        status.html("Failed to create job");
      } else {
        window;
        setTimeout(waitForScanLogEventJob, 500, jobId, table, row, device, status);
      }
    },
    onFailure: function() {
      status.html("Failed to create job");
    }
  });
}

function waitForScanLogEventJob(jobId, table, row, device, status) {
  status.html("Waiting for job status");
  new Ajax.Request("../port_3480/data_request", {
    method: "get",
    parameters: {
      id: "jobstatus",
      job: jobId,
      output_format: "json"
    },
    onSuccess: function(response) {
      var jobStatus = response.responseText.evalJSON()["status"];
      if (jobStatus === 0 || jobStatus === 1 || jobStatus === 5) {
        // Repeat.  Hopefully not so many times as to overflow the stack.
        status.html("Waiting for job status");
        window;
        setTimeout(waitForScanLogEventJob, 500, jobId, table, row, device, status);
      } else if (jobStatus == 2) {
        status.html("Failed to get job status");
      } else if (jobStatus == 4) {
        // Success.  Now get the result of the scan.
        status.html("Successful");
        window;
        setTimeout(getScanLogEventResult, 500, table, row, device, status);
      }
    },
    onFailure: function() {
      status.html("Failed to get log events");
    }
  });
}


function getScanLogEventResult(table, row, device, status) {
  status.html("Getting response");
  new Ajax.Request("../port_3480/data_request", {
    method: "get",
    parameters: {
      id: "lr_ElkEvent",
      rand: Math.random(),
      output_format: "json"
    },
    onSuccess: function(response) {
      status.html("Response received");
      var Log = response.responseText.evalJSON();

      for (var i = 0; i < Log.length; i++) {
        html = '';
        row = jQuery("<tr>").appendTo(table);
        row.append('<td>' + Log[i].index + '</td>');
        row.append('<td>' + Log[i].eventType + '</td>');
        row.append('<td>' + Log[i].day + '</td>');
        row.append('<td>' + Log[i].time + '</td>');
      }

      status.html("Completed");
    },
    onFailure: function() {
      status.html("Failed to get log events");
    }

  });

}


function tableStatus(table, device, status) {
  var index = parseInt($('table tbody tr:last td:first').text(), 10) + 1;
  scanLogEvent(table, device, index, status);
  var mark;
}




/**********
 * Time tab
 **********/
function timeTab(device) {
  var html = newLayout();
  html += '<div class="clearfix">';
  html += '<h1>ELK/NESS ALARM PANEL RTC</h1>';
  html += '<table class="table" >';

  html += '<thead>';
  html += '<tr>';
  html += '<th colspan="2">REAL TIME CLOCK</th>';
  html += '</tr>';
  html += '</thead>';

  html += '<tbody>';
  html += '<tr>';
  html += '<td id="clockCell"></td>';
  html += '<td><input id="elk_getForwardLogButton" type="submit" value="Set" class="btn1" title="Set Elk Real Time Clock from your device" onclick="setElkRTC(' + device + ',jQuery(\'#clockCell\'),jQuery(\'#status\'))"></input></td>';
  html += '</tr>';
  html += '</tbody>';

  html += '<tfoot>';
  html += '<tr><td colspan=2 id="status"></td></tr>';
  html += '</tfoot>';
  html += '</table>';
  html += '</div>';
  html += '</body>';
  html += '</html>';
  setCpanelContent(html);
  getElkRTC(device, jQuery("#clockCell"), jQuery("#status"));
}


function showtime(time, cell, offset, status) {
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
  cell.html(timeValue);
  setTimeout(function() {
    showtime(timeValue, cell, offset, status);
  }, 1000);
}


function getElkRTC(device, cell, status) {
  new Ajax.Request("../port_3480/data_request", {
    method: "get",
    parameters: {
      id: "lr_ElkRTC",
      rand: Math.random(),
      output_format: "json"
    },
    onSuccess: function(response) {
      var time = response.responseText;
      status.html("Completed");
      showtime(time, cell, null, status);
    },
    onFailure: function() {
      status.html("Failed to get Alarm panel time");
    }
  });
}


function setElkRTC(device, cell, status) {
  var time = +new Date;
  new Ajax.Request("../port_3480/data_request", {
    method: "get",
    parameters: {
      id: "lu_action",
      serviceId: ELK_SID,
      action: "SetElkRTC",
      DeviceNum: device,
      Time: time,
      output_format: "json"
    },
    onSuccess: function(response) {
      var time = response.responseText.evalJSON();
      getElkRTC(device, cell, status);
    },
    onFailure: function() {}
  });
}

/**********
 * Counter tab
 **********/
function counterTab(device)

{
  var html = newLayout();
  html += '<div class="clearfix">';
  html += '<h1>ELK/NESS ALARM PANEL COUNTERS</h1>';
  html += '<table class="table" >';

  html += '<thead>';
  html += '<tr>';
  html += '<th>INDEX</th><th>DESCRIPTION</th><th colspan="2">COUNTER VALUE</th>';
  html += '</tr>';
  html += '</thead>';

  html += '<tbody id="counterTable" >';
  html += '</tbody>';

  html += '<tfoot>';
  html += '<tr><td colspan=4 id="status"></td></tr>';
  html += '</tfoot>';
  html += '</table>';

  html += '</div>';
  html += '</body>';
  html += '</html>';

  setCpanelContent(html);

  getCounters(jQuery("#counterTable"), device, jQuery("#status"));
}

function getCounters(table, device, status) {
  new Ajax.Request("../port_3480/data_request", {
    method: "get",
    parameters: {
      id: "lr_ElkCounters",
      rand: Math.random(),
      output_format: "json"
    },
    onSuccess: function(response) {
      status.html("Response received");
      var Counters = response.responseText.evalJSON();
      if (Counters.length > 0) {
        for (var i = 0; i < Counters.length; i++) {
          row = jQuery("<tr>").appendTo(table);
          row.append('<td>' + Counters[i].index + '</td>');
          row.append('<td>' + Counters[i].label + '</td>');
          row.append('<td><form name ="' + Counters[i].index + '"><input name=counterValue type="text" value=' + Counters[i].value + '></input></td>');
          row.append('<td><input type="submit" value="Set" class="btn1" onclick="setCounter(' + device + ',' + '\'' + Counters[i].index + '\'' + ',jQuery(\'#counterTable\'))"></input></<form></td>');
        }
        status.html("Completed");
      } else {
        status.html("Completed no counters");
      }
    },
    onFailure: function() {
      status.html("Completed failed to get counters");
    }
  });
}

function setCounter(device, counter, table) {

  //var value = table.rows[counter].cells[2].children[0].value
  var value = document.forms[counter].counterValue.value;
  new Ajax.Request("../port_3480/data_request", {
    method: "get",
    parameters: {
      id: "lu_action",
      serviceId: ELK_SID,
      action: "SetCounter",
      DeviceNum: device,
      Counter: counter,
      Value: value,
      output_format: "json"
    },
    onSuccess: function(response) {
      var time = response.responseText.evalJSON();
      //getCounters(table, device)
    },
    onFailure: function() {}
  });
}

/**********
 * Custom tab
 **********/
function customTab(device) {
  var html = newLayout();
  html += '<div class="clearfix">';
  html += '<h1>ELK/NESS ALARM PANEL CUSTOM SETTINGS</h1>';
  html += '<table class="table" >';

  html += '<thead>';
  html += '<tr>';
  html += '<th>INDEX</th><th>DESCRIPTION</th><th colspan="3">CUSTOM VALUE</th>';
  html += '</tr>';
  html += '</thead>';

  html += '<tbody id="customTable" >';
  html += '</tbody>';

  html += '<tfoot>';
  html += '<tr><td colspan=5 id="status"></td></tr>';
  html += '</tfoot>';
  html += '</table>';

  html += '</div>';
  html += '</body>';
  html += '</html>';
  setCpanelContent(html);
  getCustomValue(jQuery("#customTable"), device, jQuery("#status"));
}

function getCustomValue(table, device, status) {
  new Ajax.Request("../port_3480/data_request", {
    method: "get",
    parameters: {
      id: "lr_ElkCustom",
      rand: Math.random(),
      output_format: "json"
    },
    onSuccess: function(response) {
      status.html("Response received");
      var Custom = response.responseText.evalJSON();
      if (Custom.length > 0) {
        for (var i = 0; i < Custom.length; i++) {
          var customIndex = Custom[i].index;
          var customValue = Custom[i].value;
          var type = Custom[i].format;
          if (type === 0) {
            type = "Number";
          } else if (type == 1) {
            type = "Timer";
          } else if (type == 2) {
            type = "Time Of Day";
            if (customValue.length == 1) {
              pad(customValue, 2);
            } else if (customValue.length == 3) {
              pad(customValue, 4);
            }
            customValue = pad(parseInt(customValue, 10).toString(16), 4);
            var hour = pad(parseInt(customValue.substr(0, 2), 16), 2);
            var min = pad(parseInt(customValue.substr(2, 3), 16), 2);
            customValue = hour + ":" + min;
          }


          row = jQuery('<tr>').appendTo(table);
          row.append('<td>' + Custom[i].index + '</td>');
          row.append('<td>' + Custom[i].label + '</td>');
          row.append('<td><label>' + type + ' </label></td>');
          row.append('<td><form name ="' + customIndex + '"><input type="text" value=' + customValue + ' name="' + type + '"></input></td>');
          row.append('<td><input type="submit" value="Set" class="btn1" onclick="setCustom(' + device + ',' + '\'' + customIndex + '\'' + ',jQuery(\'#customTable\'))"></input></<form></td>');
        }
        status.html("Completed");
      } else {
        status.html("Completed no custom settings");
      }
    },
    onFailure: function() {
      status.html("Completed failed to get custom values");
    }
  });
}

function setCustom(device, custom, table) {
  var value = document.forms[custom].elements[0].value;
  var type = document.forms[custom].elements[0].name;

  if (type == "Time Of Day") {
    value = formatTime(value);
    var hour = pad(parseInt(value.substr(0, 2), 10).toString(16), 2);
    var min = pad(parseInt(value.substr(3, 5), 10).toString(16), 2);
    value = pad(parseInt((hour + min), 16), 4);
  }
  new Ajax.Request("../port_3480/data_request", {
    method: "get",
    parameters: {
      id: "lu_action",
      serviceId: ELK_SID,
      action: "SetCustom",
      DeviceNum: device,
      Custom: custom,
      Value: value,
      output_format: "json"
    },
    onSuccess: function(response) {
      var custom = response.responseText.evalJSON();
    },
    onFailure: function() {}
  });
}

function pad(n, width, z) {
  z = z || '0';
  n = n + '';
  return n.length >= width ? n : new Array(width - n.length + 1).join(z) + n;
}

function formatTime(time) {
  var result = false,
    m;
  var re = /^\s*([01]?\d|2[0-3]):?([0-5]\d)\s*$/;
  if ((m = time.match(re))) {
    result = (m[1].length == 2 ? "" : "0") + m[1] + ":" + m[2];
  }
  return result;
}

	myModule = {
		uuid: uuid,
		init: init,
		onBeforeCpanelClose: onBeforeCpanelClose,
		troubleTab: troubleTab,
		troubleReport: troubleReport,
		logTab: logTab,
		timeTab: timeTab,
		counterTab: counterTab,
		customTab: customTab
	};
	return myModule;
})(api);
