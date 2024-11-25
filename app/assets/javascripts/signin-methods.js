"use strict";

// Class definition
var KTAccountSettingsSigninMethods = function () {
    // Private functions
    var initSettings = function () {

        // UI elements
        const signInMainEl = document.getElementById('kt_signin_email');
        const signInEditEl = document.getElementById('kt_signin_email_edit');
        const passwordMainEl = document.getElementById('kt_signin_password');
        const passwordEditEl = document.getElementById('kt_signin_password_edit');

        // button elements
        const signInChangeEmail = document.getElementById('kt_signin_email_button');
        const signInCancelEmail = document.getElementById('kt_signin_cancel');
        const passwordChange = document.getElementById('kt_signin_password_button');
        const passwordCancel = document.getElementById('kt_password_cancel');

        // toggle UI
        signInChangeEmail.querySelector('button').addEventListener('click', function () {
            toggleChangeEmail();
        });

        signInCancelEmail.addEventListener('click', function () {
            toggleChangeEmail();
        });

        passwordChange.querySelector('button').addEventListener('click', function () {
            toggleChangePassword();
        });

        passwordCancel.addEventListener('click', function () {
            toggleChangePassword();
        });

        var toggleChangeEmail = function () {
            signInMainEl.classList.toggle('d-none');
            signInChangeEmail.classList.toggle('d-none');
            signInEditEl.classList.toggle('d-none');
        }

        var toggleChangePassword = function () {
            passwordMainEl.classList.toggle('d-none');
            passwordChange.classList.toggle('d-none');
            passwordEditEl.classList.toggle('d-none');
        }
    }

    var handleChangeEmail = function (e) {
        let validation;
        const signInForm = document.getElementById('kt_signin_change_email');
        validation = FormValidation.formValidation(
            signInForm,
            {
                fields: {
                    "traits.email": { validators: { notEmpty: { message: require_email_text}, emailAddress: { message: invalid_email_text}} },
                    confirmemailpassword: { validators: { notEmpty: { message: require_password_text }} }
                },

                plugins: { //Learn more: https://formvalidation.io/guide/plugins
                    trigger: new FormValidation.plugins.Trigger(),
                    bootstrap: new FormValidation.plugins.Bootstrap5({
                        rowSelector: '.fv-row'
                    })
                }
            }
        );

        signInForm.querySelector('#kt_signin_submit').addEventListener('click', function (e) {
            e.preventDefault();
            validation.validate().then(function (status) {
                if (status == 'Valid') {
                    const submit_button = $('button#kt_signin_submit');
                    submit_button.attr('data-kt-indicator', 'on');
                    submit_button.attr('disabled', 'disabled');

                    $('form#kt_signin_change_email').submit();
                } else {
                    swal.fire({
                        text: normal_error_text,
                        icon: "error",
                        buttonsStyling: false,
                        confirmButtonText: $('input#ok_got_it').val(),
                        customClass: {
                            confirmButton: "btn font-weight-bold btn-light-primary"
                        }
                    });
                }
            });
        });
    }

    var handleChangePassword = function (e) {
        let validation;
        const passwordForm = document.getElementById('kt_signin_change_password');

        validation = FormValidation.formValidation(
            passwordForm,
            {
                fields: {
                    currentpassword: { validators: { notEmpty: { message: require_current_password_text }} },
                    password: { validators: { notEmpty: { message: require_new_password_text }} },
                    confirmpassword: {
                        validators: {
                            notEmpty: { message: require_confirm_password_text },
                            identical: {
                                compare: function() {
                                    return passwordForm.querySelector('[name="newpassword"]').value;
                                },
                                message: matchnot_confirm_password_text
                            }
                        }
                    },
                },

                plugins: { //Learn more: https://formvalidation.io/guide/plugins
                    trigger: new FormValidation.plugins.Trigger(),
                    bootstrap: new FormValidation.plugins.Bootstrap5({
                        rowSelector: '.fv-row'
                    })
                }
            }
        );

        passwordForm.querySelector('#kt_password_submit').addEventListener('click', function (e) {
            e.preventDefault();

            validation.validate().then(function (status) {
                if (status == 'Valid') {
                    const submit_button = $('button#kt_password_submit');
                    submit_button.attr('data-kt-indicator', 'on');
                    submit_button.attr('disabled', 'disabled');

                    $('form#kt_signin_change_password').submit();
                } else {
                    swal.fire({
                        text: normal_error_text,
                        icon: "error",
                        buttonsStyling: false,
                        confirmButtonText: $('input#ok_got_it').val(),
                        customClass: {
                            confirmButton: "btn font-weight-bold btn-light-primary"
                        }
                    });
                }
            });
        });
    }

    // Public methods
    return {
        init: function () {
            initSettings();
            handleChangeEmail();
            handleChangePassword();
        }
    }
}();

// On document ready
KTUtil.onDOMContentLoaded(function() {
    KTAccountSettingsSigninMethods.init();
});
