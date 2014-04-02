if (typeof jQuery !== 'undefined') {
	(function($) {
		$('#spinner').ajaxStart(function() {
			$(this).fadeIn();
		}).ajaxStop(function() {
			$(this).fadeOut();
		});
	})(jQuery);
}

/*------------------------- UTILITIES ------------------------------*/
/************************************************************\
 * build records query handling multiple uids
 * uidSet can be a comma-separated string or an array
 \************************************************************/
function buildQueryString(uidSet) {
    var uids = (typeof uidSet == "string") ? uidSet.split(',') : uidSet;
    var str = "";
    $.each(uids, function(index, value) {
        str += solrFieldNameForUid(value) + ":" + value + " OR ";
    });
    return str.substring(0, str.length - 4);
}
/************************************************************\
 * returns the appropriate facet name for the uid - to build
 * biocache occurrence searches
 \************************************************************/
function solrFieldNameForUid(uid) {
    switch(uid.substring(0,2)) {
        case 'co': return "collection_uid";
        case 'in': return "institution_uid";
        case 'dp': return "data_provider_uid";
        case 'dr': return "data_resource_uid";
        case 'dh': return "data_hub_uid";
        default: return "";
    }
}
/************************************************************\
 * Concatenate url fragments handling stray slashes
 \************************************************************/
function urlConcat(base, context) {
    // remove any trailing slash from base
    base = base.replace(/\/$/, '');
    // remove any leading slash from context
    context = context.replace(/^\//, '');
    // join
    return base + "/" + context;
}
// an abstraction to generalise the handling of ajax responses by different modules
function AjaxLauncher (baseUrl) {
    var self = this;
    this.baseUrl = baseUrl;
    this.subscribers = {};
    this.launch = function (query, keyword) {
        keyword = keyword === undefined ? 'default' : keyword;
        query = query === undefined ? '' : query;
        var xhr = $.ajax({url: baseUrl + query, dataType: 'jsonp', timeout: 20000}),
            list = self.subscribers[keyword];
        if (list !== undefined) {
            $.each(list, function (idx, callback) {
                callback(xhr, keyword);
            });
        }
    };
    this.subscribe = function (callback, keyword) {
        keyword = keyword === undefined ? 'default' : keyword;
        var list = self.subscribers[keyword];
        if (list === undefined) {
            list = [];
            self.subscribers[keyword] = list;
        }
        list.push(callback);
    };
}

