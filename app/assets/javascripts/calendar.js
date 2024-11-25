"use strict";

// Class definition
var KTAppCalendar = function () {
    // Shared variables
    // Calendar variables
    var calendar;
    var data = {
        id: '',
        eventTitle: '',
        eventType: '',
        eventContact: '',
        eventService: '',
        eventResource: '',
        eventDescription: '',
        startDate: '',
        endDate: '',
        startTime: '',
        endTime: '',
        customer_id: 0,
        service_id: 0,
        resource_id: 0,
        reminders: []
    };
    var popover;
    var popoverState = false;

    // Add event variables
    var eventTitle;
    var eventContact;
    var eventService;
    var eventResource;
    var eventDescription;
    var startDatepicker;
    var startFlatpickr;
    var endDatepicker;
    var endFlatpickr;
    var startTimepicker;
    var startTimeFlatpickr;
    var endTimepicker;
    var endTimeFlatpickr;

    var modal;
    var modalTitle;
    var form;
    var validator;
    var addButton;
    var submitButton;
    var cancelButton;
    var closeButton;

    // View event variables
    var viewEventName;
    var viewEventDescription;
    var viewStartDate;
    var viewEndDate;
    var viewModal;
    var viewDeleteButton;
    var viewEditButton;
    var viewBookingWidgetButton;

    // setting variables
    let settingSubmitButton;
    let businessHoursSubmitButton;
    let selectedDateStr = null;
    let selectedEventStartTime = null;
    let selectedEventEndTime = null;

    // Private functions
    var initCalendarApp = function () {
        // Define variables
        var calendarEl = document.getElementById('kt_calendar_app');
        var todayDate = moment().startOf('day');
        var YM = todayDate.format('YYYY-MM');
        var YESTERDAY = todayDate.clone().subtract(1, 'day').format('YYYY-MM-DD');
        var TODAY = todayDate.format('YYYY-MM-DD');
        var TOMORROW = todayDate.clone().add(1, 'day').format('YYYY-MM-DD');
        var locale = $('input#user_locale').val();

        let hour12 = $('select.time_format').val() == 12 ? true : false;
        let hiddenDays = [];
        if ($('input#weekend_sunday').prop('checked')) hiddenDays.push(0);
        if ($('input#weekend_saturday').prop('checked')) hiddenDays.push(6);

        // Init calendar --- more info: https://fullcalendar.io/docs/initialize-globals
        calendar = new FullCalendar.Calendar(calendarEl, {
            headerToolbar: {
                left: 'prev,next today',
                center: 'title',
                right: 'dayGridMonth,timeGridWeek,timeGridDay,listMonth'
            },
            initialDate: TODAY,
            navLinks: true, // can click day/week names to navigate views
            selectable: true,
            selectMirror: true,
            locale: locale,
            lazyFetching: true,
            slotDuration: $('select.slotDuration').val(),
            snapDuration: $('select.snapDuration').val(),
            slotMinTime: $('input.slotMinTime').val(),
            slotMaxTime: $('input.slotMaxTime').val(),
            hiddenDays: hiddenDays,
            firstDay: $('select.firstDay').val(),
            slotLabelFormat: {
                hour: 'numeric',
                minute: '2-digit',
                omitZeroMinute: false,
                meridiem: 'narrow',
                hour12: hour12
            },
            eventTimeFormat: {
                hour: 'numeric',
                minute: '2-digit',
                omitZeroMinute: false,
                meridiem: 'narrow',
                hour12: hour12
            },

            // Select dates action --- more info: https://fullcalendar.io/docs/select-callback
            select: function (arg) {
                hidePopovers();
                arg.endStr = arg.startStr
                formatArgs(arg);

                selectedDateStr = null;
                selectedEventStartTime = null;
                selectedEventEndTime = null;

                $('input[name=service_duration]').val($('input[name=slot_duration]').val());
                $('input[name=service_buffer]').val(0);
                $('select#kt_calendar_event_contact').select2().val(null).trigger('change');
                $('select#kt_calendar_event_service').select2().val(null).trigger('change');
                $('select#kt_calendar_event_resource').select2().val(null).trigger('change');

                setDisableTimeOption(arg.startStr);
                $('input#event_id').val('');
                handleNewEvent();
            },

            // Click event --- more info: https://fullcalendar.io/docs/eventClick
            eventClick: function (arg) {
                hidePopovers();
                let description = '';
                let customer = '';
                let service_name = '';
                let resource_name = '';
                let customer_id = 0;
                let service_id = 0;
                let resource_id = 0;
                let reminders = [];

                $.ajax ({
                    url: '/schedule_event/get_event_detail_info',
                    type: 'POST',
                    async: false,
                    data: {
                        event_id: arg.event.id,
                        description: arg.event.extendedProps.description,
                    },
                    success: function (response) {
                        description = response.description;
                        customer = response.customer;
                        service_name = response.service_name;
                        resource_name = response.resource_name;
                        customer_id = response.customer_id;
                        service_id = response.service_id;
                        resource_id = response.resource_id;
                        reminders = response.reminders;
                        $('input[name=service_duration]').val(response.service_duration);
                        $('input[name=service_buffer]').val(response.service_buffer);
                    }
                });

                const start = arg.event.start;
                const end = arg.event.end;
                const eventStartStr = start.getFullYear() + '-' + ('0' + (start.getMonth() + 1)).slice(-2) + '-' + ('0' + (start.getDate())).slice(-2);
                const eventStartTime = ('0' + (start.getHours())).slice(-2) + ':' +('0' + (start.getMinutes())).slice(-2);
                const eventEndTime = ('0' + (end.getHours())).slice(-2) + ':' +('0' + (end.getMinutes())).slice(-2);

                selectedDateStr = eventStartStr;
                selectedEventStartTime = eventStartTime;
                selectedEventEndTime = eventEndTime;
                setDisableTimeOption(eventStartStr, selectedEventStartTime, selectedEventEndTime);

                formatArgs({
                    id: arg.event.id,
                    title: arg.event.title,
                    event_type: arg.event.extendedProps.event_type,
                    description: description,
                    contact: customer,
                    service: service_name,
                    resource: resource_name,
                    startStr: arg.event.startStr,
                    endStr: arg.event.endStr,
                    customer_id: customer_id,
                    service_id: service_id,
                    resource_id: resource_id,
                    reminders: reminders
                });
                handleViewEvent();
            },
            dateClick: function(info) {
                // change the day's background color just for fun
                // info.dayEl.style.backgroundColor = 'red';
                // getEventsOfSelectedDate(info.dateStr);
            },
            eventMouseEnter: function (arg) {
                formatArgs({
                    id: arg.event.id,
                    title: arg.event.title,
                    description: arg.event.extendedProps.description,
                    contact: arg.event.extendedProps.contact,
                    service: arg.event.extendedProps.service || '',
                    resource: arg.event.extendedProps.resource || '',
                    startStr: arg.event.startStr,
                    endStr: arg.event.endStr,
                    customer_id: 0,
                    service_id: 0,
                    resource_id: 0,
                    reminders: []
                });

            },
            eventDrop: function (info) {
                Swal.fire({
                    text: $('input[name=event_reorder]').val(),
                    icon: 'warning',
                    showCancelButton: true,
                    buttonsStyling: false,
                    confirmButtonText: $('input[name=yes_reorder]').val(),
                    cancelButtonText: $('input[name=no_cancel]').val(),
                    customClass: {
                        confirmButton: 'btn btn-primary',
                        cancelButton: 'btn btn-active-light'
                    }
                }).then(function (result) {
                    if (!result.isConfirmed) {
                        info.revert();
                    }
                });
            },
            editable: true,
            dayMaxEvents: true, // allow "more" link when too many events
            events: function(info, successCallback, failureCallback) {
                $('input#from_date').val(info.startStr.substr(0, 10));
                $('input#to_date').val(info.endStr.substr(0, 10));
                $('div.loader-body').show();
                $.ajax ({
                    url: '/schedule_event/get_events',
                    type: 'POST',
                    data: {
                        from: info.startStr,
                        to: info.endStr,
                    },
                    success: function (response) {
                        $('div.loader-body').hide();
                        let events = [];
                        $.each(response.events, function(index, user_event) {
                            let event = {
                                id: user_event.event_id,
                                title: user_event.summary,
                                event_type: user_event.event_uid.includes("evt_external") ? 'external' : 'voxiplan',
                                start: new Date(new Date(user_event.start.time).toLocaleString('en-US', { timeZone: response.timezone })),
                                end: new Date(new Date(user_event.end.time).toLocaleString('en-US', { timeZone: response.timezone })),
                                description: user_event.description,
                                className: "fc-event-light fc-event-solid-primary",
                            }
                            events.push(event);
                        });

                        successCallback(events);
                    },
                    error: function (xhr, err) {
                        $('div.loader-body').hide();
                        console.log ("readyState: " + xhr.readyState + "\nstatus: " + xhr.status);
                        console.log ("responseText: " + xhr.responseText);
                    }
                });
            }
        });

        calendar.render();
    }

    // Initialize popovers --- more info: https://getbootstrap.com/docs/4.0/components/popovers/
    const initPopovers = (element) => {
        hidePopovers();
        
        // Generate popover content
        const startDate = data.allDay ? moment(data.startDate).format('Do MMM, YYYY') : moment(data.startDate).format('Do MMM, YYYY - h:mm a');
        const endDate = data.allDay ? moment(data.endDate).format('Do MMM, YYYY') : moment(data.endDate).format('Do MMM, YYYY - h:mm a');
        const popoverHtml = `
          <div class="fw-bolder mb-2">${data.eventName}</div>
          <div class="fs-7">
            <span class="fw-bold">Start:</span>
            ${startDate}
          </div>
          <div class="fs-7">
            <span class="fw-bold">End:</span>
            ${endDate}
          </div>
          <div class="mt-4">
            <div id="kt_calendar_event_quick_reschedule_button" class="btn btn-sm btn-light-primary d-block">Quick Reschedule</div>
          </div>
          <div class="mt-2">
            <div id="kt_calendar_event_reschedule_button" class="btn btn-sm btn-light-primary d-block">Reschedule</div>
          </div>
          <div class="mt-2">
            <div id="kt_calendar_event_cancel_button" class="btn btn-sm btn-light-danger d-block">Cancel</div>
          </div>
        `;
        // Popover options
        var options = {
            container: 'body',
            trigger: 'manual',
            boundary: 'window',
            placement: 'auto',
            dismiss: true,
            html: true,
            title: '',
            content: popoverHtml,
        }

        // Initialize popover
        popover = KTApp.initBootstrapPopover(element, options);

        // Show popover
        popover.show();

        // Update popover state
        popoverState = true;

        // Open view event modal
        // handleViewButton();
        handleTooltipCancelButton();
        handleTooltipQuickRescheduleButton();
        handleTooltipRescheduleButton();
    }

    // Hide active popovers
    const hidePopovers = () => {
        if (popoverState) {
            popover.dispose();
            popoverState = false;
        }
    }

    // Initialize datepickers --- more info: https://flatpickr.js.org/
    const initDatepickers = () => {
        startFlatpickr = flatpickr(startDatepicker, {
            enableTime: false,
            dateFormat: "Y-m-d",
            time_24hr: true,
            onChange: function(selectedDates, dateStr, instance) {
                $('input#kt_calendar_datepicker_end_date').val(dateStr);
                setDisableTimeOption(dateStr, selectedEventStartTime, selectedEventEndTime);
            }
        });

        endFlatpickr = flatpickr(endDatepicker, {
            enableTime: false,
            dateFormat: "Y-m-d",
            time_24hr: true,
        });

    }

    const initTimepickers = () => {
        startTimeFlatpickr = flatpickr(startTimepicker, {
            enableTime: true,
            noCalendar: true,
            dateFormat: "H:i",
        });

        endTimeFlatpickr = flatpickr(endTimepicker, {
            enableTime: true,
            noCalendar: true,
            dateFormat: "H:i",
        });
    }

    // Initialize add/edit modal
    const initAddEditModal = () => {
        // Init form validation rules. For more info check the FormValidation plugin's official documentation:https://formvalidation.io/
        validator = FormValidation.formValidation(
            form,
            {
                fields: {
                    'calendar_event_name': {
                        validators: { notEmpty: { message: $('input[name=event_name_required]').val() } }
                    },
                    'calendar_event_start_date': {
                        validators: { notEmpty: { message: $('input[name=event_start_date_required]').val() } }
                    },
                    'calendar_event_start_time': {
                        validators: { notEmpty: { message: $('input[name=event_start_time_required]').val() } }
                    },
                    'calendar_event_end_date': {
                        validators: { notEmpty: { message: $('input[name=event_end_date_required]').val() } }
                    },
                    'calendar_event_end_time': {
                        validators: { notEmpty: { message: $('input[name=event_end_time_required]').val() } }
                    },
                },

                plugins: {
                    trigger: new FormValidation.plugins.Trigger(),
                    bootstrap: new FormValidation.plugins.Bootstrap5({
                        rowSelector: '.fv-row',
                        eleInvalidClass: '',
                        eleValidClass: ''
                    })
                }
            }
        );

        // Handle submit form
        submitButton.addEventListener('click', function (e) {
            // Prevent default button action
            e.preventDefault();

            // Validate form before submit
            if (validator) {
                validator.validate().then(function (status) {
                    if (status == 'Valid') {
                        submitButton.setAttribute('data-kt-indicator', 'on');
                        submitButton.disabled = true;

                        $('form#kt_modal_add_event_form').ajaxSubmit({
                            success: function(response) {
                                Swal.fire({
                                    text: response.message,
                                    icon: response.result,
                                    buttonsStyling: false,
                                    confirmButtonText: $('input[name=ok_got_it]').val(),
                                    customClass: {
                                        confirmButton: "btn btn-primary"
                                    }
                                }).then(function (result) {
                                    if (result.isConfirmed) {
                                        window.location.reload();
                                    }
                                });

                            }
                        })

                    } else {
                        // Show popup warning
                        Swal.fire({
                            text: $('input[name=submit_failure]').val(),
                            icon: "error",
                            buttonsStyling: false,
                            confirmButtonText: $('input[name=ok_got_it]').val(),
                            customClass: {
                                confirmButton: "btn btn-primary"
                            }
                        });
                    }
                });
            }
        });
    }

    // Handle add button
    const handleAddButton = () => {
        addButton.addEventListener('click', e => {
            // Reset form data
            data = {
                id: '',
                eventTitle: '',
                eventType: '',
                eventContact: '',
                eventService: '',
                eventResource: '',
                eventDescription: '',
                startDate: '',
                endDate: '',
                startTime: '',
                endTime: '',
                customer_id: 0,
                service_id: 0,
                resource_id: 0,
                reminders: []
            };

            selectedDateStr = null;
            selectedEventStartTime = null;
            selectedEventEndTime = null;

            const dt = new Date();
            const current_date_str = dt.getFullYear() + '-' + ('0' + (dt.getMonth() + 1)).slice(-2) + '-' + ('0' + (dt.getDate())).slice(-2);
            data.startDate = current_date_str
            data.endDate = current_date_str

            $('input[name=service_duration]').val($('input[name=slot_duration]').val());
            $('input[name=service_buffer]').val(0);
            $('input#kt_calendar_datepicker_start_date').val('00:00');
            $('input#kt_calendar_datepicker_end_date').val('00:30');
            $('select#kt_calendar_event_contact').select2().val(null).trigger('change');
            $('select#kt_calendar_event_service').select2().val(null).trigger('change');
            $('select#kt_calendar_event_resource').select2().val(null).trigger('change');

            handleNewEvent();
            $('input#event_id').val('');
        });
    }

    // Handle add new event
    const handleNewEvent = () => {
        // Update modal title
        validator.resetForm();

        modalTitle.innerText = $('input[name=new_event]').val();
        modal.show();

        populateForm(data);

    }

    // Handle edit event
    const handleEditEvent = () => {
        // Update modal title
        form.reset();
        modalTitle.innerText = $('input[name=edit_event]').val();
        modal.show();

        populateForm(data);
    }

    const handleViewEvent = () => {
        viewModal.show();

        // Detect all day event
        var startDateMod;
        var endDateMod;
        var startTimeMod;
        var endTimeMod;

        // Generate labels
        startDateMod = moment(data.startDate).format('MMM D, YYYY');
        endDateMod = moment(data.endDate).format('MMM D, YYYY');
        startTimeMod = moment(data.startTime).format('HH:mm');
        endTimeMod = moment(data.endTime).format('HH:mm');

        const data_description = data.eventDescription.split("\n");
        let html_description = "";

        data_description.forEach((item, index) => {
            if (index) {
                const item_content = item.split(':');
                if (item_content.length > 1)
                    html_description += "<div class='row description_item'><div class='col-3'>" + item_content[0] + "</div><div class='col-6'>" + item_content[1] + "</div></div>";
            }
        });

        // Populate view data
        $('h3[data-kt-calendar="title"]').html(data.eventTitle);
        $('div[data-kt-calendar="event_description"]').html(html_description ? html_description : '--');
        $('span[data-kt-calendar="event_start_date"]').html(startDateMod);
        $('span[data-kt-calendar="event_start_time"]').html(startTimeMod);
        $('span[data-kt-calendar="event_end_date"]').html(endDateMod);
        $('span[data-kt-calendar="event_end_time"]').html(endTimeMod);
        $('div[data-kt-calendar="event_contact"]').html(data.eventContact);
        $('div[data-kt-calendar="event_service"]').html(data.eventService);
        $('div[data-kt-calendar="event_resource"]').html(data.eventResource);
        $('input#event_id').val(data.id);

        if (data.eventType == 'external') {
            $(viewEditButton).hide();
            $(viewDeleteButton).hide();
            $(viewBookingWidgetButton).hide();
            $('div#event_change_condition').addClass('d-flex').removeClass('d-none');
        }
        else {
            $(viewEditButton).show();
            $(viewDeleteButton).show();
            $(viewBookingWidgetButton).show();
            $('div#event_change_condition').removeClass('d-flex').addClass('d-none');
        }

    }

    // Handle delete event
    const handleDeleteEvent = () => {
        viewDeleteButton.addEventListener('click', e => {
            e.preventDefault();

            Swal.fire({
                text: $('input[name=delete_event_confirm]').val(),
                icon: "warning",
                showCancelButton: true,
                buttonsStyling: false,
                confirmButtonText: $('input[name=yes_delete]').val(),
                cancelButtonText: $('input[name=no_cancel]').val(),
                customClass: {
                    confirmButton: "btn btn-primary",
                    cancelButton: "btn btn-active-light"
                }
            }).then(function (result) {
                if (result.value) {
                    $('div.loader-body').show();
                    console.log($('input#event_id').val());
                    $.ajax ({
                        url: '/schedule_event/delete_event',
                        type: 'POST',
                        data: {
                            from: $('input#from_date').val(),
                            to: $('input#to_date').val(),
                            event_id: $('input#event_id').val()
                        },
                        success: function (response) {
                            $('div.loader-body').hide();
                            $('input#event_id').val('');
                            Swal.fire({
                                text: response.message,
                                icon: response.result,
                                buttonsStyling: false,
                                confirmButtonText: $('input[name=ok_got_it]').val(),
                                customClass: {
                                    confirmButton: "btn btn-primary"
                                }
                            }).then(function (result) {
                                if (result.isConfirmed) {
                                    calendar.getEventById(data.id).remove();
                                    viewModal.hide(); // Hide modal
                                }
                            });

                        }
                    });
                } else if (result.dismiss === 'cancel') {
                    // Swal.fire({
                    //     text: "Your event was not deleted!.",
                    //     icon: "error",
                    //     buttonsStyling: false,
                    //     confirmButtonText: $('input[name=ok_got_it]').val(),
                    //     customClass: {
                    //         confirmButton: "btn btn-primary",
                    //     }
                    // });
                }
            });
        });
    }

    // Handle cancel button
    const handleCancelButton = () => {
        // Edit event modal cancel button
        cancelButton.addEventListener('click', function (e) {
            e.preventDefault();
            form.reset(); // Reset form
            modal.hide(); // Hide modal
        });
    }

    // Handle close button
    const handleCloseButton = () => {
        // Edit event modal close button
        closeButton.addEventListener('click', function (e) {
            e.preventDefault();
            form.reset(); // Reset form
            modal.hide(); // Hide modal
        });
    }

    const handleSaveSettingButton = () => {
        // Edit event modal cancel button
        settingSubmitButton.addEventListener('click', function (e) {
            e.preventDefault();

            settingSubmitButton.setAttribute('data-kt-indicator', 'on');
            settingSubmitButton.disabled = true;
            $('form#kt_modal_form_settings').ajaxSubmit({
                success: function(response) {
                    if (response.result == 'success') {
                        settingSubmitButton.removeAttribute('data-kt-indicator');
                        settingSubmitButton.disabled = false;

                        $('input[name=service_duration]').val($('select.slotDuration').val().split(":")[1]);
                        $('input[name=slot_duration]').val($('select.slotDuration').val().split(":")[1]);

                        calendar.setOption('slotDuration', $('select.slotDuration').val());
                        calendar.setOption('snapDuration', $('select.snapDuration').val());

                        if ($('input.slotMinTime').val() != '') calendar.setOption('slotMinTime', $('input.slotMinTime').val());
                        if ($('input.slotMaxTime').val() != '') calendar.setOption('slotMaxTime', $('input.slotMaxTime').val());

                        let hiddenDays = [];
                        if ($('input#weekend_sunday').prop('checked')) hiddenDays.push(0);
                        if ($('input#weekend_saturday').prop('checked')) hiddenDays.push(6);
                        calendar.setOption('hiddenDays', hiddenDays);
                        calendar.setOption('firstDay', $('select.firstDay').val());

                        const isHour12 = $('select.time_format').val() == 12 ? true : false;
                        calendar.setOption('slotLabelFormat', {
                            hour: 'numeric',
                            minute: '2-digit',
                            omitZeroMinute: false,
                            meridiem: 'narrow',
                            hour12: isHour12
                        });
                        calendar.setOption('eventTimeFormat', {
                            hour: 'numeric',
                            minute: '2-digit',
                            omitZeroMinute: false,
                            meridiem: 'narrow',
                            hour12: isHour12
                        });

                        $("#kt_settings_min_time").flatpickr({
                            enableTime: true,
                            noCalendar: true,
                            dateFormat: "H:i",
                            time_24hr: isHour12 ? false : true
                        });

                        $("#kt_settings_max_time").flatpickr({
                            enableTime: true,
                            noCalendar: true,
                            dateFormat: "H:i",
                            time_24hr: isHour12 ? false : true
                        });

                        $.ajax({
                            type: "POST",
                            data: { ishour12: isHour12 },
                            url: "/schedule_event/get_time_list",
                            success: function (response) {
                                let times = [''];
                                response.times.forEach((time) => {
                                    let element = [];
                                    element['id'] = time['value'];
                                    element['text'] = time['label'];
                                    times.push(element);
                                })
                                $('select#calendar_event_start_time').html('');
                                $('select#calendar_event_start_time').select2({ data: times});
                                $('select#calendar_event_end_time').html('');
                                $('select#calendar_event_end_time').select2({ data: times});
                                $("select#calendar_event_start_time, select#calendar_event_end_time").select2({
                                    tags: true,
                                    dropdownParent: $('#kt_modal_add_event'),
                                    placeholder: "Pick a time",
                                    allowClear: true
                                }).on('select2:open', function(e){
                                    $('.select2-search__field').attr('placeholder', 'Type your custom time').attr('type', 'time');
                                });
                            }
                        })
                        $('div#kt_modal_settings').modal('hide');
                    }
                    showMessage(response.result, response.message);
                }
            })


        });
    }

    const handleSaveBusinessHoursButton = () => {
        // Edit event modal cancel button
        businessHoursSubmitButton.addEventListener('click', function (e) {
            e.preventDefault();

            businessHoursSubmitButton.setAttribute('data-kt-indicator', 'on');
            businessHoursSubmitButton.disabled = true;
            $('form#kt_modal_form_business_hours').ajaxSubmit({
                success: function(response) {
                    if (response.result == 'success') {
                        businessHoursSubmitButton.removeAttribute('data-kt-indicator');
                        businessHoursSubmitButton.disabled = false;

                        let from_hours_array = [];
                        $.each($('input.from_time_default'), function (index, from_obj) {
                            if (!$(from_obj).parent().hasClass('d-none')) {
                                let from_hours = {};
                                from_hours[$(from_obj).attr('id')] = $(from_obj).val();
                                from_hours_array.push(from_hours);
                            }
                        })

                        let to_hours_array = [];
                        $.each($('input.to_time_default'), function (index, to_obj) {
                            if (!$(to_obj).parent().hasClass('d-none')) {
                                let to_hours = {};
                                to_hours[$(to_obj).attr('id')] = $(to_obj).val();
                                to_hours_array.push(to_hours);
                            }
                        })

                        let working_hours = [];
                        working_hours[1] = getWorkingHours('mon', from_hours_array, to_hours_array);
                        working_hours[2] = getWorkingHours('tue', from_hours_array, to_hours_array);
                        working_hours[3] = getWorkingHours('wed', from_hours_array, to_hours_array);
                        working_hours[4] = getWorkingHours('thu', from_hours_array, to_hours_array);
                        working_hours[5] = getWorkingHours('fri', from_hours_array, to_hours_array);
                        working_hours[6] = getWorkingHours('sat', from_hours_array, to_hours_array);
                        working_hours[0] = getWorkingHours('sun', from_hours_array, to_hours_array);

                        let business_hours = [];
                        for (let i = 0; i <= 6 ; i ++) {
                            for (let k = 0; k < working_hours[i].length; k ++) {
                                const availability = {
                                    daysOfWeek: [i],
                                    startTime: working_hours[i][k]['from'],
                                    endTime: working_hours[i][k]['to']
                                }
                                business_hours.push(availability);
                            }
                        }

                        calendar.setOption('businessHours', business_hours);

                        $('div#kt_modal_business_hours').modal('hide');
                    }
                    showMessage(response.result, response.message);
                }
            })


        });

        function getWorkingHours(short_day, from_hours_array, to_hours_array) {
            let working_hours = [];
            for (let i = 0; i < from_hours_array.length; i ++) {
                const from_hours = from_hours_array[i];
                const to_hours = to_hours_array[i];
                $.each(from_hours, function(key, value) {
                    if (key == short_day) {
                        working_hours.push({ 'from': value, 'to': to_hours[key] });
                    }
                })

            }
            return working_hours;
        }
    }

    const handleEditButton = () => {
        viewEditButton.addEventListener('click', e => {
            e.preventDefault();

            hidePopovers();
            handleEditEvent();
        });
    }

    const handleBookingWidget = () => {
        viewBookingWidgetButton.addEventListener('click', e => {
            e.preventDefault();

            hidePopovers();
            handleWebBookingPage();
        });
    }

    const handleWebBookingPage = () => {
        const url = $('input#webbooking_url').val() + '&event_id=' + data.id;
        window.open(url, '_blank');
    }
    // Populate form 
    const populateForm = () => {
        eventTitle.value = data.eventTitle ? data.eventTitle : '';
        eventDescription.value = data.eventDescription ? data.eventDescription : '';
        if (data.startDate) startFlatpickr.setDate(data.startDate, true, 'Y-m-d');
        if (data.startTime) $('select[name=calendar_event_start_time]').select2().val(moment(data.startTime).format('HH:mm')).trigger('change');

        if (data.endDate) endFlatpickr.setDate(data.endDate, true, 'Y-m-d');
        if (data.endTime) $('select[name=calendar_event_end_time]').select2().val(moment(data.endTime).format('HH:mm')).trigger('change');

        if (data.customer_id > 0) $('select#kt_calendar_event_contact').select2().val(data.customer_id).trigger('change');
        if (data.service_id > 0) {
            $('select#kt_calendar_event_service').select2().val(data.service_id).trigger('change');
            $('div.notification-section').addClass('d-none');
        }
        if (data.resource_id > 0) $('select#kt_calendar_event_resource').select2().val(data.resource_id).trigger('change');

        $('div#trigger-clone-box').html('');
        $.each(data.reminders, function(index, reminder) {
            cloneTrigger(reminder.offset_time, reminder.offset_duration);
        })
        if (data.reminders.length == 0) cloneTrigger('', 'minutes');
    }

    // Format FullCalendar reponses
    const formatArgs = (res) => {
        data.id = res.id;
        data.eventTitle = res.title;
        data.eventType = res.event_type;
        data.startDate = res.startStr;
        data.endDate = res.endStr;
        data.startTime = res.startStr;
        data.endTime = res.endStr;
        data.eventContact = res.contact;
        data.eventService = res.service;
        data.eventResource = res.resource;
        data.eventDescription = res.description;
        data.customer_id = res.customer_id == undefined ? 0 : res.customer_id;
        data.service_id = res.service_id == undefined ? 0 : res.service_id;
        data.resource_id = res.resource_id == undefined ? 0 : res.resource_id;
        data.reminders = res.reminders == undefined ? [] : res.reminders;
    }

    // Generate unique IDs for events
    const uid = () => {
        return Date.now().toString() + Math.floor(Math.random() * 1000).toString();
    }

    const getEventsOfSelectedDate = (selected_date_str) => {
        const all_events = calendar.getEvents();
        let booked_times = [];
        $.each(all_events, function(index, event) {
            const start = event.start;
            const end = event.end;
            const startStr = start.getFullYear() + '-' + ('0' + (start.getMonth() + 1)).slice(-2) + '-' + ('0' + (start.getDate())).slice(-2);
            const startTime = ('0' + (start.getHours())).slice(-2) + ':' +('0' + (start.getMinutes())).slice(-2);
            const endTime = ('0' + (end.getHours())).slice(-2) + ':' +('0' + (end.getMinutes())).slice(-2);
            if (startStr == selected_date_str) booked_times.push({start_time: startTime, end_time: endTime});
        });

        return booked_times;
    }

    const setDisableTimeOption = (startDateStr, eventStartTime = null, eventEndTime = null) => {
        const booked_times = getEventsOfSelectedDate(startDateStr);

        // disable already booked times in start time dropdown list except selected event time
        $('select#calendar_event_start_time option').removeAttr('disabled');
        $.each($('select#calendar_event_start_time option'), function(index, option) {
            const time = $(option).val();
            $.each(booked_times, function(index, booked_time) {
                if (eventStartTime == null || eventEndTime == null) {
                    if (time >= booked_time.start_time && time < booked_time.end_time) {
                        $(option).attr('disabled', 'disabled');
                        return false;
                    }
                }
                else {
                    if (booked_time.start_time != eventStartTime && booked_time.end_time != eventEndTime && time >= booked_time.start_time && time < booked_time.end_time) {
                        $(option).attr('disabled', 'disabled');
                        return false;
                    }
                }

            })
        });

        // disable already booked times in end time dropdown list except selected event time
        $('select#calendar_event_end_time option').removeAttr('disabled');
        $.each($('select#calendar_event_end_time option'), function(index, option) {
            const time = $(option).val();
            $.each(booked_times, function(index, booked_time) {
                if (selectedDateStr == null) {
                    if (time >= booked_time.start_time && time < booked_time.end_time) {
                        $(option).attr('disabled', 'disabled');
                        return false;
                    }
                }
                else {
                    if (booked_time.start_time != eventStartTime && booked_time.end_time != eventEndTime && time >= booked_time.start_time && time < booked_time.end_time) {
                        $(option).attr('disabled', 'disabled');
                        return false;
                    }
                }

            })
        });
    }

    setInterval(function() {
        $.ajax ({
            url: '/notification/get_notification',
            type: 'POST',
            data: {
                client_id: $('input#client_id').val()
            },
            success: function (response) {
                if (response.has_new == 'yes') {
                    const event_sources = calendar.getEventSources();
                    $.each(event_sources, function(index, event_source) {
                        event_source.refetch();
                    });
                }

            }
        });
    }, 4000);

    return {
        // Public Functions
        init: function () {
            // Define variables
            // Add event modal
            const element = document.getElementById('kt_modal_add_event');
            form = element.querySelector('#kt_modal_add_event_form');
            eventTitle = form.querySelector('#kt_calendar_event_title');
            startDatepicker = form.querySelector('#kt_calendar_datepicker_start_date');
            endDatepicker = form.querySelector('#kt_calendar_datepicker_end_date');
            startTimepicker = form.querySelector('#kt_calendar_timepicker_start_time');
            endTimepicker = form.querySelector('#kt_calendar_timepicker_end_time');
            eventContact = form.querySelector('#kt_calendar_event_contact');
            eventService = form.querySelector('#kt_calendar_event_service');
            eventResource = form.querySelector('#kt_calendar_event_resource');
            eventDescription = form.querySelector('#kt_calendar_event_description');

            addButton = document.querySelector('[data-kt-calendar="add"]');
            submitButton = form.querySelector('#kt_modal_add_event_submit');
            cancelButton = form.querySelector('#kt_modal_add_event_cancel');
            closeButton = element.querySelector('#kt_modal_add_event_close');
            modalTitle = form.querySelector('[data-kt-calendar="title"]');
            modal = new bootstrap.Modal(element);

            // View event modal
            const viewElement = document.getElementById('kt_modal_view_event');
            viewModal = new bootstrap.Modal(viewElement);
            viewEventName = viewElement.querySelector('[data-kt-calendar="event_name"]');
            viewEventDescription = viewElement.querySelector('[data-kt-calendar="event_description"]');
            viewStartDate = viewElement.querySelector('[data-kt-calendar="event_start_date"]');
            viewEndDate = viewElement.querySelector('[data-kt-calendar="event_end_date"]');
            viewEditButton = viewElement.querySelector('#kt_modal_view_event_edit');
            viewDeleteButton = viewElement.querySelector('#kt_modal_view_event_delete');
            viewBookingWidgetButton = viewElement.querySelector('#kt_calendar_event_reschedule_button');

            const settingElement = document.getElementById('kt_modal_settings');
            const settingForm = settingElement.querySelector('#kt_modal_form_settings');
            settingSubmitButton = settingForm.querySelector('#save_setting');

            const availabilityElement = document.getElementById('kt_modal_business_hours');
            const availabilityForm = availabilityElement.querySelector('#kt_modal_form_business_hours');
            businessHoursSubmitButton = availabilityForm.querySelector('#save_default_hours');

            initCalendarApp();
            initDatepickers();
            initAddEditModal();
            // initTimepickers();
            handleAddButton();
            handleCancelButton();
            handleCloseButton();
            handleEditButton();
            handleDeleteEvent();
            handleBookingWidget();

            handleSaveSettingButton();
            handleSaveBusinessHoursButton();
        }
    };
}();

// On document ready
KTUtil.onDOMContentLoaded(function () {
    KTAppCalendar.init();
});
