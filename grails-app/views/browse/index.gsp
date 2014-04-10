<%@ page contentType="text/html;charset=UTF-8" %>
<html>
<head>
    <meta name="layout" content="main"/>
    <title>Specimen image browser prototype</title>
    <r:require modules="knockout,bbq"/>
    <r:script disposition="head">
        var biocacheServicesUrl = "${grailsApplication.config.biocacheServicesUrl}",
            biocacheWebappUrl = "${grailsApplication.config.biocache.baseURL}",
            collectoryServicesURL = "${grailsApplication.config.collectory.servicesURL}",
            imageViewerBaseUrl = "${createLink(controller: 'view', action: 'view')}",
            entityUid = "${uid}";
    </r:script>
</head>

<body>
    <div id="content">
        <h2>Specimen images from <span data-bind="text:entityName"></span></h2>
        <div class="row-fluid">
            <div class="span3 well well-small">
                <span data-bind="click:clearAllFilters" class="clickable">All</span>
                <div data-bind="with:taxonomy" id="taxonomyFacet">
                    <h3>Taxonomy</h3>
                    <ul style="margin-left:0; margin-bottom:0;">
                        <!-- ko foreach:hierarchy -->
                        <li data-bind="css:levelClass">
                            <span style="font-weight:bold;" data-bind="text:displayRank"></span>:
                            <span class="clickable" data-bind="visible:isClickable,text:name,click:$parent.clearFilters"></span>
                            <span data-bind="visible:!isClickable,text:name"></span>
                        </li>
                        <!-- /ko -->
                        <li data-bind="css:levelClassForCurrentRank">
                            <span style="font-weight:bold;" data-bind="text:currentRankLabel"></span>
                            <ul>
                                <!-- ko foreach:valuesForCurrentRank -->
                                <li><span class="clickable" data-bind="visible:!$parent.selectedASingleValueAtLowestRank(),click:$parent.filterSearch,attr:{id:label}"><span data-bind="text:label"></span> (<span data-bind="text:count"></span>)</span></li>
                                <li><span data-bind="visible:$parent.selectedASingleValueAtLowestRank"><span data-bind="text:label"></span> (<span data-bind="text:count"></span>)</span></li>
                                <!-- /ko -->
                            </ul>
                        </li>
                    </ul>
                </div>
                <div data-bind="foreach:facets.list">
                    <h3 data-bind="text:fieldLabel" style="margin-bottom:0;line-height:30px;"></h3>
                    <ul data-bind="attr:{id:fieldName}">
                        <!-- ko foreach:values -->
                        <li><span class="clickable" data-bind="click:$parent.filterSearch,attr:{id:label}"><span data-bind="text:label"></span> (<span data-bind="text:count"></span>)</span></li>
                        <!-- /ko -->
                        <li><span class="clickable" data-bind="click:filterSearch">all values</span></li>
                    </ul>
                </div>
                %{--<div id="debug2">
                    <pre>Images: <span data-bind="text:imageList.numberOfImages"></span></pre>
                    <pre>Records processed: <span data-bind="text:imageList.numberOfRecordsProcessed"></span></pre>
                    <pre>Offset: <span data-bind="text:imageList.offset"></span></pre>
                </div>--}%
            </div>
            <div class="span9">
                <div class="alert alert-success" data-bind="visible:loadStatus()==='done'">
                    <span data-bind="text:totalRecords"></span> images are available.
                </div>
                <div class="alert alert-warning" data-bind="visible:loadStatus()==='no results'">No images are available for this search.</div>
                <div class="alert alert-error" data-bind="visible:loadStatus()==='error'">An error occurred.</div>
                <div class="alert alert-error" data-bind="visible:loadStatus()==='timeout'">The search timed out.</div>
                <div id="debug" data-bind="if:taxonomy">
                    %{--<pre>Current rank: <span data-bind="text:taxonomy.currentRank"></span></pre>
                    <pre>Original rank: <span data-bind="text:taxonomy.originalRank"></span></pre>
                    <pre>selectedASingleValueAtLowestRank: <span data-bind="text:taxonomy.selectedASingleValueAtLowestRank"></span></pre>--}%
                    %{--<pre data-bind="text:ko.toJSON(taxonomy.hierarchy,null,2)"></pre>--}%
                    %{--<pre data-bind="text:ko.toJSON(query,null,2)"></pre>--}%
                </div>
                <div data-bind="foreach: imageList.images" id="imagesList">
                    <div class="imgCon">
                        <a data-bind="attr:{href:largeImageViewerUrl}">
                            <img data-bind="attr:{src:smallImageUrl,'data-width':thumbWidth,'data-height':thumbHeight}"/><br/>
                        </a>
                        <div class="meta brief" data-bind="attr:{'data-uuid':uuid}">
                            <ul class="unstyled pull-left" style="margin: 0">
                                <li class="title" data-bind="text:scientificName"></li>
                            </ul>
                        </div>
                        <div class="meta full hover-target" data-bind="attr:{'data-uuid':uuid}">
                            <ul class="unstyled pull-left" style="margin: 0">
                                <li class="title" data-bind="text:scientificName"></li>
                                <li data-bind="text:vernacularName,visible:vernacularName"></li>
                                <li data-bind="text:typeStatus,visible:typeStatus"></li>
                            </ul>
                            <span class="pull-right" style="position:absolute;bottom:4px;right:4px;">
                                <a data-bind="attr:{href:recordLink}"><i class="icon-info-sign icon-white"></i></a>
                                <a data-bind="attr:{href:largeImageViewerUrl}"><i class="icon-zoom-in icon-white"></i></a>
                            </span>
                        </div>
                    </div>
                </div>
                <div style="text-align:center;margin-top:15px;">
                    <r:img style="" data-bind="visible:isLoading" dir="images" file="ajax-loader.gif"/>
                    <span data-bind="visible:!hasMoreResults()&&!isLoading(),click:imageList.getMoreResults" class="btn clickable">Show more results</span>
                </div>
            </div>
        </div>

    </div>
    <r:script>

        var wsBase = "/occurrences/search.json",
            uiBase = "/occurrences/search",
            ranks = ['kingdom', 'phylum', 'class', 'order', 'family', 'genus', 'species'/*, 'subspecies_name'*/], // support division and sub-ranks later
            facetNames = {type_status: 'Types', raw_sex: 'Sex', family: 'Family', order: 'Order', 'class': 'Class',
                kingdom: 'Kingdom', phylum: 'Phylum', genus: 'Genus', species: 'Species', subspecies_name: 'Sub-species'},
            facetsToShow = ["type_status", "raw_sex"],
            baseQuery = "?fq=multimedia:Image&im=true",
            richQuery,
            pageSize = 100;

        // add taxonomy facets sub-query
        $.each(ranks, function (idx, facet) {
            baseQuery += "&facets=" + facet;
        });

        richQuery = baseQuery + "&pageSize=" + pageSize;

        // add general facets to rich query
        $.each(facetsToShow, function (idx, facet) {
            richQuery += "&facets=" + facet;
        });

        var entityNameLookup = new AjaxLauncher(collectoryServicesURL + 'resolveNames/'),
            richQueryUrl = richQuery + "&q=" + (entityUid === '' ? '*:*' : buildQueryString(entityUid)),
            imagesLookup = new AjaxLauncher(urlConcat(biocacheServicesUrl, wsBase + richQueryUrl));

        var initialQueryResultsLoaded;

        $(window).load(function () {

            // handles general (ie non-taxonomic) facets
            function Facet(data, topModel) {
                var self = this;
                this.fieldName = data.fieldName;
                this.fieldLabel = facetNames[data.fieldName] || data.fieldName;
                this.values = ko.observableArray(data.fieldResult);
                this.filterSearch = function () {
                    // we detect if this is triggered from the 'all values' link by checking whether the
                    // context (this) is the Facet object itself
                    if (this === self) {
                        self.removeFacetFilter(self.fieldName);
                    } else {
                        self.addFacetFilter(self.fieldName, this.label);
                    }
                };
                this.removeFacetFilter = function (fieldName) {
                    // adding/removing the filter should automatically invoke a new search because of the dependency chain
                    topModel.removeFilter(fieldName);
                };
                this.addFacetFilter = function (fieldName, value) {
                    // adding/removing the filter should automatically invoke a new search because of the dependency chain
                    topModel.addFilter(fieldName, value);
                };
            }

            function Facets(parent) {
                var self = this;
                // the facet data returned from the search
                this.list = ko.observableArray([]);

                // handler for completed image searches
                imagesLookup.subscribe(function (xhr, key) {
                    xhr.done(function (data) {
                        // load facets
                        self.list($.grep($.map(data.facetResults, function (item) {
                            return new Facet(item, parent);
                        }), function (item) {
                            return $.inArray(item.fieldName, facetsToShow) > -1;
                        }));
                    });
                }, 'imagesSearch');
            }

            // represents a displayed image
            function Image(data) {
                var self = this,
                    metadata = data.imageMetadata[0];

                this.scientificName = data.scientificName;
                this.vernacularName = data.vernacularName;
                this.smallImageUrl = metadata ? metadata.thumbUrl : data.smallImageUrl;
                this.thumbWidth = metadata.thumbWidth;
                this.thumbHeight = metadata.thumbHeight;
                this.largeImageUrl = metadata ? metadata.imageUrl : data.largeImageUrl;
                this.typeStatus = data.typeStatus;
                this.uuid = data.uuid;
                this.largeImageViewerUrl = ko.computed(function () {
                    var url = imageViewerBaseUrl + '/' + metadata.imageId;
                    url += '?title=' + self.scientificName;
                    if (self.vernacularName !== undefined) {
                        url += '&common=' + self.vernacularName;
                    }
                    url += '&recordId=' + self.uuid;
                    return url;
                });
                this.recordLink = ko.computed(function () {
                    return biocacheWebappUrl + 'occurrences/' + self.uuid;
                });
                this.imageCaption = ko.computed(function () {
                    var imageText = self.scientificName;
                    if (self.typeStatus !== undefined) {
                        imageText = self.typeStatus + " - " + imageText;
                    }
                    return imageText;
                });
            }

            function ImageList(parent) {
                var self = this;
                // the images
                this.images = ko.observableArray([]);

                // the next offset for getting results
                this.offset = 0;

                // the number of results processed (potentially > the number of actual images displayed)
                this.recordsProcessed = ko.observable(0);

                // handler for completed image searches
                imagesLookup.subscribe(function (xhr, key, context) {
                    xhr.done(function (data) {
                        // clear list unless we are loading more
                        if (context !== 'load-more') {
                            self.images([]);
                            self.recordsProcessed(0);
                            self.offset = 0;
                        }
                        self.recordsProcessed(self.recordsProcessed() + data.occurrences.length);

                        // temp hack to filter out images without metadata
                        var imagesWithMetadata = $.grep(data.occurrences, function (item) {
                            return (item.imageMetadata !== undefined);
                        });
                        ko.utils.arrayPushAll(self.images, $.map(imagesWithMetadata, function (item) {
                            return new Image(item);
                        }));
                        // layout images
                        imageLayout.layoutImages();
                    });
                    xhr.fail(function () {
                        self.images([]);
                    });
                }, 'imagesSearch');

                this.numberOfImages = ko.computed(function () {
                    return self.images().length;
                });

                this.numberOfRecordsProcessed = ko.computed(function () {
                    return self.recordsProcessed();
                });

                this.getMoreResults = function () {
                    self.offset += pageSize;
                    viewModel.load('load-more', self.offset);
                };
            }

            // represents the search criteria - a change in the query string will trigger a new search
            function Query() {
                var self = this;

                // list of filters that are dynamically added to the search
                this.filters = ko.observableArray([]);

                // triggering searches on query change can be turned off for batched changes
                //  (eg for loading initial state)
                this.autoQueryEnabled = false;
                this.autoOff = function () {
                    self.autoQueryEnabled = false
                };
                this.autoOn = function () {
                    self.autoQueryEnabled = true
                };

                // adds a new filter to the query
                this.addFilter = function (name, value) {
                    // check for duplicates
                    var existing = $.grep(self.filters(), function (filter) {
                        return filter.name === name;
                    });
                    if (existing.length > 0) {
                        if (existing[0].value !== value) {
                            existing[0].value = value;
                        }
                    } else {
                        self.filters.push({name: name, value: value});
                    }
                };

                // removes a filter
                this.removeFilter = function (name) {
                    self.filters.remove(function (item) {
                        return item.name === name
                    });
                };

                // removes all filters
                this.clear = function () {
                    self.filters([]);
                };

                // removes all filters
                this.isEmpty = function () {
                    return self.filters().length === 0;
                };

                // the queryString is recomputed whenever a filter changes
                this.queryString = ko.computed(function () {
                    var qs = "";
                    ko.utils.arrayForEach(self.filters(), function (item) {
                        qs += '&fq=' + item.name + ':' + item.value;
                    });
                    return qs;
                });

                // redo the search when the queryString changes
                this.queryString.subscribe(function () {
                    if (self.autoQueryEnabled) {
                        viewModel.load();
                    }
                });
            }

            function UpperContextRank(rank, value, idx, contextOnly) {
                var self = this;
                this.rank = rank;
                this.value = value;
                this.displayRank = facetNames[rank] || rank;
                this.name = value.label;
                this.count = value.count;
                this.levelClass = 'level' + idx;
                this.isClickable = !contextOnly;
            }

            // builds the taxonomy widget based on rank facets
            function Taxonomy(parent) {
                var self = this;

                // the rank whose facets we are currently displaying
                this.currentRank = ko.observable('');

                // the initial current rank - useful if we only want to have links to go back to the initial
                // rank and not higher
                this.originalRank = ko.observable('');

                // the rank that is being targeted for the next search
                /* eg if current rank is Order and the user selects a particular Order, the next rank
                 will be Family. We need to know this because the targeted rank cannot always be
                 divined from the results - such as when the targeted rank has only one facet value.
                 */
                this.nextRank = "";

                // a flag that indicates that a specific value has been chosen from the lowest rank
                /* we need this because the behaviour is different when there is no lower rank to display
                 */
                this.selectedASingleValueAtLowestRank = ko.observable(false);

                // the display version of the current rank - these are defined in the facetNames list
                this.currentRankLabel = ko.computed(function () {
                    return facetNames[self.currentRank()] || self.currentRank()
                });

                // the facet values for the current rank
                this.valuesForCurrentRank = ko.observableArray();

                // the rank hierarchy that is above the current rank
                this.hierarchy = ko.observableArray();

                // returns facet values for the specified rank
                this.getFacetsForRank = function (facets, rank) {
                    var field = $.grep(facets, function (facet, idx) {
                        return facet.fieldName === rank;
                    });
                    return field.length === 0 ? undefined : field[0].fieldResult;
                };

                // adds a rank and its name to the rank hierarchy
                this.addToHierarchy = function (rank, value, idx, contextOnly) {
                    self.hierarchy.push(new UpperContextRank(rank, value, idx, contextOnly));
                };

                // sets a css class for the current rank based on the number of ranks above it
                // - used for the level of indentation for example
                this.levelClassForCurrentRank = ko.computed(function () {
                    return 'level' + (self.hierarchy().length);
                });

                // handler for completed image searches
                imagesLookup.subscribe(function (xhr, key) {
                    xhr.done(function (data) {
                        var facets = data.facetResults, aboveOriginalRank = true;

                        // clear the hierarchy
                        self.hierarchy.removeAll();

                        //console.log('taxonomy:load: currentRank = ' + self.currentRank());
                        // if there is no current rank then we are doing a fresh load and need to calculate
                        //  the current rank based on the number of facet values at each rank (we are looking
                        //  for the highest rank with multiple values)
                        if (self.currentRank() === '') {
                            //console.log('taxonomy:load: finding currentRank');
                            // no ranks have been determined yet so this must be the initial query
                            //  determine a starting rank based on the data
                            var done = false;
                            $.each(ranks, function (idx, rank) {
                                var result = self.getFacetsForRank(facets, rank);
                                if (result !== undefined && !done && result.length > 0) {
                                    //console.log('taxonomy:load: rank = ' + rank + ', results = ' + result.length);
                                    if (result.length > 1) {
                                        // first rank with multiple values so set the current rank
                                        self.currentRank(rank);
                                        // set the next rank initially to current - this is needed if the next
                                        //  query changes a non-taxonomic facet
                                        self.nextRank = rank;
                                        // set the original rank if it has not been set
                                        if (self.originalRank() === '') {
                                            self.originalRank(rank);
                                            //console.log('taxonomy:load: originalRank set to ' + rank);
                                        }
                                        done = true;
                                    }
                                }
                            });
                            // catch-all for if all ranks have 1 value
                            if (self.currentRank() === '') {
                                self.currentRank(ranks[ranks.length - 1]);
                                self.originalRank(ranks[ranks.length - 1]);
                            }
                        } else {
                            // set current rank to the next rank to display
                            // Note this is not necessarily the child rank - it can be any rank
                            self.currentRank(self.nextRank);
                        }

                        // add ranks above the current to the hierarchy
                        $.each(ranks.slice(0, $.inArray(self.currentRank(), ranks)), function (idx, rank) {
                            var result = self.getFacetsForRank(facets, rank);
                            if (result !== undefined && result.length > 0) {
                                // set a flag to indicate whether this rank is above or below the oriinal
                                //  rank - this allows the ui to handle these differently eg. for links
                                if (self.childRank(rank) === self.originalRank()) {
                                    aboveOriginalRank = false
                                }
                                //console.log('load: rank = ' + rank + ', original = ' + self.originalRank() + ', above = ' + aboveOriginalRank);
                                self.addToHierarchy(rank, result[0], idx, aboveOriginalRank);
                            }
                        });

                        // add the current rank values
                        self.valuesForCurrentRank(self.getFacetsForRank(facets, self.currentRank()));

                    });
                }, 'imagesSearch');

                // returns the next lower rank unless it is already at the lowest rank
                this.childRank = function (rank) {
                    var idx = $.inArray(rank, ranks);
                    return idx < ranks.length - 1 ? ranks[idx + 1] : rank;
                };

                // removes filters for the specified rank and all below it
                this.clearRankAndBelow = function (rank) {
                    var idx = $.inArray(rank, ranks),
                            ranksToClear = ranks.slice(idx);
                    self.selectedASingleValueAtLowestRank(false);
                    $.each(ranksToClear, function (idx, item) {
                        parent.removeFilter(item);
                    });
                };

                // sets a new target rank and triggers a new search by removing filters for the target
                //  rank and any below it
                this.clearFilters = function () {
                    //console.log('clearFilters: rank = ' + this.rank + ', context = ' + this.contextOnly);
                    self.nextRank = self.childRank(this.rank);
                    self.clearRankAndBelow(self.nextRank);
                };

                // sets a new target rank and triggers a new search by removing filters for the target
                //  rank and any below it
                this.setRank = function () {
                    self.nextRank = this.rank;
                    self.clearRankAndBelow(this.rank);
                };

                // handles the setRank functionality for when the lowest rank link is clicked
                /*this.setLowestRank = function () {
                 self.nextRank = ranks[ranks.length - 1];
                 self.clearRankAndBelow(self.nextRank);
                 self.selectedASingleValueAtLowestRank(false);
                 };*/

                // this allows the state to be set externally - eg for initial state
                /* - note that it may be necessary to add the ranks in the correct order. Seems to work for now.
                 */
                this.setState = function (rank, value) {
                    // first make sure this is a taxonomic rank
                    if ($.inArray(rank, ranks) === -1) {
                        return false;
                    } else {
                        self.addTaxonFilter(rank, value);
                        return true;
                    }
                };

                // handles selection of a specific rank value through the UI
                this.filterSearch = function () {
                    self.addTaxonFilter(self.currentRank(), this.label);
                };

                // adds a filter for a specific named taxon - triggers a new search if auto query is on
                this.addTaxonFilter = function (rank, name) {
                    // increment target rank unless we are already at the bottom
                    if (rank === ranks[ranks.length - 1]) { // is the lowest rank
                        self.selectedASingleValueAtLowestRank(true);
                    } else {
                        self.selectedASingleValueAtLowestRank(false);
                        self.nextRank = self.childRank(rank);
                    }
                    parent.addFilter(rank, name);
                };

                // reset to the original rank
                this.reset = function () {
                    self.nextRank = '';//self.originalRank();
                    self.currentRank('');
                };

                this.findOriginalRankFromInitialState = function (states) {
                    // find the highest level rank that is present in the states
                    var found = false, highest;
                    $.each(ranks, function (idx, rank) {
                        if (!found && states[rank] !== undefined) {
                            highest = rank;
                            found = true;
                        }
                    });
                    return highest;
                };
            }

            function ViewModel() {
                var self = this;
                // the uid of the entity to browse
                this.entityUid = ko.observable(entityUid);
                // the display name for the entity - this is updated asynchronously by a collectory look-up
                this.entityName = ko.observable(self.entityUid() || ' entire Atlas'); // display the uid while the name is being retrieved

                // ajax call to get the readable name of the entity
                if (self.entityUid() !== '') {
                    // look up the entity name
                    entityNameLookup.subscribe(function (xhr) {
                        xhr.done(function (data) {
                            var name = data[self.entityUid()];
                            if (name) {
                                self.entityName(name);
                            }
                        });
                    });
                    entityNameLookup.launch(self.entityUid());
                }

                // the images
                this.imageList = new ImageList(self);
                // the non-taxonomic facets
                this.facets = new Facets(self);
                // the widget for traversing the taxonomy ranks in the returned facet data
                this.taxonomy = new Taxonomy(this);

                // the constructed search query - a change to this triggers a new search
                this.query = new Query();
                // the number of records returned from the search
                this.totalRecords = ko.observable();

                this.hasMoreResults = ko.computed(function () {
                    //console.log("hasMoreResults: total records = " + self.totalRecords() + " records processed = " + self.imageList.numberOfRecordsProcessed());
                    return self.totalRecords() === undefined ? false : self.imageList.numberOfRecordsProcessed() >= self.totalRecords();
                });

                // adds a filter and updates the url
                this.addFilter = function (facetName, facetValue) {
                    var obj = {};
                    obj[facetName] = facetValue;
                    $.bbq.pushState(obj);
                    self.query.addFilter(facetName, facetValue);
                };

                // removes a filter and updates the url
                this.removeFilter = function (facetName) {
                    $.bbq.removeState(facetName);
                    self.query.removeFilter(facetName);
                };

                // implements the 'all' function - removes all filters
                // Note - it only resets fields if the query is not already showing all results. This is
                //  because no search is done if the query doesn't change and clearing fields such as
                //  current rank will stuff up if a new search isn't performed.
                this.clearAllFilters = function () {
                    if (!self.query.isEmpty()) {
                        self.taxonomy.reset();
                        document.location.hash = '';
                        self.query.clear();
                    }
                };

                // true while a search is in progress - hook for ui indicators
                this.isLoading = ko.observable(false);

                // contains error messages that may result from searches
                this.loadStatus = ko.observable('');

                // handler for completed image searches
                // - this just does the global stuff, other objects have their own listeners
                imagesLookup.subscribe(function (request, keyword) {
                    // handle global effects
                    request.fail(function (jqXHR, textStatus) {
                        self.loadStatus(textStatus);
                    });
                    request.always(function () {
                        self.isLoading(false);
                    });
                    request.done(function (data) {
                        // check for errors
                        if (data.length == 0 || data.totalRecords == undefined || data.totalRecords == 0) {
                            self.loadStatus('no results');
                        } else if (data.totalRecords > 0) {
                            self.totalRecords(data.totalRecords);
                            self.loadStatus('done');
                        }
                    });
                }, 'imagesSearch');

                // launches the search
                this.load = function (userData, offset) {
                    var start = (offset !== undefined && offset > 0) ? '&start=' + offset : '';
                    self.isLoading(true);
                    //console.log("load: queryString = " + self.query.queryString());
                    imagesLookup.launch(self.query.queryString() + start, 'imagesSearch', userData);
                }
            }

            var viewModel = new ViewModel();
            ko.applyBindings(viewModel);

            // get any initial state from the url hashes
            var states = $.bbq.getState();

            // if there is initial state then we can't derive the original rank form the facet data
            //  so we need to examine the state to find out what it was
            var originalRank = viewModel.taxonomy.findOriginalRankFromInitialState(states);
            if (originalRank !== undefined) {
                viewModel.taxonomy.originalRank(originalRank);
            }

            // set initial state based on location hashes
            //  - note that these do not trigger searches as auto-query is initially disabled
            $.each(states, function (key, value) {
                viewModel.taxonomy.setState(key, value); // only sets state for known ranks
                // only set state for known general facets
                if ($.inArray(key, facetsToShow) !== -1) {
                    viewModel.query.addFilter(key, value);
                }
            });

            // turn auto-query on so that any filter changes trigger a new search
            viewModel.query.autoOn();

            // do the initial search
            // console.log('onload: searching..');
            viewModel.load();

        });

        // handles the resizing of images to achieve a gapless style similar to google images or flickr
        function ImageLayout() {
            var self = this,
                    $imageContainer = $('#imagesList'),
                    MAX_HEIGHT = ${maxRowHeight};

            this.getheight = function (images, width) {
                width -= images.length * 5;
                var h = 0;
                for (var i = 0; i < images.length; ++i) {
                    if ($(images[i]).data('width') === undefined) {
                        $(images[i]).data('width', $(images[i]).width());
                    }
                    if ($(images[i]).data('height') === undefined) {
                        $(images[i]).data('height', $(images[i]).height());
                    }
                    //console.log("original = " + $(images[i]).data('width') + '/' + $(images[i]).data('height'));
                    h += $(images[i]).data('width') / $(images[i]).data('height');
                }
                //console.log("row count = " + images.length + " row height = " + width / h);
                return width / h;
            };

            this.setheight = function (images, height) {
                for (var i = 0; i < images.length; ++i) {
                    //console.log("setting width to " + height * $(images[i]).data('width') / $(images[i]).data('height'));
                    $(images[i]).css({
                        width: height * $(images[i]).data('width') / $(images[i]).data('height'),
                        height: height
                    });
                }
            };

            this.layoutImages = function (maxHeight) {
                var size = $imageContainer.innerWidth() - 30,
                        n = 0,
                        images = $imageContainer.find('img');
                if (maxHeight === undefined) {
                    maxHeight = MAX_HEIGHT;
                }
                w: while (images.length > 0) {
                    for (var i = 1; i < images.length + 1; ++i) {
                        var slice = images.slice(0, i);
                        var h = self.getheight(slice, size);
                        if (h < maxHeight) {
                            self.setheight(slice, h);
                            n++;
                            images = images.slice(i);
                            continue w;
                        }
                    }
                    self.setheight(slice, Math.min(maxHeight, h));
                    n++;
                    break;
                }
            };

            window.addEventListener('resize', function () {
                self.layoutImages();
            });
        }

        var imageLayout = new ImageLayout();

    </r:script>
</body>
</html>