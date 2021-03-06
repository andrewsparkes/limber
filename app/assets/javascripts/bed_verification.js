(function($, exports, undefined){
  "use strict";

  ////////////////////////////////////////////////////////////////////
  // Bed Robot Page
  $(function(event) {

    if ($('#robot-verification-bed').length === 0) { return };

    //= require lib/ajax_support

    var closeIcon = function() {
      return $(document.createElement('a')).
        attr('class','close').attr('aria-label','close').append(
          $(document.createElement('span')).
            attr('aria-hidden','true').text('×')
        );
    }


    SCAPE.robot_beds = {};
    SCAPE.robot_barcode = '';

    var newScanned = function(bed,plate){
      var new_li;
      // $('#whole\\['+bed+'\\]').detach();
      new_li = $(document.createElement('li')).
        attr('data-bed',bed).
        attr('data-labware',plate).
        attr('class','list-group-item list-group-item-action').
        on('click', removeEntry).
        append(
          $(document.createElement('a')).
          attr('href','#').
          attr('class','list-group-item-action').
          append(
            $(document.createElement('h3')).
            attr('class',"ui-li-heading").
            text('Bed: '+bed)
          ).append(closeIcon()).append(
            $(document.createElement('p')).
            attr('class','ui-li-desc').
            text('Plate: '+plate)
          ).append(
            $(document.createElement('input')).
            attr('type','hidden').attr('id','bed_plates['+bed+']').attr('name','bed_plates['+bed+'][]').
            val(plate)
          )
        );
      SCAPE.robot_beds[bed] = SCAPE.robot_beds[bed] || []
      SCAPE.robot_beds[bed].push(plate);
      $('#start-robot').prop('disabled',true);
      $('#bed_list').append(new_li);
    }

    var newRobotScanned = function(robot_barcode){
      $('#robot').text('Robot: ' + robot_barcode);
      $('#robot_barcode').val(robot_barcode)
      SCAPE.robot_barcode = robot_barcode
    }

    var removeEntry = function() {
      var lw_index, bed_list;
      bed_list = SCAPE.robot_beds[$(this).attr('data-bed')];
      lw_index = bed_list.indexOf($(this).attr('data-labware'));
      bed_list.splice(lw_index,1);
      if (bed_list.length === 0) { SCAPE.robot_beds[$(this).attr('data-bed')] = undefined };
      $(this).detach();
      $('#bed_list');
    }

    var checkResponse = function(response) {
      if ($('#bed_list').children().length===0) {
        // We don't have any content
        $('#loadingModal').fadeOut(100);
      } else if (response.valid) {
        pass();
      } else {
        flagBeds(response.beds,response.message);
        fail();
      }

    }

    var flagBeds = function(beds,message) {
      var bad_beds = [];
      $.each(beds, function(bed_id) {
        if (!this) {$('#bed_list li[data-bed="'+bed_id+'"]').addClass('bad_bed list-group-item-danger'); bad_beds.push(bed_id);}
      });
      SCAPE.message('There were problems: '+message,'danger');
    }

    var wait = function() {
      $('#loadingModal').fadeIn(100);
    }

    var pass = function() {
      $('#loadingModal').fadeOut(100);
      SCAPE.message('No problems detected!','success');
      $('#start-robot').prop('disabled',false);
    }

    var fail = function() {
      $('#loadingModal').fadeOut(100);
      $('#start-robot').prop('disabled',true);
    }

    $('#plate_scan').on('change', function(){
      var plate_barcode, bed_barcode, robot_barcode;
      plate_barcode = this.value
      bed_barcode = $('#bed_scan').val();
      robot_barcode = $('#robot_scan').val();
      SCAPE.robot_scan = robot_barcode
      this.value = "";
      $('#bed_scan').val("");
      $('#bed_scan').focus();
      newScanned(bed_barcode,plate_barcode);
    });

    $('#robot_scan').on('change', function(){
      var robot_barcode;
      robot_barcode = this.value
      newRobotScanned(robot_barcode);
    });

    $('#validate_layout').on('click',function(){
      wait();
      var ajax = $.ajax({
          dataType: "json",
          url: window.location.pathname+'/verify',
          type: 'POST',
          data: {
            bed_plates: SCAPE.robot_beds,
            robot_barcode: SCAPE.robot_barcode
          },
          success: function(data,status) { checkResponse(data); }
        }).fail(function(data,status) { SCAPE.message('The beds could not be validated. There may be network issues, or problems with Sequencescape.','danger'); fail(); });
    })
  });
})(jQuery,window);
