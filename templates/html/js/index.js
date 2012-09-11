/** Index and search using a static page index */
var INDEX = {};
(function(I) {
	'use strict';

	/** default formatter for making lists and such */
	function default_formatter(v) {
		return ''+v;
	}

	/** default style */
	function default_styler (el, v) {
	}

	/** make new element, append and return it */
	function make_and_append(jq, el) {
		var selection = $('');
		for (var i = 0; i < $(jq).length; i++) {
			var he = document.createElement(el);
			$($(jq)[i]).append(he)
			selection = selection.add(he);
		};
		return selection;
	}

	/** constructor for index objects

		We expect data to be in a tree format: we the element 'value' is 
		used for search, the element 'children' must be an array of 
		elements.

	 */
	var Index = function (data) {
		this.data = data;
		this.format = default_formatter;
		this.styler = default_styler;
		this.bullet_styler = default_styler;
	};

	/** update the formatter */
	Index.prototype.set_formatter = function(f) {
		this.format = f;
	};

	/** update the styler */
	Index.prototype.set_styler = function (f) {
		this.styler = f;
	}

	/** update the styler */
	Index.prototype.set_bullet_styler = function (f) {
		this.bullet_styler = f;
	}

	/** make a list with links from the index, append to 
	    element with selector id */
	Index.prototype.make_list = function(id, d, rec, parent) {
		rec = rec||0;
		if(!d) {
			if (rec) {
				return;
			} else {
				d = this.data;
				$(id).addClass('index_tree');
			}
		}
		var bullet = make_and_append(id, 'img');
		bullet.attr('src', 'css/pixel.png');
		$(bullet).data('index_record', d);
		$(bullet).data('index_parent', parent);

		var el = make_and_append(id, 'span')
			.html(this.format(d.value));

		$(bullet).data('index_element', el);
		
		if (d.children && d.children.length > 0) {
			var children = make_and_append(id, 'ul');
			for (var i = 0; i < d.children.length; i++) {
				var li = make_and_append(children, 'li');
				this.make_list(li, d.children[i], rec+1, bullet);
			};
			$(el).data('index_children', children);
			$(el).data('index_depth', rec);
			$(bullet).data('index_children', children);
			$(bullet).data('index_depth', rec);
		};

		this.bullet_styler(bullet, d);
		this.styler(el, d);
		this.top_bullet = bullet;
		this.div = id;
	};

	/** find subtree which contains a selection of leaves
	    and all paths to the root from there
		
		Parameters:
		A selector to pick the bullet elements for the leaves we want.

		Returns: 
		The subtree bullet elements as a jQuery selection
    */
	Index.prototype.find_subtree = function(selector) {
		var leaves = $('img', this.div)
			.filter(function () { return selector(this); } );

		var list = $();
		for (var i = 0; i < leaves.length; i++) {
			var x= leaves[i];
			while(x) {
				list = list.add(x);
				x = $(x).data('index_parent');
			}
		};
		return list;
	}

	/** Walk the index, return all children of a given node
		
		Parameters:
		root : the node to start with (index root is used when not 
		       defined)

		Returns: 
		The subtree bullet elements as a jQuery selection
	  */
	Index.prototype.all_children = function(root) {
		if (!root) {
			root = this.top_bullet;
		}
		return $( 'img', $(root).parent() );
	}

	/** init index from a source URL
		Parameters:
		sourceurl : the url to get the JSON stuff from
		data : parameters for JSON request
		indexready: callback function, passed one argument 
		           (the index object, see below)
	 */
	I.init = function (sourceurl, data, indexready) {
		$.ajax({
			url: sourceurl,
			dataType: 'json',
			data: data,
			success: function(jsd) {
				indexready( new Index(jsd) );
			}
		});
	};
})(INDEX);