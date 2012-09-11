'use strict'
var DOCUMENTER = {};
$(function() {
	// show the toolbar
	$('#toolbar').css('display', 'block');
	$('#collapseall').button({});
	$('#expandall').button({});
	$('#upbutton')
		.button({icons: {primary: "ui-icon-home"}})
		.click(function() {
			var loc = window.location.href;
			loc = loc.split("/");
			loc.pop();
			loc = loc.join('/');
			if (loc != '') {
				window.location.href = loc;
			}			
		});
	
	$('#print')
	  .button({icons: {primary: "ui-icon-print"}})
	  .click(function() {
		window.print();
	  });
	
	$('#index').hide();

	$('#indexbutton')
	  .button({ icons: {primary: 'ui-icon-document'}})
	  .click(function() {
	  	$('#index').toggle(100);
	  });

	$('#collapseexpand').buttonset();
	$('#collapseall').click(function() {
		$('#content .code pre').addClass('collapse')
		.filter(function() {
			return $(this).height() > min_collapse_height;
		}).addClass('collapsed');
	});
	$('#expandall').click(function() {
		$('#content .code pre')
			.removeClass('collapse')
			.removeClass('collapsed');
	});

	var min_collapse_height = 70;
	$('#content .code pre').click(function() {
		if($(this).hasClass('collapsed')) {
			$(this).removeClass('collapsed');
			$(this).removeClass('collapse');
		} else {
			$(this).addClass('collapse');
			if ($(this).height() > min_collapse_height) {
				$(this).addClass('collapsed');
			}
		}
	});
	$('#content .code pre').addClass('collapse')
	.filter(function() {
		return $(this).height() > min_collapse_height;
	}).addClass('collapsed');

	$('#content .code pre')
	.resize(function() {
		if($(this).hasClass('collapse') && $(this).height() > min_collapse_height) {
			$(this).addClass('collapsed');
		} else {
			$(this).removeClass('collapsed');
		}	
	});

	RSSSEARCH.init('feed.rss', '#search');

	// make the index
	INDEX.init('index.json', null, function(idx) {
		idx.set_formatter(function(v) {
			if(!v) {
				return '';
			}
			var ret = v.title;
			if ( v.link ) {
				ret = '<a href="' + v.link + '">'
					+ ret + '</a>';
			}
			return ret;
		});
		idx.set_styler(function(el, v) {
			if(!v) {
				return '';
			}
			if (v.value && v.value.type != "") {
				$(el).addClass(v.value.type);
			}
		});
		idx.set_bullet_styler(function(el, v) {
			if(!v) {
				return '';
			}
			if (v.value && v.value.type != "") {
				$(el).addClass('index_icon_' + v.value.type);
				$(el).width(16);
				$(el).height(16);
				$(el).css({
					'padding-right' : '2px',
					'background-image': 'url(css/icons/'+v.value.type+'.png)',
					'background-repeat': 'no-repeat',
					'vertical-align' : 'middle',
				});
				var c = $(el).data('index_children');
				if (c) {
					$(el).click(function () {
						$(c).toggle(50);
					});

					$(el).addClass('hoverbox');
				}
				var d = $(el).data('index_depth');
				if (c && d > 0) {
					$(c).hide();
				}
			}
		});

		var root = idx.make_list('#index');

		$(window).bind( 'hashchange', function( event ) {
			var ch = idx.all_children();

			for (var i = 0; i < ch.length; i++) {
				var e = $(ch[i]).data('index_element');
				$(e).removeClass('marked');
			};

			// show/hide index items
			var loc = window.location.href;
			loc = loc.split("/");
			loc = decodeURIComponent (loc[loc.length-1]);

			// empty loc => are on top
			if(loc == '') {
				return;
			}

			var loc_leaves = idx.find_subtree(function(el) {
				var dta = $(el).data('index_record');
				if( dta.value && 
					dta.value.link && 
					decodeURIComponent(dta.value.link).indexOf(loc) >= 0) {
					return true;
				} else {
					return false;
				}
			});

			for (var i = 0; i < loc_leaves.length; i++) {
				var c = $(loc_leaves[i]).data('index_children');
				$(c).show();
				var e = $(loc_leaves[i]).data('index_element');
				$(e).addClass('marked');
			};
		});
		// update selection for the first time
		$(window).trigger('hashchange');
	})
});
