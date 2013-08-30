function allowDrop(ev) {
  ev.preventDefault();
}

function showAdd(ev) {
  ev.preventDefault();
  $(ev.target).parent().children(".add").slideDown();
}

function hideAdd(ev) {
  ev.preventDefault();
  $(ev.target).parent().children(".add").slideUp();
}

function drag(ev) {
  ev.dataTransfer.setData("tsm_id", ev.target.id);
  $(ev.target).parent().children(".delete").slideDown();
}

function hideAll(ev) {
  ev.preventDefault();
  $(".add").slideUp();
  $(".delete").slideUp();
}

function deleteMember(ev) {
  ev.preventDefault();
  var tsm_id = ev.dataTransfer.getData("tsm_id");
  $.ajax({
    url: "/tabling_slot_members/" + tsm_id,
    type: "DELETE",
  }).done(function(data) {
    $(ev.target).parent().children("#"+tsm_id).remove();
    $(ev.target).parent().children(".delete").slideUp();
  });
}

function addMember(ev) {
  ev.preventDefault();
  var tsm_id = ev.dataTransfer.getData("tsm_id");
  var tabling_slot_id = $(ev.target).parent().parent().attr("id");
  $.ajax({
    url: "tabling_slot_members/" + tsm_id,
    type: "PUT",
    data: { "tabling_slot_id": tabling_slot_id },
  }).done(function(data) {
    $(ev.target).parent().append($("#"+tsm_id));
    $(".add").slideUp();
    $(".delete").slideUp();
  });
}


