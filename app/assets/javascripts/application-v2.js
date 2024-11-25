// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery.js
//= require jquery_ujs
//= require bootstrap-timepicker.js
//= require ./cable
//= require metronic-v6/manifest
//= require moment-locales.js
//= require moment-timezone-with-data
//= require data
//= require basic
//= require select2
//= require datatables.bundle
//= require intlTelInput
//= require intlTelInput.min
//= require jquery_nested_form
//= require chosen.jquery.min
//= require clipboard
//= require lodash.min
//= require bootstrap-datepicker.min
//= require locales/bootstrap-datepicker.de.min
//= require locales/bootstrap-datepicker.el.min
//= require locales/bootstrap-datepicker.fr.min
//= require locales/bootstrap-datepicker.it.min
//= require appointment_widget

function submitForm(str) {
  if ($("#vox-first").length != 0) {
    $("#vox-first").submit();
  } else if ($("#greetings_form").length != 0) {
    $("#greetings_form").submit();
  } else {
    $("form").submit();
  }
}

var getUrlParameter = function getUrlParameter(sParam) {
  var sPageURL = window.location.search.substring(1),
    sURLVariables = sPageURL.split("&"),
    sParameterName,
    i;

  for (i = 0; i < sURLVariables.length; i++) {
    sParameterName = sURLVariables[i].split("=");
    if (sParameterName[0] === sParam) {
      return sParameterName[1] === undefined
        ? true
        : decodeURIComponent(sParameterName[1]);
    }
  }
};

function getCookie(name) {
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) return parts.pop().split(';').shift();
}

// programmatically set the value of a select box element using JavaScript
var setSelectValue = function selectElement(id, valueToSelect) {
  let element = document.getElementById(id);
  element.value = valueToSelect;
};

var localeParam = getUrlParameter("locale") ? getUrlParameter("locale") : "en";
var localeURL =
  window.location.origin + "/locales/datatables/" + localeParam + ".json";
$.extend(true, $.fn.dataTable.defaults, {
  language: {
    url: localeURL,
  },
});

$(document).ready(function () {
  // set localzation select box value
  var localeValue = getUrlParameter("locale")
    ? getUrlParameter("locale")
    : "en";
  if (localeValue) {
    $(".localization").val(localeValue);
  }

  $(".localization").on("change", function () {
    var requestParameters = ["?locale=" + $(this).val()];
    var path = window.location.pathname + requestParameters.join("");
    window.location.href = path;
  });

  var timezone = moment.tz.names();
  for (var i = 0; i < timezone.length; i++) {
    $(".timezone-select").append(
      '<option value="' + timezone[i] + '">' + timezone[i] + "</option>"
    );
  }
  $(".timezone-select").select2();

  var time_zone_default = $(".time_zone_default").val();
  if (time_zone_default) {
    $(".timezone-select").val(time_zone_default).trigger("change");
  }

  var first_login = $("#first_login").val();
  console.log("first login", first_login)
  if(first_login) {
    $('#after-signup-modal').modal({
      show: true
    });
  }

  $("#startDemo").click(function(){
    $("#onboardingDemoStep").addClass("d-none");
    $(this).addClass("d-none");
    $("#onBoardingCheckOutStep").removeClass("d-none");
    $("#onBoardingCheckOut").removeClass("d-none");
  });

  $("#onBoardingCheckOut").click(function(){
    $("#onBoardingCheckOutStep").addClass("d-none");
    $(this).addClass("d-none");
    $("#video-intro").removeClass("d-none");
    $("#continueOnboarding").removeClass("d-none");
  });

  $("#continueOnboarding").click(function(){
    $("#video-intro").addClass("d-none");
    $("#classic-agenda").removeClass("d-none");
    $("#backOnBoarding").removeClass("d-none");
    $(this).addClass("d-none");
    $("#after-signup-modal .modal-dialog").removeClass("modal-lg");
  });

  $("#backOnBoarding").click(function(){
    $("#video-intro").removeClass("d-none");
    $("#classic-agenda").addClass("d-none");
    $("#continueOnboarding").removeClass("d-none");
    $(this).addClass("d-none");
    $("#after-signup-modal .modal-dialog").addClass("modal-lg");
  });

  $(".clipboard-btn").tooltip({
    trigger: "click",
    placement: "bottom",
  });

  function setTooltip(btn, message) {
    $(btn).tooltip("show").attr("data-original-title", message).tooltip("show");
  }

  function hideTooltip(btn) {
    setTimeout(function () {
      $(btn).tooltip("hide");
    }, 1000);
  }

  // Clipboard
  var clipboard = new Clipboard(".clipboard-btn");

  clipboard.on("success", function (e) {
    setTooltip(e.trigger, "Copied!");
    hideTooltip(e.trigger);
  });

  clipboard.on("error", function (e) {
    setTooltip(e.trigger, "Failed!");
    hideTooltip(e.trigger);
  });

  var messageLength = 0;
  var maxchar = 160;
  $("#smsMessage").keyup(function () {
    messageLength = this.value.length;
    if (messageLength > maxchar) {
      return false;
    } else if (messageLength > 0) {
      $("#remainingC").html(maxchar - messageLength);
    } else {
      $("#remainingC").html(maxchar);
    }
  });

  var input = document.querySelector("#messagePhone");
  if (input) {
    iti = window.intlTelInput(input, {
      preferredCountries: ["fr", "be", "de", "gb", "us", "ca"],
      utilsScript: "/assets/utils.js",
      geoIpLookup: function (callback) {
        $.get(
          "https://api.ipdata.co?api-key=" + IPdata_key,
          function () {},
          "jsonp"
        ).always(function (resp) {
          var countryCode = (resp && resp.country_code) ? resp.country_code : "fr";
          callback(countryCode);
        });
      },
    });
  }

  window.addEventListener('load', function() {
    console.log('loaded');
    // Fetch all the forms we want to apply custom Bootstrap validation styles to
    var forms = document.getElementsByClassName('needs-validation');
    console.log('check');
    // Loop over them and prevent submission
    var validation = Array.prototype.filter.call(forms, function(form) {
      console.log('enterd 11111111111111');
      form.addEventListener('submit', function(event) {
        if (form.checkValidity() === false) {
          event.preventDefault();
          event.stopPropagation();
        }
        form.classList.add('was-validated');
        var obj = document.querySelector("#messagePhone");
        var iti = window.intlTelInputGlobals.getInstance(obj);
        var number = iti.getNumber();
        $(obj).val(number);
      }, false);
    });
  }, false);
  $(".clickable-1").click(function() {
    window.open("http://localhost:3000/s/9997772515?locale=en", "_blank");
  })
});

$(document).ready(function () {
  new KTAvatar(document.getElementById('logo'));
});
