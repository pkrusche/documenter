'use strict'
var RSSSEARCH = {};

$.widget( "custom.searchcomplete", $.ui.autocomplete, {
	_renderMenu: function( ul, items ) {
		var self = this,
			currentCategory = "";
			$.each( items, function( index, item ) {
				if ( item.category != currentCategory ) {
					ul.append( "<li class='ui-autocomplete-category'>" + item.category + "</li>" );
					currentCategory = item.category;
				}
				return $( "<li></li>" )
						.data( "item.autocomplete", item )
						.append( "<a>" + item.label + "</a>" )
						.appendTo( ul );
			});
	}
});

(function(R){
	R.init = function(url, searchbox) {
		$(searchbox).html('<input type="text"></input>');
		jQuery.ajax({
		  url: url,
		  type: 'GET',
		  dataType: 'xml',
		  success: function( xmlResponse ) {
				var data = $( "item", xmlResponse ).map(function() {
					var desc = $( 'description', this ).text();
					var title = $( 'title', this ).text();
					
					var m = desc.split(':');
					var cat = 'Others';
					var path = '';

					// format: <cat>:<level>:<index_pos>:<path>
					if (m && m[0]) {
						cat = m[0];
					}
					
					if (m && m[3]) {
						path = m[3];
					}

					return {
						value: path + ":" + title,
						path: path,
						category: cat,
						id: title, 
						link: $( 'guid', this).text()
					};
				}).get();

				// sort data so the search results don't get mixed
				data = data.sort(function(a, b){
					var cata = a.category.toLowerCase(), 
						catb = b.category.toLowerCase();
					var patha = a.category.toLowerCase(), 
						pathb = b.category.toLowerCase();

					 if (patha < pathb) {
						return -1;
					 }
					 if (patha > pathb) {
						return 1;
					 }
					 if (cata < catb) {
						return -1;
					 }
					 if (cata > catb) {
						return 1;
					 }
					 return 0;
				});


				$('input', searchbox)
				 .addClass("ui-corner-all")
				 .addClass("ui-widget")
				 .searchcomplete({
					source: function(request, response) {
						var the_term = request.term;
						var searcharray = [];
						var tmatch = the_term.match(/^([A-Za-z0-9]+)\:(.*)/);
						
						// stuff prefixed by <type>: gets filtered first
						if (tmatch) {
							var type = tmatch[1].toLowerCase();
							the_term = tmatch[2];
							searcharray = data.filter(function(a) {return a.category == type;});
						} else {
							searcharray = data;
						}
						
						var matcher = new RegExp( $.ui.autocomplete.escapeRegex(the_term), "i" );

						response( searcharray.map(function(a) {
							if(!a) {
								return;
							}
							var text = a.value;
							var cat = a.category;
							if ( text && ( !request.term || matcher.test(text) ) )
								return {
									label: text.replace(
										new RegExp(
											"(?![^&;]+;)(?!<[^<>]*)(" +
											$.ui.autocomplete.escapeRegex(request.term) +
											")(?![^<>]*>)(?![^&;]+;)", "gi"
										), "<b>$1</b>" ),
									value: text,
									category: cat,
									link: a.link || '#'
								};
							}).filter(function(a) {return a})
						);
					},
					// minLength: 2,
					select: function( event, ui ) {
						window.location.href = ui.item.link;
					}
				});					
		  },
		  error: function(xhr, textStatus, errorThrown) {
		    console.log(xhr, textStatus, errorThrown);
		  }
		});
	}	
})(RSSSEARCH);
