$.fn.availabilityEditor = function (opts) {
  // selector of input where availability json is stored
  var availabilityInputSelector = opts.availabilityInputSelector;
  // selector input where useDefaults is stored
  var useDefaultsInputSelector = opts.useDefaultsInputSelector;
  // selector of submit button for form containing the availability editor
  var submitSelector = opts.submitSelector;
  // if provided, initial availability
  var initAvailability =
    (opts.initialState ? opts.initialState.availability : {}) || {};
  // if provided, initial value for useDefaultAvailability
  var initUseDefaults = opts.initialState
    ? !!opts.initialState.useDefaults
    : true;
  // ids of available days
  var DAY_IDS = opts.dayIds;
  // map of day id to a human-readable day name
  var DAY_NAMES = opts.dayNames;
  // i18n messages
  var messages = $.extend(
    {
      "business_hours.add": "Add",
      "business_hours.remove": "Remove",
      "services.booking_time.confirm_remove_slot":
        "Are you sure you want to remove this element?",
    },
    opts.messages
  );

  var availabilityInput = $(availabilityInputSelector);
  var useDefaultsInput = $(useDefaultsInputSelector);
  var submitBtn = $(submitSelector);
  var rootContainer = this;

  var customAvailability = initAvailability;
  var disabledAvailability = {};
  var useDefaultAvailability = initUseDefaults;

  // when the json changes, re-render the form
  availabilityInput.change(function (evt) {
    try {
      customAvailability = JSON.parse($(evt.currentTarget).val());
    } catch (e) {
      console.error(e);
    }
    renderCustomAvailability();
    var isValid = validateAvailability();
    submitBtn.attr("disabled", !isValid);
  });

  // ensure that the provided set of availabilities is valid
  function validateAvailability() {
    // if default availability is selected, always allow submit
    if (useDefaultAvailability) {
      return true;
    }

    // if custom availability is selected, validate the slots
    var numberOfDaysWithSlots = 0;
    for (var i in DAY_IDS) {
      var day = DAY_IDS[i];
      var daySlots = customAvailability[day];
      if (!daySlots) {
        continue;
      }
      numberOfDaysWithSlots++;
      for (var j in daySlots) {
        if (!validateSlot(day, j)) {
          return false;
        }
      }
    }

    // we have no availability - this is not allowed
    if (numberOfDaysWithSlots === 0) {
      return false;
    }
    // we have some slots and all are valid
    return true;
  }

  function validateSlot(day, slotIdx) {
    // the slot we're currently validating
    var slot = customAvailability[day][slotIdx];
    // int value of the `from` time for the current slot
    var slotFrom = parseInt(slot.from.replace(":", ""));
    // int value of the `to` time for the current slot
    var slotTo = parseInt(slot.to.replace(":", ""));

    // start and end time are out of order
    if (slotTo <= slotFrom) {
      return false;
    }

    // check current slot against earlier slots for the same day
    var previous = customAvailability[day].slice(0, slotIdx);
    for (var i in previous) {
      var prev = previous[i];
      var prevTo = parseInt(prev.to.replace(":", ""));
      // current slot overlaps with an earlier slot
      if (prevTo > slotFrom) {
        return false;
      }
    }

    // everything is valid!
    return true;
  }

  function disableDay(day) {
    // remove availability for the day, but keep track of the availability in case we re-enable
    // availability for the day before submitting the form
    var toDisable = customAvailability[day];
    delete customAvailability[day];
    if (toDisable) {
      disabledAvailability[day] = toDisable;
    }
    updateCustomAvailability();
  }

  function enableDay(day) {
    // restore availability for the day, if we've previously disabled it while editing.
    // if no availability was previously disabled, apply the default availability for the newly enabled day.
    var toEnable = disabledAvailability[day];
    delete disabledAvailability[day];
    if (toEnable) {
      customAvailability[day] = toEnable;
    } else {
      customAvailability[day] = [{ from: "09:00", to: "17:00" }];
    }
    updateCustomAvailability();
  }

  // add a new slot for the given day using the default value
  function addSlot(day) {
    if (customAvailability[day]) {
      customAvailability[day].push({ from: "09:00", to: "17:00" });
      updateCustomAvailability();
    }
  }

  // remove the slot at slotIndex from the given day
  function removeSlot(day, slotIndex) {
    if (customAvailability[day]) {
      if (confirm(messages["services.booking_time.confirm_remove_slot"])) {
        customAvailability[day].splice(slotIndex, 1);
        updateCustomAvailability();
      }
    }
  }

  // update the `from` value for the slot at slotIndex on the given day
  function updateSlotFrom(day, slotIndex, val) {
    if (customAvailability[day] && customAvailability[day][slotIndex]) {
      customAvailability[day][slotIndex].from = val;
      updateCustomAvailability();
    }
  }

  // update the `to` value for the slot at slotIndex on the given day
  function updateSlotTo(day, slotIndex, val) {
    if (customAvailability[day] && customAvailability[day][slotIndex]) {
      customAvailability[day][slotIndex].to = val;
      updateCustomAvailability();
    }
  }

  // render the checkbox for toggling the given day
  function renderDayCheckbox(day) {
    return $("<div/>", { class: "col-md-3 col-xs-12 pt-3" }).append(
      $("<input/>", {
        type: "checkbox",
        checked: customAvailability[day] ? "checked" : undefined,
          class: "form-check-input w-20px h-20px me-2"
      }).change(function (evt) {
        if (evt.currentTarget.checked) {
          enableDay(day);
        } else {
          disableDay(day);
        }
      })
    )
    .append($("<label/>", {
      class: "form-check-label",
      text: DAY_NAMES[day]
    }))
  }

  // render the slots for the given day
  function renderDayTimes(day, times, container) {
    for (var i = 0; i < times.length; i++) {
      var slot = times[i];
      var from = slot.from,
        to = slot.to;
      container.append(renderSlotPickers(day, i, from, to));
    }
    container.append(
      $("<div/>", { class: "row mb-3" }).append(
        $("<div/>", { class: "col-md-4" }).append(
          $("<a/>", {
            href: "javascript:;",
            class: "btn btn-bold btn-sm btn-success",
          })
            .html('<i class="la la-plus"></i>' + messages["business_hours.add"])
            .click(function () {
              addSlot(day);
            })
        )
      )
    );
  }

  // render a single time picker
  function renderSingleSlotPicker(day, slotIndex, value, onNewValue) {
    var isValid = validateSlot(day, slotIndex);
    var input_obj = document.createElement("input");
    input_obj.type = "text";
    input_obj.value = value;
    input_obj.style = isValid ? "" : "color: red;";
    $(input_obj).addClass("from_time_default form-control timepicker-default");
    $(input_obj).flatpickr({
      enableTime: true,
      noCalendar: true,
      time_24hr: true,
      dateFormat: "H:i",
      onChange: function(selectedDates, dateStr, instance) {
          onNewValue(dateStr);
      },
    })

    // $(input_obj).change(function () {
    //   onNewValue($(this).val());
    // });
    return input_obj;
  }

  // render the `to` and `from` pickers for the given time slot
  function renderSlotPickers(day, slotIndex, from, to) {
    var slotContainer = $("<div/>", { class: "row mb-3 time_slot" })
      .append(
        $("<div/>", { class: "col-4 col-md-4" }).append(
          renderSingleSlotPicker(day, slotIndex, from, function (newValue) {
            updateSlotFrom(day, slotIndex, newValue);
          })
        )
      )
      .append(
        $("<div/>", { class: "col-4 col-md-4" }).append(
          renderSingleSlotPicker(day, slotIndex, to, function (newValue) {
            updateSlotTo(day, slotIndex, newValue);
          })
        )
      );

    // delete button not available for the first slot, so only add it for the other slots
    if (slotIndex > 0) {
      slotContainer.append(
        $("<div/>", { class: "col-4 col-md-4 align-self-center" }).append(
          $("<a/>", {
            href: "javascript:;",
            class: "btn-sm btn btn-danger btn-bold",
          })
            .html(
              '<i class="las la-trash-alt"></i>' +
                messages["business_hours.remove"]
            )
            .click(function () {
              removeSlot(day, slotIndex);
            })
        )
      );
    }
    return slotContainer;
  }

  // render the availability editor (not shown when 'use default availability' is chosen)
  function renderCustomAvailability() {
    rootContainer.empty();
    for (var i in DAY_IDS) {
      var day = DAY_IDS[i];
      var dayContainer = $("<div/>", { class: "row min-height-50" }).append(
        renderDayCheckbox(day)
      );
      if (customAvailability[day]) {
        var timesContainer = $("<div/>", { class: "col-md-9 col-xs-12" });
        renderDayTimes(day, customAvailability[day], timesContainer);
        dayContainer.append(timesContainer);
      }
      rootContainer.append(dayContainer);
    }
    var classToRemove = useDefaultAvailability ? "d-block" : "d-none";
    var classToAdd = useDefaultAvailability ? "d-none" : "d-block";
    rootContainer.removeClass(classToRemove).addClass(classToAdd);
  }

  // save the new availability to the input as JSON
  function updateCustomAvailability() {
    availabilityInput.val(JSON.stringify(customAvailability));
    availabilityInput.change();
  }

  // when 'use default availability' is toggled, apply the new value and re-render
  useDefaultsInput.change(function (evt) {
    useDefaultAvailability = evt.currentTarget.value === "true";
    renderCustomAvailability();
  });

  // bootstrap the editor:
  availabilityInput.change();
  $(`${useDefaultsInputSelector}[value="${useDefaultAvailability}"]`).click();
};
