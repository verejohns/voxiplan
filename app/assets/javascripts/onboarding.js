"use strict";

// Class definition
var KTCreateAccount = function () {
  // Elements
  var stepper;
  var form;
  var formSubmitButton;
  var startIndex;

  // Variables
  var stepperObj;
  var validations = [];

  // Private Functions
  var initStepper = function () {
    // Initialize Stepper
    stepperObj = new KTStepper(stepper, {startIndex: startIndex});


    // Validation before going to next page
    stepperObj.on('kt.stepper.next', function (stepper) {
      // if (stepper.getCurrentStepIndex() == 1 && startIndex == 1) {
      //     if (startIndex == 1) $('button[data-kt-stepper-action=next]').addClass('disabled')
      //     if (startIndex == 3) $('button[data-kt-stepper-action=next]').removeClass('disabled')
      // }
      // else
      //     $('button[data-kt-stepper-action=next]').removeClass('disabled')


      // Validate form before change stepper step
      var validator = validations[stepper.getCurrentStepIndex() - 1]; // get validator for currnt step

      if (validator) {
        validator.validate().then(function (status) {
            if (status == 'Valid') {
                if (!$('#detected_key_message').is(":visible")) {
                    $.ajax({
                        type: "POST",
                        url: "/check_exist_ivr_url",
                        data: { voxiplan_url: $('#voxiplan_url').val().toLowerCase(), ivr_id: $('#voxiplan_url').attr('ivr_id') },
                        success: function (data) {
                            if (!data.existed) {
                                $.ajax({
                                    url: "/save_voxiplan_url",
                                    type: "POST",
                                    data: {
                                        voxiplan_url: $('input#voxiplan_url').val().toLowerCase(),
                                        organization_name: $('input#organization_name').val()
                                    },
                                    success: function(response){
                                        if (response.success) {
                                            stepper.goNext();

                                            KTUtil.scrollTop();
                                        } else {

                                        }
                                    }
                                });
                            }
                        },
                        error: function (error) {
                            $.notify({ title: "<strong>Error!</strong>", message: "Something Went Wrong! Please Try again." },{ type: 'danger' });
                        },
                    });
                }
            } else {
                if (stepper.getCurrentStepIndex() - 1) {
                    Swal.fire({
                        text: $('input#normal_error_text').val(),
                        icon: "error",
                        buttonsStyling: false,
                        confirmButtonText: $('input#ok_got_it').val(),
                        customClass: {
                            confirmButton: "btn btn-light"
                        }
                    }).then(function () {
                        KTUtil.scrollTop();
                    });
                }
            }
        });
      } else {
        stepper.goNext();

        KTUtil.scrollTop();
      }
    });

    // Prev event
    stepperObj.on('kt.stepper.previous', function (stepper) {
      // if (stepper.getCurrentStepIndex() == 3 && startIndex == 1) {
      //   if (startIndex == 1) $('button[data-kt-stepper-action=next]').addClass('disabled');
      //   if (startIndex == 3) $('button[data-kt-stepper-action=next]').removeClass('disabled');
      // }
      // else
      //   $('button[data-kt-stepper-action=next]').removeClass('disabled');

      stepper.goPrevious();
      KTUtil.scrollTop();
    });
  }

  var handleForm = function () {
    formSubmitButton.addEventListener('click', function (e) {
      // Prevent default button action
      e.preventDefault();

      // Disable button to avoid multiple click
      formSubmitButton.disabled = true;

      // Show loading indication
      formSubmitButton.setAttribute('data-kt-indicator', 'on');
      formSubmitButton.disabled = true;
      $(form).ajaxSubmit({
          success: function(response) {
              window.location.href = response.redirect_url;
          }
      })

    });
  }

  var initValidation = function () {
    // Init form validation rules. For more info check the FormValidation plugin's official documentation:https://formvalidation.io/
    // Step 1
    validations.push(FormValidation.formValidation(
      form,
      {
        fields: {
          'voxiplan_url': {
            validators: {
              notEmpty: {
                message: 'Can’t be empty'
              }
            }
          },
            'organization_name': {
                validators: {
                    notEmpty: {
                        message: 'Can’t be empty'
                    }
                }
            },
          'timezone': {
            validators: {
              notEmpty: {
                message: 'Please, select time zone.'
              }
            }
          },
        },
        plugins: {
          trigger: new FormValidation.plugins.Trigger(),
          // tachyons: new FormValidation.plugins.Tachyons({
          //   defaultMessageContainer: false,
          // }),
          bootstrap: new FormValidation.plugins.Bootstrap5({
            rowSelector: '.fv-row',
            eleInvalidClass: '',
            eleValidClass: ''
          }),
          // message: new FormValidation.plugins.Message({
          //   container: function (field, el) {
          //     return FormValidation.utils.closest(el, '.fv-row');
          //   },
          // }),
        }
      }
    ));

    // Step 3
    validations.push(FormValidation.formValidation(
      form,
      {
        fields: {
          // 'available_hours_from': {
          //   validators: {
          //     notEmpty: {
          //       message: 'Please, fill available hours.'
          //     }
          //   }
          // },
          // 'available_hours_to': {
          //   validators: {
          //     notEmpty: {
          //       message: 'Please, fill available hours.'
          //     }
          //   }
          // },
          // 'available_days': {
          //   validators: {
          //     notEmpty: {
          //       message: 'Please select available days.'
          //     }
          //   }
          // }
        },
        plugins: {
          trigger: new FormValidation.plugins.Trigger(),
          // Bootstrap Framework Integration
          bootstrap: new FormValidation.plugins.Bootstrap5({
            rowSelector: '.fv-row',
            eleInvalidClass: '',
            eleValidClass: ''
          })
        }
      }
    ));
  }

  return {
    // Public Functions
    init: function () {

      stepper = document.querySelector('#kt_create_account_stepper');
      startIndex = document.querySelector('#agenda_app_stepIndex').value;
      form = stepper.querySelector('#kt_create_account_form');
      formSubmitButton = stepper.querySelector('[data-kt-stepper-action="submit"]');

      initStepper();
      initValidation();
      handleForm();
    }
  };
}();

// On document ready
KTUtil.onDOMContentLoaded(function () {
  KTCreateAccount.init();
});