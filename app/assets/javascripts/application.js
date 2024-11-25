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
//= require bootstrap-timepicker.js
//= require jquery_ujs
//= require lodash.min
//= require jquery-ui.bundle
//= require moment-locales.js
//= require moment-timezone-with-data
//= require jquery.form.min

// $(document).ready(function () {
  //TODO: Remove reference logic
  // toggleAgendaFields();
  //
  // $("#client_agenda_app_attributes_type").change(function() {
  //   toggleAgendaFields();
  // });
  //
  // function toggleAgendaFields() {
  //   $(".agenda-app").addClass('hidden');
  //   var app = $("#client_agenda_app_attributes_type").val();
  //   if (app == 'SuperSaas'){
  //     $("#super-saas-feilds").removeClass('hidden');
  //   } else if(app == 'Mobminder'){
  //     $("#mobminder-feilds").removeClass('hidden');
  //   }
  // }
//for registration and profile phone

// for select2
  // $('.m-select2').select2();
// });

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

function showMessage(message_type, message) {
  toastr.options = {
    closeButton: false,
    debug: false,
    newestOnTop: false,
    progressBar: false,
    positionClass: "toast-top-right",
    preventDuplicates: false,
    onclick: null,
    showDuration: "300",
    hideDuration: "1000",
    timeOut: "5000",
    extendedTimeOut: "1000",
    showEasing: "swing",
    hideEasing: "linear",
    showMethod: "fadeIn",
    hideMethod: "fadeOut",
  };
  if (message_type == 'success') toastr.success(message);
  if (message_type == 'error') toastr.error(message);
  if (message_type == 'warning') toastr.warning(message);
  if (message_type == 'info') toastr.info(message);
}