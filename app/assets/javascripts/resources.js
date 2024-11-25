$(document).on('ajax:success', 'a.toggle-service', function (status, data, xhr) {
    alert('asd');
    var elem = $("a#toggle-service-" + data.id);
    if(elem.text() == "Turn on") {
        elem.text('Turn off');
    } else {
        elem.text('Turn on');
    }
    elem.toggleClass('btn-primary');
    elem.toggleClass('btn-label-primary');
});
