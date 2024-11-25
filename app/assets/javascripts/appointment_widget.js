$(document).ready(function () {
  Date.prototype.addDays = function(days) {
    var date = new Date(this.valueOf());
    date.setDate(date.getDate() + days);
    return date;
  }
  // set date
  function addWeekdays(date, days) {
    date = moment(date); // use a clone
    var tempDate = 0;
    var dateCollection = offDaysCollection;
    if (dateCollection.includes(0)) {
      dateCollection[dateCollection.indexOf(0)] = 7
    }
    while (days >= 0) {
      if (!dateCollection.includes(date.isoWeekday())) {
        tempDate = date.clone();
      }
      days -= 1;
      date = date.add(1, "days");
    }
    return tempDate;
  }

  function populateCalendarButtonText(date) {
    $("#calendarButtonContainer").removeClass("d-none");
    var selectedDate = moment(date).format("MMM DD, YYYY");
    var nextDate = addWeekdays(moment(date), 6).format("MMM DD, YYYY");
    $("#calendarText7").text(selectedDate + " - " + nextDate);
  }

  var locale = window.I18n;
  var availableSlots = [];
  var offDaysCollection = [];
  var serviceLength = $("#servicesSelect").children("option").length;
  var resouceLength = $("#resourcesSelect").children("option").length;
  var useBranding = $("#ivrid").data("use-branding");
  var firstTimezoneReload = true;
  var appointmentDuration;
  var clientDetail;
  var firstStartDate;
  var widge_language_prefernce = $("#widget_language_by_preference").val();
  var localeParam;
  var calendarDays = [];
  var selecetedTimeResource;
  let appointmentQuestions;
  let appointmentCustomerID;
  if (widge_language_prefernce == "-") {
    localeParam = getUrlParameter('locale') ? getUrlParameter('locale') : "en";
  } else {
    localeParam = widge_language_prefernce;
  }

  var input = document.querySelector("#appointmentPhoneNumber");
  if (input) {
    iti = window.intlTelInput(input, {
      initialCountry: "auto",
      preferredCountries: ["fr", "be", "de", "gb", "us", "ca"],
      utilsScript: "/assets/utils.js",
      geoIpLookup: function (callback) {
        $.get(
            "https://api.ipdata.co?api-key=" + $(".phoneSection").data("ipkey"),
            function () {},
            "jsonp"
        ).always(function (resp) {
          var countryCode = (resp && resp.country_code) ? resp.country_code : "fr";
          callback(countryCode);
        });
      },
    });
  }

  $('#goToServiceResouceRow').click(function(){
    $('#brandingPreview').addClass('d-none');
    if (serviceLength > 2) {
      $('#serviceResouceRow').removeClass('d-none');
    } else {
      $(".localization").removeClass("d-inline-block").addClass("d-none");
      $("#step-2").removeClass("d-none");
      $("#heading_one").addClass("d-none");
      $("#heading_two").removeClass("d-none");
      window.finishTime = null;
      window.widget_load = 1;
      $("#loaderSection").addClass("loading");
      fetchAppointmentCalendar();
    }
  });

  $('#backTobrandingPreview').click(function(){
    $('#brandingPreview').removeClass('d-none');
    $('#serviceResouceRow').addClass('d-none');
  });

  function createCalendarHTML() {
    $("#calendarJSContainer").append(
      '<button type="button" id="calendarButton" class="btn btn-outline-secondary border-0 pl-4 pr-3 pt-1 pb-1">\
        <i class="flaticon-calendar-3"></i>\
        <span id="calendarText7"></span>\
        <i class="flaticon2-down-arrow ml-1" style="font-size: 1.0rem;"></i>\
      </button>'
    );
  }

  function createMobileCalendarHTML() {
    $("#calendarMobileJSContainer").append(
      '<div class="calendarButtonMobile" id="inMobileView"></div>'
    );
  }

  function formatDateForEnableFilter(d) {
    var day = String(d.getDate())
    //add leading zero if day is is single digit
    if (day.length == 1)
      day = '0' + day
    var month = String((d.getMonth()+1))
    //add leading zero if month is is single digit
    if (month.length == 1)
      month = '0' + month
    return d.getFullYear() + "-" + month + "-" + day;
  }

  function initializeDatepicker(firstDate, calendar_days, defaultViewCalendar) {
    calendarDays = _.uniq(calendarDays.concat(calendar_days));
    $("#calendarButton").remove();
    $(".calendarButtonMobile").remove();
    createCalendarHTML();
    createMobileCalendarHTML();
    $("#calendarButton, .calendarButtonMobile").datepicker('destroy').datepicker({
      startDate:new Date(firstDate.replace(/ /g,"T")),
      weekStart: 1,
      autoclose: true,
      format: "yyyy-mm-dd",
      defaultViewDate: {
        year: moment(defaultViewCalendar).format("YYYY"),
        month: moment(defaultViewCalendar).format("M") - 1,
        day: moment(defaultViewCalendar).format("DD")
      },
      language: localeParam,
      beforeShowDay: function(date){
        if($("#future_days").val() !== "") {
        var updatedDate = new Date().addDays(parseInt($("#future_days").val()));
          if (date <= updatedDate) {
          } else {
            return {
              enabled: false
            }
          }
        }
        if (calendarDays.indexOf(formatDateForEnableFilter(date)) < 0) {
            return {
              enabled: false
            }
        }
        else {
          return {
            enabled: true
          }
        }
      },
      daysOfWeekDisabled: offDaysCollection.toString(),
    }).on("changeDate", function(date) {
      // set mobile list view active
      if($(this).attr("id") == "inMobileView") {
        window.finishTime = null;
        $("#loaderSection").addClass("loading");
        fetchCalendarSlotsForMobile(dateFormat(date.format()));
      } else {
        window.widget_load = null;
        initializeWidgetCarousel(new Date(date.format()));
        populateCalendarButtonText(new Date(date.format()));
      }
    }).on("changeMonth", function(updatedMonth){
      var newDate = updatedMonth.date.getFullYear() + "-" + moment(updatedMonth.date).format("MM") + "-01 00:00:00";
      updateCalendarAvilableSlots(newDate, $(this).attr("id"));
    });
  }

  // function initializeMobileWidget(date) {
  //   window.finishTime = null;
  //   $("#loaderSection").addClass("loading");
  //   updateCalendarAvilableSlots(date, "inMobileView", "fromMObile");
  // }

  function fetchCalendarSlotsForMobile(date) {
    $("#loaderSection").addClass("loading");
    var ivrID = $("#ivrid").val();
    var serviceID = $("#servicesSelect").val() === "" ? $("#servicesSelect")[0][1].value : $("#servicesSelect").val();
    var resourceID = $("#resourcesSelect").val() === "" ? $("#resourcesSelect")[0][1].value : $("#resourcesSelect").val();
    var data = {};

    data["ivr_id"] = ivrID;
    data["service_id"] = serviceID;
    data["resource_id"] = resourceID;
    data["start_time"] = date;
    if ($('input[name="timerange"]:checked').val() != "all") {
      data["tslot"] = $('input[name="timerange"]:checked').val();
    }
    data["first_start_date"] = dateFormat(firstStartDate);
    data["authenticity_token"] = $('[name="csrf-token"]')[0].content;
    data["mobile_view"] = true;

    $.ajax({
      url: "/fetch_agenda_slots",
      type: "POST",
      data: data,
      success: function (response) {
        $("#loaderSection").removeClass("loading");
        initializeDatepicker(response.start_calendar, response.calendar_days, response.start_calendar);
        $("#calendarDetailSm").removeClass("d-none");
        $("#prevCustomr").addClass("d-none");
        $("#timeSection").removeClass("d-block").addClass("d-none");
        $("#heading_two").addClass("d-none");
        var days = response.days;
        var slots = response.slots;
        window.finishTime = days[days.length - 1];
        availableSlots = availableSlots.concat(slots);
        appointmentDuration = response.duration;
        offDaysCollection = response.off_days;
        var selectedDate = moment(new Date(date));
        var widget_tz_by_preference = $("#widget_tz_by_preference").val();
        var selectedTimeZone = widget_tz_by_preference == "-" ? $(".timezone-select").val(): widget_tz_by_preference;
        // populate headings
        $("#mobileWidgetWeekDay").text(selectedDate.format("dddd"));
        $("#mobileWidgetDate").text(selectedDate.format("MMMM DD, YYYY"));
        $("#mobileWidgetTZ").text(selectedTimeZone);
        $("#mobileWidgetDuration").text(locale["appointment_widget"]["appointment_duration"] + " " + response.duration + " min");
        var html = "";
        for (k = 0; k < slots.length; k++) {
          if (slots[k].start.substr(0, 10) == moment(date).format("YYYY-MM-DD")) {
            html += '<label class="btn btn-secondary w-100 p-3 mb-3" style="border-color: #3d94fb; font-size: 13px; font-weight: bold; color: #3d94fb;">';
            html += '<input type="radio" class="rButton d-none" name="mobileOptions" value="'+slots[k].start+'" id="optionMobile2">' + tConvert(slots[k].start);
            html += '</label>';
          }
        }
        $("#mobileTimeSlotsLabels").html(html);
      },
      error: function(error) {
        $("#loaderSection").removeClass("loading");
        $(".appointment-success-info").addClass("d-none");
        $(".appointmnet-error-info").removeClass("d-none");
        $(".appointmentMessage").text(locale["appointment_widget"]["appointment_static_error"]);
        $("#appointmentStatus").modal("show");
        console.log(error);
      }
    });
  }

  function updateCalendarAvilableSlots(newDate, breakpointView) {
    $("#loaderSection").addClass("loading");
    var ivrID = $("#ivrid").val();
    var serviceID = $("#servicesSelect").val() === "" ? $("#servicesSelect")[0][1].value : $("#servicesSelect").val();
    var resourceID = $("#resourcesSelect").val() === "" ? $("#resourcesSelect")[0][1].value : $("#resourcesSelect").val();
    var data = {};

    data["ivr_id"] = ivrID;
    data["service_id"] = serviceID;
    data["resource_id"] = resourceID;
    data["start_time"] = newDate
    if ($('input[name="timerange"]:checked').val() != "all") {
      data["tslot"] = $('input[name="timerange"]:checked').val();
    }
    data["first_start_date"] = dateFormat(firstStartDate);
    data["authenticity_token"] = $('[name="csrf-token"]')[0].content;

    $.ajax({
      url: "/fetch_agenda_slots",
      type: "POST",
      data: data,
      success: function (response) {
        $("#loaderSection").removeClass("loading");
        newDate = newDate < response.start_calendar ? response.start_calendar : newDate;
        initializeDatepicker(response.start_calendar, response.calendar_days, newDate);
        if(!_.isEmpty(response.days)) {
          populateCalendarButtonText(new Date(response.days[0]));
        } else {
          populateCalendarButtonText(new Date());
        }
        // workaround
        $(".datepicker.datepicker-dropdown").remove();
        if (breakpointView != "inMobileView") {
          $("#calendarButton").click();
        }
      },
      error: function(error) {
        $("#loaderSection").removeClass("loading");
        $(".appointment-success-info").addClass("d-none");
        $(".appointmnet-error-info").removeClass("d-none");
        $(".appointmentMessage").text(locale["appointment_widget"]["appointment_static_error"]);
        $("#appointmentStatus").modal("show");
        console.log(error);
      }
    });
  }

  $("#backtocalendar").click(function(){
    // $("#customerDetail").addClass("d-none");
    $("#calendarDetailSm").addClass("d-none");
    $("#prevCustomr").removeClass("d-none");
    $("#timeSection").removeClass("d-none").addClass("d-block");
    $("#heading_three").addClass("d-none");
    $("#heading_two").removeClass("d-none");
  });
  

  function initializeWidgetCarousel(date) {
    $("#carocalendar .carousel-item:first-child").addClass("active");
    $("#carocalendar .carousel-item:not(:first-child)").remove();
    window.finishTime = null;
    $("#loaderSection").addClass("loading");
    fetchAppointmentCalendar(date);
  }

  $("#servicesSelect, #resourcesSelect").select2({
    // placeholder: locale["appointment_widget"]["select_placeholder"]
  });
  $("#heading_two").addClass("d-none");
  $("#heading_three").addClass("d-none");
  $("#step-2").addClass("d-none");
  $(".step2-summary").addClass("d-none");
  $("#serviceNext").attr("disabled", true);

  function redirect2Step2() {
    $("#serviceResouceRow").addClass("d-none");
    $("#loaderSection").addClass("loading");
    $("#step-2").removeClass("d-none");
    $("#heading_two").removeClass("d-none");
    window.widget_load = 1;
    fetchAppointmentCalendar();
    $("#backToservices").addClass("d-none");
    $("#heading_one").addClass("d-none");
  }

  var level1dropdownForWidget = $("#level1dropdownForWidget").val();
  var defaultResourceForWidget = $("#defaultResourceForWidget").val();

  if (serviceLength === 2 && resouceLength === 2 && !useBranding) {
    redirect2Step2();
  }
  else $("#backToservices").removeClass("d-none");

  if (serviceLength === 2) {
    $("#servicesSelect .no-disable").remove();
    $("#serviceOptions").addClass("d-none");
    $("#resoucrOptions").addClass("mx-auto");
    if(level1dropdownForWidget == "Service Only") {
      $("#resourcesSelect").val(defaultResourceForWidget.toString()).trigger("change");
      if (! useBranding) redirect2Step2();
      else $("#backToservices").removeClass("d-none");
    }
  }

  var randomResourceSelect = $("#servicesSelect").find(':selected').data('random-resource-select');

  if (serviceLength === 2 && randomResourceSelect) {
    if (! useBranding) redirect2Step2();
    else $("#backToservices").removeClass("d-none");
  }

  if (resouceLength === 2) {
    $("#resoucrOptions").addClass("d-none");
    $("#serviceOptions").addClass("mx-auto");
    $("#resourcesSelect").val($("#resourcesSelect")[0][1].value);
  }

  if(level1dropdownForWidget == "Service Only") {
    // $("#resourcesSelect").val(defaultResourceForWidget.toString()).trigger("change");
    $("#resoucrOptions").addClass("d-none");
    $("#serviceOptions").addClass("mx-auto");
  }

  if(level1dropdownForWidget == "Custom Order" && serviceLength > 2) {
    if(defaultResourceForWidget !== "resourceFirst") {
      $("#resoucrOptions").addClass("d-none");
      $("#serviceOptions").addClass("mx-auto");
    } else {
      $("#serviceOptions").addClass("d-none");
      $("#resoucrOptions").addClass("mx-auto");
    }
  }

  $('#resourcesSelect').on('select2:select', function (e) {
    if(level1dropdownForWidget == "Custom Order" && defaultResourceForWidget =="resourceFirst") {
      $("#serviceOptions").removeClass("d-none");
      $("#resoucrOptions").removeClass("mx-auto");

      $("#loaderSection").addClass("loading");
      $("#servicesSelect").html();

      $.ajax({
        type: "GET",
        data: {id: $("#resourcesSelect").val(), type: "Resource"},
        url: "/services/get_dependencies",
        success: function(data){
          $("#loaderSection").removeClass("loading");
          $('#servicesSelect').find('option').remove().end()
          $.each(data["dependent_services"], function(key, value){
            $('#servicesSelect')
                .append($("<option></option>")
                    .attr("value",value[0])
                    .text(value[1]));
          });
          $("#serviceNext").attr("disabled", false);
        }
      });
    }
    if($("#resourcesSelect").val() != "" && $("#servicesSelect").val() != "") {
      $("#serviceNext").attr("disabled", false);
    } else {
      $("#serviceNext").attr("disabled", true);
    }
  });

  $('#servicesSelect').on('select2:select', function (e) {
    if(level1dropdownForWidget == "Service Only" || level1dropdownForWidget == "-" || level1dropdownForWidget == "Custom Order" && defaultResourceForWidget !=="resourceFirst") {
      $("#loaderSection").addClass("loading");
      $("#resourcesSelect").html();
      //set after ajax
      $.ajax({
        type: "GET",
        data: {id: $("#servicesSelect").val(), type: "Service"},
        url: "/services/get_dependencies",
        success: function(data){
          $("#loaderSection").removeClass("loading");
          $('#resourcesSelect').find('option').remove().end()
          $.each(data["dependent_resources"], function(key, value){
            $('#resourcesSelect')
                .append($("<option></option>")
                    .attr("value",value[0])
                    .text(value[2]));
          });
          $("#serviceNext").attr("disabled", false);
        }
      });
    }

    if ($(this).find(':selected').data('random-resource-select')) {
      $("#resoucrOptions").addClass("d-none");
      $("#serviceOptions").addClass("mx-auto");
    } else {
      if (level1dropdownForWidget !== "Service Only") {
        $("#resoucrOptions").removeClass("d-none");
        $("#serviceOptions").removeClass("mx-auto");
      }
    }

    if(level1dropdownForWidget == "Custom Order" && defaultResourceForWidget !== "resourceFirst" && !$(this).find(':selected').data('random-resource-select')) {
      $("#resoucrOptions").removeClass("d-none");
      $("#serviceOptions").removeClass("mx-auto");
    }
    if($("#resourcesSelect").val() != "" && $("#servicesSelect").val() != "") {
      $("#serviceNext").attr("disabled", false);
    } else {
      $("#serviceNext").attr("disabled", true);
    }
  });

  if ($('input#appointment_type').val() == 'schedule') {
    if ($('input#appointment_status').val() == 'cancelled') {
      $(".appointment-success-info").addClass("d-none");
      $(".appointmnet-error-info").removeClass("d-none");
      $("h4.appointment-error-text").text($('input#appointment_cannot_reschedule').val());
      $(".appointmentMessage").text($('input#appointment_already_cancelled').val());
      $("#appointmentStatus").modal("show");
      return;
    }
    $("h4.booking-heading").html($('input#appointment_name').val());                      // service name
    $("input#appointmentEmail").val($("input#appointment_customer_email").val());         // email
    iti.setNumber($("input#appointment_customer_phone").val());   // phone
    $("input#customerFullName").val($("input#appointment_customer_name").val());          // full name
    $("input#customerFirstName").val($("input#appointment_customer_firstname").val());    // first name
    $("input#customerLastName").val($("input#appointment_customer_lastname").val());     // last name
    $('#brandingPreview').addClass('d-none');

    gotoNext();
  }

  if ($('input#appointment_type').val() == 'cancel') {
    if ($('input#appointment_status').val() == 'cancelled') {
      $(".appointment-success-info").addClass("d-none");
      $(".appointmnet-error-info").removeClass("d-none");
      $("h4.appointment-error-text").text($('input#appointment_cannot_cancel').val());
      $(".appointmentMessage").text($('input#appointment_already_cancelled').val());
      $("#appointmentStatus").modal("show");
      return;
    }
    $("#customerDetail").removeClass("d-none");
    $("#prevCustomr").addClass("d-none");
    $("#timeSection").removeClass("d-block").addClass("d-none");
    $("#heading_three").addClass("d-none");
    $("#heading_two").addClass("d-none");
    $("i#backToSlots").addClass("d-none");
    $("i#backToSlots").removeClass("d-md-block");
    if (!$('div#email_and_phone_sec').hasClass('d-none')) $('div#email_and_phone_sec').addClass('d-none');
    if (!$('div#additonalQuestionEmbed').hasClass('d-none')) $('div#additonalQuestionEmbed').addClass('d-none');

    $("h4.booking-heading").html($('input#appointment_name').val());
    $("span#durationH").html($('input#appointment_duration').val() + " mins");
    const start_time =$('input#appointment_start_time').val();
    const end_time =$('input#appointment_end_time').val();
    $("span#selectedSlotH").html(tConvert(start_time) + " - " + tConvert(end_time) + ", " + moment(end_time).format("ddd, MMMM D, YYYY"));
    $("span#timezoneH").html($('input#appointment_timezone').val());
  }

  if ($('input#appointment_type').val() == 'invalid_cancel_event') {
    $("#loaderSection").removeClass("loading");
    $(".appointment-success-info").addClass("d-none");
    $(".appointmnet-error-info").removeClass("d-none");
    $("h4.appointment-error-text").html($('input#appointment_invalid_cancel').val());
    $(".appointmentMessage").text($('input#appointment_invalid_event').val());
    $("#appointmentStatus").modal("show");
  }

  function gotoNext() {
    $(".localization").removeClass("d-inline-block").addClass("d-none");
    $("#serviceResouceRow").addClass("d-none");
    $("#step-2").removeClass("d-none");
    $("#heading_one").addClass("d-none");
    $("#heading_two").removeClass("d-none");
    $('div.cancelSection').addClass('d-none');
    $(this).addClass("d-none");
    window.finishTime = null;
    window.widget_load = 1;
    $("#loaderSection").addClass("loading");
    fetchAppointmentCalendar();
  }
  $("#serviceNext").click(function () {
    gotoNext();
  });

  $(".time-format").on("change", function () {
    window.widget_load = 1;
    initializeWidgetCarousel();
  });

  $(".timezone-select").on("change", function () {
    if (!firstTimezoneReload) {
      window.widget_load = 1;
      initializeWidgetCarousel();
    }
    
  });

  $(document).on("change", "input[name='timerange']:checkbox", function () {
    $("input[name='timerange']:checkbox").not(this).prop('checked', false);  
    $("#carocalendar .carousel-item:first-child").addClass("active");
    $("#carocalendar .carousel-item:not(:first-child)").remove();
    window.finishTime = null;
    window.widget_load = 1;
    $("#loaderSection").addClass("loading");
    fetchAppointmentCalendar();
  });

  $("#fetchSlot").click(function () {
    // http://localhost:3000/fetch_agenda_slots?ivr_id=1&resource_id=3&service_id=3&start_time=2020-07-17+00%3A01%3A00+UTC&tslot=0912
    $("#loaderSection").addClass("loading");
    window.widget_load = 1;
    fetchAppointmentCalendar();
  });

  function dateFormat(date) {
    t = new Date(date);
    hr = ("0" + t.getHours()).slice(-2);
    min = ("0" + t.getMinutes()).slice(-2);
    sec = ("0" + t.getSeconds()).slice(-2);
    nmon = ("0" + (parseInt(t.getMonth()) + 1)).slice(-2);
    ndate = ("0" + t.getDate()).slice(-2);
    nyear = t.getFullYear();
    new_date =
      nyear + "-" + nmon + "-" + ndate + " " + hr + ":" + min + ":" + sec;
    return new_date;
  }

  function newDateFormat(date) {
    t = new Date(date);
    // seconds * minutes * hours * milliseconds = 1 day
    var day = 60 * 60 * 24 * 1000;
    var endDate = new Date(t.getTime() + day);
    nmon = ("0" + (parseInt(endDate.getMonth()) + 1)).slice(-2);
    ndate = ("0" + endDate.getDate()).slice(-2);
    nyear = endDate.getFullYear();
    new_date = nyear + "-" + nmon + "-" + ndate + " " + "00:00:00";
    return new_date;
  }

  function tConvert(time) {
    firstTimezoneReload = false;
    var time_format = moment(time);
    var widget_tz_by_preference = $("#widget_tz_by_preference").val();
    var selectedTimeZone = widget_tz_by_preference == "-" ? $(".timezone-select").val(): widget_tz_by_preference;
    var formatType;
    var checkTZPreference = $("#widget_tf_by_preference").val();
    var checkAvailableFormats = checkTZPreference == "-" ? $(".time-format").val() : checkTZPreference;
    if (checkAvailableFormats === "am/pm") {
      formatType = "hh:mm a";
    } else {
      formatType = "HH:mm"
    }
    return time_format.tz(selectedTimeZone).format(formatType);
  }

  function fetchAppointmentCalendar(date) {
    // first date rounded
    var coeff = 1000 * 60 * 30;
    var rounded;
    if (date == undefined) {
      var date = new Date();
      rounded = new Date(Math.round(date / coeff) * coeff);
    } else {
      rounded = date;
    }
    
    // end

    var ivrID = $("#ivrid").val();
    var serviceID = $('input#appointment_type').val() == 'schedule' ? $('input#appointment_service_id').val() : ($("#servicesSelect").val() === "" ? $("#servicesSelect")[0][1].value : $("#servicesSelect").val());
    var resourceID = $('input#appointment_type').val() == 'schedule' ? $('input#appointment_resource_id').val() : ($("#resourcesSelect").val() === "" ? $("#resourcesSelect")[0][1].value : $("#resourcesSelect").val());
    var data = {};

    $("#servicesSelect").val(serviceID);
    $('#resourcesSelect').val(resourceID);

    data["ivr_id"] = ivrID;
    data["service_id"] = serviceID;
    data["resource_id"] = resourceID;
    data["start_time"] = window.finishTime
      ? newDateFormat(window.finishTime)
      : dateFormat(rounded);

    if ($('input[name="timerange"]:checked').val() != "all") {
      data["tslot"] = $('input[name="timerange"]:checked').val();
    }

    data["first_start_date"] = dateFormat(firstStartDate);
    if (window.widget_load != null) {
      data["widget_load"] = window.widget_load;
      data["first_start_date"] = "";
    }

    data["authenticity_token"] = $('[name="csrf-token"]')[0].content;
    if (typeof window.orientation !== 'undefined') {
      data["check_next_on_mobile"] = true;
    }

    function convertTime12to24(time12h) {
      const [time, modifier] = time12h.split(" ");
      let [hours, minutes] = time.split(":");

      if (hours === "12") {
        hours = "00";
      }

      if (modifier === "PM") {
        hours = parseInt(hours, 10) + 12;
      }

      return `${hours}:${minutes}`;
    }    

    $.ajax({
      url: $('#appointment_type').val() == 'schedule' ? "/fetch_agenda_slots_for_schedule" : "/fetch_agenda_slots",
      type: "POST",
      data: data,
      success: function (response) {
        $("#fetchSlot").addClass("d-none");
        $("#loaderSection").removeClass("loading");
        var days = response.days;
        var slots = response.slots;
        var html = "";
        moment.locale(localeParam);
        // days = [];
        if(!_.isEmpty(days)) {
          var counter = 0;
          $.each(days, function (i) {
            if($("#future_days").val() !== "") {
              var updatedDate = new Date().addDays(parseInt($("#future_days").val()));
              if(new Date(days[i]) <= updatedDate) {
                html += "<div class='ml-2 mr-2'>";
                html +=
                  "<a class='calender-date font-weight-bold' data-date=" +
                  days[i] +
                  " style='cursor: pointer'>" +
                  moment(days[i]).format("MMM Do") +
                  "</br>" +
                  moment(days[i]).format("dddd") +
                  "</a>";
                var radio = "";
                var timeSlots = response.slots;
                radio += "<div class='mt-3 handleradio'>";
                for (k = 0; k < timeSlots.length; k++) {
                  if (timeSlots[k].start.substr(0, 10) == days[i]) {
                    radio += "<label class='btn btn-secondary' style='width: 90px'>";
                    radio +=
                      "<input type='radio' class='rButton d-none' name='options' value='" +
                      timeSlots[k].start +
                      "' id='option2'>" +
                      tConvert(timeSlots[k].start);
                    // $('.time-format').val() === "am/pm"? tConvert(timeSlots[k].start.substr(11,5)) : timeSlots[k].start.substr(11,5);
                    radio += "</label>";
                    radio += "<br>";
                  }
                }
                radio += "</div>";
                html += radio;
                html += "</div>";
              } else {
                counter += 1;
                if(counter === days.length) {
                  html += "<div class='mt-5 mb-5' id='no-slot-info'>";
                  html += "<div class='alert alert-info mt-5 mb-5' role='alert'>" +
                  locale["appointment_widget"]["no_slots_button"] +
                    "</div></div>";
                }
              }
            } else {
              html += "<div class='ml-2 mr-2'>";
                html +=
                  "<a class='calender-date font-weight-bold' data-date=" +
                  days[i] +
                  " style='cursor: pointer'>" +
                  moment(days[i]).format("MMM Do") +
                  "</br>" +
                  moment(days[i]).format("dddd") +
                  "</a>";
                var radio = "";
                var timeSlots = response.slots;
                radio += "<div class='mt-3 handleradio'>";
                for (k = 0; k < timeSlots.length; k++) {
                  if (timeSlots[k].start.substr(0, 10) == days[i]) {
                    radio += "<label class='btn btn-secondary' style='width: 90px'>";
                    radio +=
                      "<input type='radio' class='rButton d-none' name='options' value='" +
                      timeSlots[k].start +
                      "' id='option2'>" +
                      tConvert(timeSlots[k].start);
                    // $('.time-format').val() === "am/pm"? tConvert(timeSlots[k].start.substr(11,5)) : timeSlots[k].start.substr(11,5);
                    radio += "</label>";
                    radio += "<br>";
                  }
                }
                radio += "</div>";
                html += radio;
                html += "</div>";
            }
          });
        } else {
          var nextAvailableSlot = response.next_available_slot;
          var nextSlots = nextAvailableSlot.start;
          html += ": <button type='button' id='next-available-date' class='btn btn-outline-info btn-outline-hover-info' data-slot-val="+ nextSlots +"> "+
          "<i class='fa fa-eye'></i>" + locale["appointment_widget"]["next_slots_button"] + moment(nextSlots).format("MMMM Do, YYYY")
           +"</button>";
        }  

        if (window.finishTime) {
          var newCarousel = "";
          newCarousel += "<div class='carousel-item'>";
          newCarousel += "<div class='row pl-5 pr-5 justify-content-center'>";
          newCarousel += html;
          newCarousel += "</div>";
          newCarousel += "</div>";
          $("#carocalendar").append(newCarousel);
        } else {
          $("#dateCarousel").removeClass("d-none");
          $("#firstlist").html(html);
        }

        var days = response.days;
        window.finishTime = days[days.length - 1];
        if(window.finishTime == undefined) {
          window.finishTime = newDateFormat(new Date(data["start_time"]).addDays(7));
        }
        availableSlots = availableSlots.concat(response.slots);
        appointmentDuration = response.duration;
        offDaysCollection = response.off_days;
        firstStartDate = response.start_calendar
        var dateValidate = !_.isEmpty(days) ? new Date(days[0]) : new Date();
        dateValidate = dateValidate < response.start_calendar ? response.start_calendar : dateValidate;
        initializeDatepicker(response.start_calendar, response.calendar_days, dateValidate);
        if(!_.isEmpty(days)) {
          populateCalendarButtonText(new Date(days[0]));
        } else {
          populateCalendarButtonText(new Date());
        }
        var serviceTxt = $("#servicesSelect").find(':selected').text() === "" ?
        $("#servicesSelect")[0][1].text : $("#servicesSelect").find(':selected').text();
        $("#selectedServiceName").text(serviceTxt);
        $("#agendaDuration").text(response.duration + " min");
        $(".step2-summary").removeClass("d-none");
        // window.finishTime = response.slots.slice(-1).pop().finish;
        var cList = $("#carocalendar");
        $("#dateCarousel").carousel("next");
        if ($('#appointment_type').val() == 'schedule') $('i#backToservices').addClass('d-none');
      },
      error: function(error) {
        $("#loaderSection").removeClass("loading");
        $(".appointment-success-info").addClass("d-none");
        $(".appointmnet-error-info").removeClass("d-none");
        $(".appointmentMessage").text(locale["appointment_widget"]["appointment_static_error"]);
        $("#appointmentStatus").modal("show");
        console.log(error);
      }
    });
  }

  $(document.body).on("click", "#next-available-date", function(){
    var aSlot = $(this).data("slot-val");
    window.finishTime = new Date(aSlot).addDays(-1);
    $("#loaderSection").addClass("loading");
    window.widget_load = null;
    fetchAppointmentCalendar();
  });

  $(".carousel-control-next").click(function () {
    window.widget_load = null;
    $("#loaderSection").addClass("loading");
    fetchAppointmentCalendar();
  });


  $(document).on("change", "input[name='mobileOptions']:radio", function () {
    var $radioButtons = $("input[name='mobileOptions']:radio");
    $radioButtons.each(function() {
      $(this).parent().toggleClass('checked11', this.checked);
    });
    var selectedValue = $('input[name="mobileOptions"]:checked').val();
    var selectedSlot = availableSlots.find((x) => x.start === selectedValue);
    window.startTime = selectedSlot.start;
    window.finishTime = selectedSlot.finish;
    selecetedTimeResource = _.sample(selectedSlot.resource_id);
    var serviceTxt = $("#servicesSelect").find(':selected').text() === "" ?
          $("#servicesSelect")[0][1].text : $("#servicesSelect").find(':selected').text();
    if ($('input#appointment_type').val() == 'schedule') serviceTxt = "Demo Service";

    $(".booking-heading").text(serviceTxt);
    $("#durationH").text(appointmentDuration + " min");
    var widget_tz_by_preference = $("#widget_tz_by_preference").val();
    var selectedTimeZone = widget_tz_by_preference == "-" ? $(".timezone-select").val(): widget_tz_by_preference;
    $("#timezoneH").text(selectedTimeZone);
    $("#selectedSlotH").text(tConvert(window.startTime) + " - " + tConvert(window.finishTime) + ", " + moment(window.startTime).format("ddd, MMMM D, YYYY"));
    $("#customerDetail").removeClass("d-none");
    $("#calendarDetailSm").addClass("d-none");
    $("#timeSection").removeClass("d-block").addClass("d-none");
    $("#heading_three").removeClass("d-none");
    $("#heading_two").addClass("d-none");
  });

  $("#backToSlotsMobile").click(function(){
    $("#customerDetail").addClass("d-none");
    $("#calendarDetailSm").removeClass("d-none");
    $("#timeSection").removeClass("d-none").addClass("d-block");
    $("#heading_three").addClass("d-none");
    $("#heading_two").removeClass("d-none");
  });

  
  $(document).on("change", "input[name='options']:radio", function () {
    var $radioButtons = $("input[name='options']:radio");
    $radioButtons.each(function() {
      $(this).parent().toggleClass('checked11', this.checked);
    });
    var selectedValue = $('input[name="options"]:checked').val();
    var selectedSlot = availableSlots.find((x) => x.start === selectedValue);
    window.startTime = selectedSlot.start;
    window.finishTime = selectedSlot.finish;
    selecetedTimeResource = _.sample(selectedSlot.resource_id);
    var serviceTxt = $("#servicesSelect").find(':selected').text() === "" ? $("#servicesSelect")[0][1].text : $("#servicesSelect").find(':selected').text();
    if ($('input#appointment_type').val() == 'schedule') serviceTxt = $('input#appointment_name').val() == "" ? "Demo Service" : $('input#appointment_name').val();

    $(".booking-heading").text(serviceTxt);
    $("#durationH").text(appointmentDuration + " min");
    var widget_tz_by_preference = $("#widget_tz_by_preference").val();
    var selectedTimeZone = widget_tz_by_preference == "-" ? $(".timezone-select").val(): widget_tz_by_preference;
    $("#timezoneH").text(selectedTimeZone);
    $("#selectedSlotH").text(tConvert(window.startTime) + " - " + tConvert(window.finishTime) + ", " + moment(window.startTime).format("ddd, MMMM D, YYYY"));
    $("#customerDetail").removeClass("d-none");
    $("#prevCustomr").addClass("d-none");
    $("#timeSection").removeClass("d-block").addClass("d-none");
    $("#heading_three").removeClass("d-none");
    $("#heading_two").addClass("d-none");
  });

  $("#backToSlots").click(function(){

    if (! $('div#additonalQuestionEmbed').hasClass('d-none')) {
      $('div#additonalQuestionEmbed').addClass('d-none'); // hide question section
      $('div.customerSection').removeClass('d-none');     // show first and last name or full name section
      $('div#email_and_phone_sec').removeClass('d-none'); // show email and phone section
      $('div#serviceQuestions').html('');                 // remove question fields
    }
    else {
      $("#customerDetail").addClass("d-none");
      $("#prevCustomr").removeClass("d-none");
      $("#timeSection").removeClass("d-none").addClass("d-block");
      $("#heading_three").addClass("d-none");
      $("#heading_two").removeClass("d-none");
    }

  });

  $("#backToservices").click(function(){
    if (serviceLength > 2) {
      $("#serviceResouceRow").removeClass("d-none");
    } else {
      $("#brandingPreview").removeClass("d-none");
    }

    $("#servicesSelect, #resourcesSelect").select2({
      placeholder: locale["appointment_widget"]["select_placeholder"]
    });
    $(".localization").removeClass("d-none").addClass("d-inline-block");
    $("#step-2").addClass("d-none");
    $("#serviceNext").removeClass("d-none");
    $("#heading_two").addClass("d-none");
    $("#heading_one").removeClass("d-none");
    $("div.cancelSection").addClass("d-none");
  });

  function generateButton(elementID, type, option) {
    var parentDiv = $("<div/>").attr("id", "parent_div_"+elementID);
    $.each(option, function(id, value){
      var conElement = $("<div/>").addClass("custom-control custom-"+type)
      .append(
        $("<input/>").addClass("custom-control-input").attr({
          "name": "custom_"+type+"_"+elementID,
          "type": type,
          "id": type+"_select_"+id,
          "value": value
        }),
        $("<label/>").addClass("custom-control-label").attr("for", type+"_select_"+id).text(value)
      );
      conElement.appendTo(parentDiv)
      
    });    
    return parentDiv;
  }

  function ServiceQuestionForm(id, text, answerType, options) {
    var htmlStructure = {
      oneline: "<input class='form-control'>",
      multilines: "<textarea class='form-control' rows='4'></textarea>",
      radiobuttons: _.isEmpty(options) ? "" : generateButton(id, "radio", options),
      checkboxes: _.isEmpty(options) ? "" : generateButton(id, "checkbox", options),
    };

    return $("<div/>")
        .addClass("form-group mb-3 service_questions")
        .attr({
          "id": "service_question_"+id,
          "data-eletype": answerType
        })
        .append($("<label/>").text(text))
        .append(htmlStructure[answerType])
  }

  function fetchMandatoryQuestions() {
    $.ajax({
      type: 'POST',
      url: "/get_mandatory_question",
      data: {
        authenticity_token: $('[name="csrf-token"]')[0].content,
        service_id: $("#servicesSelect").val() === "" ? $("#servicesSelect")[0][1].value : $("#servicesSelect").val()
      },
      success: function(response) {
        $("#loaderSection").removeClass("loading");
        $(".phone-invalid-feedback").addClass("d-none");
        $(".customerSection").removeClass("d-none");
        $("#checkPhoneValidity").addClass("d-none");

        if (response.mandatory_question == 'fullname') {
          $('div.full_name').removeClass('d-none');
          $('div.first_lastname').addClass('d-none');
        }
        if (response.mandatory_question == 'first_lastname') {
          $('div.full_name').addClass('d-none');
          $('div.first_lastname').removeClass('d-none');
        }
      }
    })
  }

  function fetchQuestions(customerID) {
    const service_id = $('input#appointment_type').val() == 'schedule' ? $('input#appointment_service_id').val() : ($("#servicesSelect").val() === "" ? $("#servicesSelect")[0][1].value : $("#servicesSelect").val())
    $.ajax({
      type: "POST",
      url: "/linked_questions",
      async: false,
      data: {
        service_id: service_id
      },
      success: function (data) {
        $("#loaderSection").removeClass("loading");
        // if array is empty call book appointment otherwise open modal
        if(!_.isEmpty(data.questions_data)) {
          additionalQuestionDisplay(data.questions_data, customerID);
        } else {
          const questionDetails = [];
          if ($('input#appointment_type').val() == 'schedule') {
            data["authenticity_token"] = $('[name="csrf-token"]')[0].content;
            data["first_name"] = $("input#appointment_customer_firstname").val();
            data["last_name"] = $("input#appointment_customer_lastname").val();
            data["email"] = $("input#appointment_customer_email").val();
            data["phone_number"] = $("input#appointment_customer_phone").val();
            data["question_details"] = questionDetails;
            bookAppointmentForSchedule(data);
          }
          else bookAppointment(customerID, questionDetails);
        }        
      },
      error: function (error) {
        $("#loaderSection").removeClass("loading");
        console.log(error);
      },
    });
  }

  $("#additional-question-submit").click(function(){
    var questionDetails = [];
    var saveAppointment = true;
    var unanswerQuestion = [];
    $(".question-error ul li").remove();
    $.each( appointmentQuestions, function( key, value ) {
      var ans = generateAnswer(key, $("#service_question_"+key).data("eletype"));
      if((ans === "" || ans === undefined || ans === null) && value.mandatory) {
        unanswerQuestion.push(value.text);
        saveAppointment = false;
        return;
      }
      questionDetails.push({
        "question": value.text,
        "question_type": $("#service_question_"+key).data("eletype"),
        "answer": generateAnswer(key, $("#service_question_"+key).data("eletype"))
      })
    });
    if(!saveAppointment) {
      $(".question-error").removeClass("d-none");
      $.each(unanswerQuestion, function(key, value){
        $(".question-error ul").append("<li>"+value+"</li>");
      });
    }
    if(saveAppointment) {
      $(".question-error").addClass("d-none");

      const questions = JSON.stringify(questionDetails);
      if ($('input#appointment_type').val() == 'schedule') {
        let data = [];
        data["authenticity_token"] = $('[name="csrf-token"]')[0].content;
        data["first_name"] = $("input#appointment_customer_firstname").val();
        data["last_name"] = $("input#appointment_customer_lastname").val();
        data["email"] = $("input#appointment_customer_email").val();
        data["phone_number"] = $("input#appointment_customer_phone").val();
        data["question_details"] = questions;
        bookAppointmentForSchedule(data);
      }
      else bookAppointment(appointmentCustomerID, questions);
    }
  });

  function additionalQuestionDisplay(questions, customerID) {
    appointmentQuestions = questions;
    appointmentCustomerID = customerID;
    $("#email_and_phone_sec").addClass("d-none");
    $(".customerSection").addClass("d-none");
    $("#additonalQuestionEmbed").removeClass("d-none");
    $.each( questions, function( key, value ) {
      $("#serviceQuestions").append(
        ServiceQuestionForm(key, value.text, value.answer_type, value.options)
      );
    });
  }

  function generateAnswer(key, type) {
    var getAns;
    switch(type) {
      case "multilines":
        getAns = "#service_question_"+key +" textarea"
        break;
      case "radiobuttons":
        getAns = $("#service_question_"+key+" input[name='custom_radio_"+key+"']:checked")
        break;
      case "checkboxes":
        getAns = $("#service_question_"+key+" input[name='custom_checkbox_"+key+"']:checked")
        break;
      default:
        getAns = "#service_question_"+key +" input"
    }
    if(type === "checkboxes") {
      var checkAnswers = [];
      $(getAns).each(function(i){
        checkAnswers.push($(this).val());
      });
      return checkAnswers.toString();
    }
    return $(getAns).val();
  }

  function bookAppointmentForSchedule(data) {
    data["ivr_id"] = $("#ivrid").val();
    data["start_time"] = window.startTime;
    data["end_time"] = window.finishTime;
    data["event_id"] = $('#event_id').val();
    data["service_id"] = $('input#appointment_service_id').val()
    data["resource_id"] = $('input#appointment_resource_id').val()

    const d = new Date();
    data["local_timezone"] = d.getTimezoneOffset() * -1;
    $("#loaderSection").addClass("loading");
    $.ajax({
      type: "POST",
      url: "/book_appointment_for_schedule",
      data: {
        ivr_id: data["ivr_id"],
        event_name: $('input#appointment_name').val(),
        start_time: data['start_time'],
        end_time: data['end_time'],
        event_id: data['event_id'],
        service_id: data['service_id'],
        resource_id: data['resource_id'],
        first_name: data['first_name'],
        last_name: data['last_name'],
        email: data['email'],
        phone_number: data['phone_number'],
        question_details: data['question_details'],
        local_timezone: data['local_timezone'],
        customer_id: $("input#appointment_customer_id").val()
      },
      success: function (response) {
        $("#loaderSection").removeClass("loading");
        $(".appointment-success-info").removeClass("d-none");
        $(".appointmnet-error-info").addClass("d-none");
        $("#loaderSection").removeClass("loading");

        $("h4.appointment-result-text").html($('input#appointment_reschedule_success').val());
        $("#customerNameH").text(data['first_name'] + " " + data['last_name'])
        $("#customerEmailH").text(data['email'])
        $("#customerPhoneH").text(data['phone_number'])
        $("#customerDurationH").text($("#durationH").text())
        $("#customertimezoneH").text($("#timezoneH").text())
        $("#customerSelectedTimeH").text($("#selectedSlotH").text())
        $("#appointmentStatus").modal("show");
      },
      error: function (error) {
        $("#loaderSection").removeClass("loading");
        $(".appointment-success-info").addClass("d-none");
        $(".appointmnet-error-info").removeClass("d-none");
        $(".appointmentMessage").text(error.responseJSON.message);
        $("#appointmentStatus").modal("show");
        console.log("errorrrr", error);
      },
    });
  }
  function bookAppointment(customerID, questionDetails) {
    var resourceForBackend;
    if($("#servicesSelect").find(':selected').data('random-resource-select')) {
      resourceForBackend = selecetedTimeResource;
    } else {
      resourceForBackend = $('input#appointment_type').val() == 'schedule' ? $('input#appointment_resource_id').val() : ($("#resourcesSelect").val() === "" ? $("#resourcesSelect")[0][1].value : $("#resourcesSelect").val());
    }
    $("#loaderSection").addClass("loading");
    var data = {};
    data["ivr_id"] = $("#ivrid").val();
    data["customer_id"] = customerID;
    data["resource_id"] = resourceForBackend;
    data["service_id"] = $("#servicesSelect").val() === "" ? $("#servicesSelect")[0][1].value : $("#servicesSelect").val();
    data["slot_start"] = window.startTime;
    data["slot_end"] = window.finishTime;
    data["question_details"] = questionDetails;
    data["authenticity_token"] = $('[name="csrf-token"]')[0].content;

    $.ajax({
      type: "POST",
      url: "/book_appointment",
      data: data,
      success: function (response) {
        $(".appointment-success-info").removeClass("d-none");
        $(".appointmnet-error-info").addClass("d-none");
        $("#loaderSection").removeClass("loading");

        $("h4.appointment-result-text").html(response.message);
        $("#customerNameH").text(clientDetail.first_name + " " + clientDetail.last_name)
        $("#customerEmailH").text(clientDetail.email)
        $("#customerPhoneH").text(clientDetail.phone_number)
        $("#customerDurationH").text($("#durationH").text())
        $("#customertimezoneH").text($("#timezoneH").text())
        $("#customerSelectedTimeH").text($("#selectedSlotH").text())        
        $("#appointmentStatus").modal("show");
      },
      error: function (error) {
        $("#loaderSection").removeClass("loading");
        $(".appointment-success-info").addClass("d-none");
        $(".appointmnet-error-info").removeClass("d-none");
        $(".appointmentMessage").text(error.responseJSON.message);
        $("#appointmentStatus").modal("show");
        console.log("errorrrr", error);
      },
    });
  }



  function emailIsValid (email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  }

  $("#checkValidity").click(function () {
    const emailValue = $("#appointmentEmail");
    if (emailValue.val() == "") {
      $(".email-empty-feedback").removeClass("d-none");
    } else if (!emailIsValid(emailValue.val())) {
      $(".email-empty-feedback").addClass("d-none");
      $(".email-invalid-feedback").removeClass("d-none");
    }
    else {
      $(".email-empty-feedback").addClass("d-none");
      $(".email-invalid-feedback").addClass("d-none");
      $("#loaderSection").addClass("loading");
      $.ajax({
        type: "POST",
        url: "/validate_customer",
        data: {
          authenticity_token: $('[name="csrf-token"]')[0].content,
          email: emailValue.val(),
          ivr_id: $("#ivrid").val(),
        },
        success: function (data) {
          $("#loaderSection").removeClass("loading");
          if (data.customer_data) {
            // book an appointment
            clientDetail = data.customer_data;
            $("#checkValidity").addClass("d-none");
            if (clientDetail.phone_number == "" || $("#appointment_type").val() == 'schedule')
              $(".phoneSection").removeClass("d-none");
            else if (clientDetail.first_name == "" || clientDetail.first_name == "X." )
              fetchMandatoryQuestions();
            else
              fetchQuestions(data.customer_data.id);
          }
          else if (data.email_status == false) {
            Swal.fire({
              text: $('input#email_validation_message').val(),
              icon: "error",
              buttonsStyling: false,
              confirmButtonText: $('input#ok_got_it').val(),
              customClass: {
                confirmButton: "btn btn-primary"
              }
            });
          }
          else {
            $("#checkValidity").addClass("d-none");
            $(".phoneSection").removeClass("d-none");
          }

        },
        error: function (error) {
          $("#loaderSection").removeClass("loading");
          console.log(error);
        },
      });
    }
  });

  $('button#cancelEvent').click(function() {
    $("#loaderSection").addClass("loading");
    $.ajax({
      type: 'post',
      url: '/cancel_appointment',
      data: {
        ivr_id: $('input#ivrid').val(),
        event_id: $('input#event_id').val(),
        reason: $('textarea#appointmentReason').val()
      },
      success: function(response) {
        if (response.result == 'success') {
          $("#loaderSection").removeClass("loading");
          $(".appointment-success-info").removeClass("d-none");
          $(".appointmnet-error-info").addClass("d-none");
          $("h4.appointment-result-text").html(response.message);
          $("#customerNameH").text($('input#appointment_customer_name').val());
          $("#customerEmailH").text($('input#appointment_customer_email').val());
          $("#customerPhoneH").text($('input#appointment_customer_phone').val());
          $("#customerDurationH").text($("#durationH").text())
          $("#customertimezoneH").text($("#timezoneH").text())
          $("#customerSelectedTimeH").text($("#selectedSlotH").text())
          $("#appointmentStatus").modal("show");
        }
        else {
          $("#loaderSection").removeClass("loading");
          $(".appointment-success-info").addClass("d-none");
          $(".appointmnet-error-info").removeClass("d-none");
          $("h4.appointment-error-text").html($('input#appointment_invalid_cancel').val());
          $(".appointmentMessage").text(response.message);
          $("#appointmentStatus").modal("show");
        }

      }
    })
  })

  function updateEmailForExistingPhoneNumber(customerData) {
    var data = {};
    data["customer_id"] = customerData.id;
    data["email"] = $("#appointmentEmail").val();
    data["authenticity_token"] = $('[name="csrf-token"]')[0].content;
    $.ajax({
      type: "POST",
      url: "/update_customer",
      data: data,
      success: function (data) {
        if (customerData.first_name == "" || customerData.first_name == "X." || $("#appointment_type").val() == 'schedule')
          fetchMandatoryQuestions();
        else
          fetchQuestions(customerData.id);
        clientDetail.email = $("#appointmentEmail").val();
      },
      error: function (error) {
        fetchQuestions(customerData.id);
        console.log("updateEmailForExistingPhoneNumber error:", error);
      },
    });
  }

  $("#checkPhoneValidity").click(function () {
    var phoneValue = $("#appointmentPhoneNumber");
    var emailValue = $("#appointmentEmail");
    if (emailValue.val() == "") {
      $(".email-empty-feedback").removeClass("d-none");
    } else if (!emailIsValid(emailValue.val())) {
      $(".email-empty-feedback").addClass("d-none");
      $(".email-invalid-feedback").removeClass("d-none");
    } else {
      $(".email-empty-feedback").addClass("d-none");
      $(".email-invalid-feedback").addClass("d-none");
      if (phoneValue.val() != "") {
        $(".phone-invalid-feedback").addClass("d-none");
        var obj = document.querySelector("#appointmentPhoneNumber");
        var iti = window.intlTelInputGlobals.getInstance(obj);
        var number = iti.getNumber();
        $(obj).val(number);
        if(iti.isValidNumber()) {
          $("#loaderSection").addClass("loading");

          $.ajax({
            type: "POST",
            url: "/validate_customer",
            data: {
              authenticity_token: $('[name="csrf-token"]')[0].content,
              email: $("#appointmentEmail").val(),
              phone: phoneValue.val(),
              ivr_id: $("#ivrid").val(),
            },
            success: function (data) {
              $("#loaderSection").removeClass("loading");
              if (data.customer_data) {
                // book an appointment
                $("#loaderSection").addClass("loading");
                clientDetail = data.customer_data;
                if(data.customer_data.email != $("#appointmentEmail").val()) {
                  // update EMAIL:
                  updateEmailForExistingPhoneNumber(data.customer_data);
                } else {
                  if (clientDetail.first_name == "" || clientDetail.first_name == "X." || $("#appointment_type").val() == 'schedule')
                    fetchMandatoryQuestions();
                  else
                    fetchQuestions(clientDetail.id);
                }

              } else {
                if (data.phone_status == true){
                  $(".phone-invalid-feedback").addClass("d-none");
                  $(".customerSection").removeClass("d-none");
                  $("#checkPhoneValidity").addClass("d-none");
                  fetchMandatoryQuestions();
                }
                else if (data.email_status == false) {
                  Swal.fire({
                    text: $('input#email_validation_message').val(),
                    icon: "error",
                    buttonsStyling: false,
                    confirmButtonText: $('input#ok_got_it').val(),
                    customClass: {
                      confirmButton: "btn btn-primary"
                    }
                  });
                }
                else {
                  $(".phone-invalid-feedback").removeClass("d-none");
                  $(".phone-invalid-feedback").text(locale["appointment_widget"]["phone_number_not_valid"]);
                }
              }
            },
            error: function (error) {
              $("#loaderSection").removeClass("loading");
              console.log(error);
            },
          });
        }
      } else {
        $(".phone-invalid-feedback").removeClass("d-none");
      }
    }  
  });

  function reset() {
    $("#appointmentPhoneNumber").css("border-color", "");
    $("#appointmentPhoneNumber-valid-msg").hide();
    $("#appointmentPhoneNumber-error-msg").hide();
  }

  $("#appointmentPhoneNumber").on("change", function () {
    reset();
    $(".phone-invalid-feedback").addClass("d-none");

    // if ($("#appointmentPhoneNumber").intlTelInput("isValidNumber")) {
    if (iti.isValidNumber()) {
      $("#appointmentPhoneNumber-valid-msg").show();
    } else {
      $("#appointmentPhoneNumber").css("border-color", "#f4516c");
      $("#appointmentPhoneNumber-error-msg").show();
    }
  });

  $("#createCustomer").click(function () {
    let firstName = '';
    let lastName = '';
    if ($('div.full_name').hasClass('d-none')) {
      $("div.first_lastname #customerFirstName").val($("div.first_lastname #customerFirstName").val().trim());
      $("div.first_lastname #customerLastName").val($("div.first_lastname #customerLastName").val().trim());
      firstName = $("div.first_lastname #customerFirstName").val();
      lastName = $("div.first_lastname #customerLastName").val();
    }
    else {
      const full_name = $("div.full_name #customerFullName").val().trim();
      const names = full_name.split(' ');
      if (names.length >= 2) {
        firstName = names[0];
        lastName = names[1];
        for (let i = 2; i < names.length; i ++) {
          lastName += ' ' + names[i];
        }
      }
      else {
        firstName = full_name;
        lastName = '';
      }
      $("input#customerFirstName").val(firstName);
      $("input#customerLastName").val(lastName);
    }


    if(firstName != "" && firstName.length >= 2) {
      $(".first-invalid-feedback").addClass("d-none");
    } else {
      $(".first-invalid-feedback").removeClass("d-none");
      return;
    }

    if (! $('div.first_lastname').hasClass('d-none')) {
      if(lastName != "" && lastName.length >= 2) {
        $(".last-invalid-feedback").addClass("d-none");
      } else {
        $(".last-invalid-feedback").removeClass("d-none");
        return;
      }
    }


    var data = {};
    data["authenticity_token"] = $('[name="csrf-token"]')[0].content;
    data["ivr_id"] = $("#ivrid").val();
    data["first_name"] = $("#customerFirstName").val();
    data["last_name"] = $("#customerLastName").val();
    data["email"] = $("#appointmentEmail").val();
    data["phone_number"] = $("#appointmentPhoneNumber").val();
    $("#loaderSection").addClass("loading");

    $.ajax({
      type: "POST",
      url: "/create_new_customer",
      data: data,
      success: function (data) {
        $("#loaderSection").removeClass("loading");
        if (data) {
          // book an appointment
          $("#loaderSection").addClass("loading");
          clientDetail = data;
          if ($("#appointment_type").val() == 'schedule') {
            $("input#appointment_customer_id").val(clientDetail.id);
            fetchQuestions($('input#appointment_customer_id').val());
            const answer_data = JSON.parse($("input#appointment_answers").val());
            $.each(answer_data, function (index, answer) {
              $.each($('div#serviceQuestions').find('div.service_questions'), function(index, question_obj) {
                if ($(question_obj).find('label').html() == answer.question_text) {
                  if (answer.question_type == 'oneline') $(question_obj).find('input').val(answer.text);
                  if (answer.question_type == 'multilines') $(question_obj).find('textarea').val(answer.text);
                  if (answer.question_type == 'radiobuttons') {
                    $(question_obj).find('input[type=radio][value="' + answer.text + '"]').prop('checked', true);
                  }
                  if (answer.question_type == 'checkboxes') {
                    $.each(answer.text.split(','), function(index, ans) {
                      $(question_obj).find('input[type=checkbox][value="' + ans + '"]').prop('checked', true);
                    })
                  }
                }
              });
            });
            // bookAppointmentForSchedule(data);
          }
          else fetchQuestions(data.id);
        } else {
          $("#customerCreate").removeClass("d-none");
          $("#checkValidity").addClass("d-none");
        }
      },
      error: function (error) {
        $("#loaderSection").removeClass("loading");
        console.log(error);
      },
    });
  });

  function clockUpdate() {
    var date = new Date();
    var time_format = moment(date.getTime());
    var widget_tz_by_preference = $("#widget_tz_by_preference").val();
    var selectedTimeZone = widget_tz_by_preference == "-" ? ($(".timezone-select").val() || "UTC"): widget_tz_by_preference;
    var formatType;
    var checkTZPreference = $("#widget_tf_by_preference").val();
    var checkAvailableFormats = checkTZPreference == "-" ? $(".time-format").val() : checkTZPreference;
    if (checkAvailableFormats === "am/pm") {
      formatType = "hh:mm:ss A";
    } else {
      formatType = "HH:mm:ss"
    }
    if (selectedTimeZone) {
      $('#currentTime').text('('+time_format.tz(selectedTimeZone).format(formatType) + ')')
    }
  }
  clockUpdate();
  setInterval(clockUpdate, 1000);

  // function fetchUpdatedSelectResouce(selectedAPIValue, ApiType) {
  //   var data = {};
  //   data["id"] = selectedAPIValue;
  //   data["type"] = ApiType;
  //   data["authenticity_token"] = $('[name="csrf-token"]')[0].content,
  //   $.ajax({
  //     type: "POST",
  //     url: "/linked_services_or_resources",
  //     data: data,
  //     success: function (data) {
  //       updateSelect2(ApiType, data);
  //     },
  //     error: function (error) {
  //       console.log(error);
  //     },
  //   });
  // }

  function updateSelect2(type, data) {
    if(type == "service") {
      $("#resourcesSelect > option").each(function() {
        if (data.linked_data.includes(parseInt(this.value))) {
          $(this).prop("disabled", false);
        } else {
          $(this).prop("disabled", true);
        }
      });

      const randomResourceSelect = $("#servicesSelect").find(':selected').data('random-resource-select');
      if(resouceLength > 2) { 
        if (randomResourceSelect) {
          $("#resourcesSelect").val(_.sample(data.linked_data)).trigger('change');
          $("#resoucrOptions").addClass('d-none');
          $("#serviceOptions").addClass("mx-auto");
          $("#serviceNext").attr("disabled", false);
        } else {
          $("#resourcesSelect").val('').trigger('change');
          $("#serviceOptions").removeClass("mx-auto");
          $("#resoucrOptions").removeClass('d-none');
        }
      }
    } else {
      $("#servicesSelect > option").each(function() {
        if (data.linked_data.includes(parseInt(this.value))) {
          $(this).prop("disabled", false);
        } else {
          $(this).prop("disabled", true);
        }
      });
    }
    $(".no-disable").prop("disabled", false);
    $("#servicesSelect, #resourcesSelect").select2({
      placeholder: locale["appointment_widget"]["select_placeholder"]
    });
  }

  $('#servicesSelect').on('select2:select', function (e) {
    if(level1dropdownForWidget != "Custom Order") {
      if($("#resourcesSelect").val() != "" && $("#servicesSelect").val() != "") {
        $("#serviceNext").attr("disabled", false);
      }
    }
    //var serviceID = $("#servicesSelect").val();
    if(level1dropdownForWidget != "Service Only") {
      if(resouceLength != 2) {
        $("#serviceNext").attr("disabled", true);
      }
      //fetchUpdatedSelectResouce(serviceID, "service");
    }
  });

  $('#resourcesSelect').on('select2:select', function (e) {
    if(level1dropdownForWidget != "Custom Order") {
      if($("#resourcesSelect").val() != "" && $("#servicesSelect").val() != "") {
        $("#serviceNext").attr("disabled", false);
      }
    }
    //var resourceID = $("#resourcesSelect").val();
    //fetchUpdatedSelectResouce(resourceID, "resource");
  });

  // mobile code
  $('#calendarButtonMobile').datepicker({});
});
