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
            entityUid = "${uid}";
    </r:script>
</head>

<body>
    <div id="content">
        <h2>Specimen images from <span data-bind="text:entityName"></span> <r:img style="margin-left:100px;" data-bind="visible:isLoading" dir="images" file="ajax-loader.gif"/> </h2>
        <div class="row-fluid">
            <div class="span3 well well-small">
                <div data-bind="with:taxonomy" id="taxonomyFacet">
                    <h3>Taxonomy</h3>
                    <ul style="margin-left:0; margin-bottom:0;">
                        <!-- ko foreach:hierarchy -->
                        <li data-bind="css:levelClass">
                            <span style="font-weight:bold;" class="clickable"
                                  data-bind="text:displayRank,click:$parent.setRank"></span>:
                            <span data-bind="text:name"></span>
                        </li>
                        <!-- /ko -->
                        <li data-bind="css:levelClassForCurrentRank">
                            <span style="font-weight:bold;" class="clickable"
                                  data-bind="text:currentRankLabel,click:setLowestRank,visible:selectedASingleValueAtLowestRank"></span>
                            <span style="font-weight:bold;"
                                  data-bind="text:currentRankLabel,visible:!selectedASingleValueAtLowestRank()"></span>
                            <ul>
                                <!-- ko foreach:valuesForCurrentRank -->
                                <li><span class="clickable" data-bind="click:$parent.filterSearch,attr:{id:label}"><span data-bind="text:label"></span> (<span data-bind="text:count"></span>)</span></li>
                                <!-- /ko -->
                            </ul>
                        </li>
                    </ul>
                </div>
                <div data-bind="foreach:facets">
                    <h3 data-bind="text:fieldLabel" style="margin-bottom:0;line-height:30px;"></h3>
                    <ul data-bind="attr:{id:fieldName}">
                        <!-- ko foreach:values -->
                        <li><span class="clickable" data-bind="click:$parent.filterSearch,attr:{id:label}"><span data-bind="text:label"></span> (<span data-bind="text:count"></span>)</span></li>
                        <!-- /ko -->
                        <li><span class="clickable" data-bind="click:filterSearch">all values</span></li>
                    </ul>
                </div>
            </div>
            <div class="span9">
                <div class="alert alert-success" data-bind="visible:loadStatus()==='done'">
                    <span data-bind="text:totalRecords"></span> images are available.
                </div>
                <div class="alert alert-warning" data-bind="visible:loadStatus()==='no results'">No images are available for this search.</div>
                <div class="alert alert-error" data-bind="visible:loadStatus()==='error'">An error occurred.</div>
                <div class="alert alert-error" data-bind="visible:loadStatus()==='timeout'">The search timed out.</div>
                <div id="debug" data-bind="if:taxonomy()">
                    %{--<pre>Current rank: <span data-bind="text:taxonomy().currentRank"></span></pre>
                    <pre>selectedASingleValueAtLowestRank: <span data-bind="text:taxonomy().selectedASingleValueAtLowestRank"></span></pre>
                    <pre data-bind="text:ko.toJSON(taxonomy().hierarchy,null,2)"></pre>--}%
                    %{--<pre data-bind="text:ko.toJSON(query,null,2)"></pre>--}%
                </div>
                <div data-bind="foreach: imagesList">
                    <div class="imgCon"><a data-bind="attr:{href:bieLink}"><img data-bind="attr:{src:smallImageUrl}"/><br/><span data-bind="text:imageCaption"></span></a></div>
                </div>
            </div>
        </div>

    </div>
    <r:script>

        var wsBase = "/occurrences/search.json",
            uiBase = "/occurrences/search",
            ranks = ['kingdom', 'phylum', 'class', 'order', 'family', 'genus', 'species'], // support division and sub-ranks later
            facetNames = {type_status: 'Types', raw_sex: 'Sex', family: 'Family', order: 'Order', 'class': 'Class',
                kingdom: 'Kingdom', phylum: 'Phylum', genus: 'Genus', species: 'Species'},
            rankFacets = "",
            baseQuery = "fq=multimedia%3AImage&pageSize=100",
            facetsToShow = ["type_status", "raw_sex"],
            mainQuery = baseQuery;

        // build taxonomy facet sub-query
        $.each(ranks, function (idx, facet) {
            rankFacets += "&facets=" + facet;
        });

        // add general facets to main query
        $.each(facetsToShow, function (idx, facet) {
            mainQuery += "&facets=" + facet;
        });

        $(window).load(function () {

            // handles general (ie non-taxonomic) facets
            function Facet(data, parent) {
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
                    parent.removeFilter(fieldName);
                };
                this.addFacetFilter = function (fieldName, value) {
                    // adding/removing the filter should automatically invoke a new search because of the dependency chain
                    parent.addFilter(fieldName, value);
                };
            }

            // represents a displayed image
            function Image(data) {
                var self = this;
                this.scientificName = data.scientificName;
                this.smallImageUrl = data.smallImageUrl;
                this.typeStatus = data.typeStatus;
                this.uuid = data.uuid;
                this.bieLink = ko.computed(function () {
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

            // represents the search criteria - a change in the query string will trigger a new search
            function Query() {
                var self = this;

                // list of filters that are dynamically added to the search
                this.filters = ko.observableArray([]);

                // triggering searches on query change can be turned off for batched changes
                //  (eg for loading initial state)
                this.autoQueryEnabled = false;
                this.autoOff = function () { self.autoQueryEnabled = false };
                this.autoOn = function () { self.autoQueryEnabled = true };

                // adds a new filter to the query
                this.addFilter = function (name, value) {
                    // just add to list for now - may need to check for dups later
                    self.filters.push({name: name, value: value});
                };

                // removes a filter
                this.removeFilter = function (name) {
                    self.filters.remove(function (item) {
                        return item.name === name
                    });
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
                        viewModel.loadImages();
                    }
                });
            }

            // builds the taxonomy widget based on rank facets
            function Taxonomy(parent) {
                var self = this;

                // the rank whose facets we are currently displaying
                this.currentRank = ko.observable('');

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
                this.addToHierarchy = function (rank, value, idx) {
                    self.hierarchy.push({
                        rank: rank,
                        displayRank: facetNames[rank] || rank,
                        name: value.label,
                        count: value.count,
                        levelClass: 'level' + idx});
                };

                // sets a css class for the current rank based on the number of ranks above it
                // - used for the level of indentation for example
                this.levelClassForCurrentRank = ko.computed(function () {
                    return 'level' + (self.hierarchy().length);
                });

                // loads the taxonomy object's values when a new search has been done
                this.load = function (facets) {
                    self.hierarchy.removeAll();
                    if (self.currentRank() === '') {
                        // no ranks have been determined yet so this must be the initial query
                        // determine a starting rank based on the data
                        var done = false;
                        $.each(ranks, function (idx, rank) {
                            var result = self.getFacetsForRank(facets, rank);
                            if (result !== undefined && !done && result.length > 0) {
                                if (result.length > 1) {
                                    self.currentRank(ranks[idx]);
                                    done = true;
                                }
                            }
                        });
                        // catch-all for if all ranks have 1 value
                        if (self.currentRank() === '') {
                            self.currentRank(ranks[ranks.length - 1]);
                        }
                    } else {
                        // set current rank to the next rank to display
                        // Note this is not necessarily the child rank - it can be any rank
                        self.currentRank(self.nextRank);
                    }
                    // add ranks above the current to the hierarchy
                    $.each(ranks.slice(0, $.inArray(self.currentRank(),ranks)), function (idx, rank) {
                        var result = self.getFacetsForRank(facets, rank);
                        self.addToHierarchy(rank, result[0], idx);
                    });
                    // add the current rank values
                    self.valuesForCurrentRank(self.getFacetsForRank(facets, self.currentRank()));
                };

                // returns the next lower rank unless it is already at the lowest rank
                this.childRank = function (rank) {
                    var idx = $.inArray(rank, ranks);
                    return idx < ranks.length-1 ? ranks[idx + 1] : rank;
                };

                // removes filters for the specified rank and all below it
                this.clearRankAndBelow = function (rank) {
                    var idx = $.inArray(rank, ranks),
                            ranksToClear = ranks.slice(idx);
                    $.each(ranksToClear, function (idx, item) {
                        parent.removeFilter(item);
                    });
                };

                // sets a new target rank and triggers a new search by removing filters for the target
                //  rank and any below it
                this.setRank = function () {
                    self.nextRank = this.rank;
                    self.clearRankAndBelow(this.rank);
                };

                // handles the setRank functionality for when the lowest rank link is clicked
                this.setLowestRank = function () {
                    self.nextRank = ranks[ranks.length-1];
                    self.clearRankAndBelow(self.nextRank);
                    self.selectedASingleValueAtLowestRank(false);
                };

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
                }
            }

            function ViewModel() {
                var self = this;
                // the uid of the entity to browse
                this.entityUid = ko.observable(entityUid);
                // the display name for the entity - this is updated asynchronously by a collectory look-up
                this.entityName = ko.observable(self.entityUid()); // display the uid while the name is being retrieved
                // look up the entity name
                $.ajax({url: collectoryServicesURL + 'resolveNames/' + self.entityUid(), dataType: 'jsonp', timeout: 20000})
                .done(function (data) {
                    var name = data[self.entityUid()];
                    if (name) {
                        self.entityName(name);
                    }
                });
                // the images
                this.imagesList = ko.observableArray([]);
                // the number of images returned from the search
                this.totalRecords = ko.observable();
                // the facet data returned from the search
                this.facets = ko.observableArray([]);
                // the constructed search query - a change to this triggers a new search
                this.query = new Query();
                // the widget for traversing the taxonomy ranks in the returned data
                this.taxonomy = ko.observable(new Taxonomy(this));

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

                // true while a search is in progress
                this.isLoading = ko.observable(false);

                // contains error messages that may result from searches
                this.loadStatus = ko.observable('');

                // performs the images search and handles results
                this.loadImages = function () {
                    var imagesQueryUrl = "?" + mainQuery + rankFacets + "&q=" +
                                    buildQueryString(self.entityUid()),
                            url = urlConcat(biocacheServicesUrl, wsBase + imagesQueryUrl + self.query.queryString()),
                            request;
                    //console.log('Query is ' + url);
                    self.isLoading(true);
                    request = $.ajax({url: url, dataType: 'jsonp', timeout: 20000});
                    request.fail(function (jqXHR, textStatus) {
                        self.loadStatus(textStatus);
                        self.imagesList([]);
                    });
                    request.always(function () {
                        self.isLoading(false);
                    });
                    request.done(function (data) {
                        // check for errors
                        if (data.length == 0 || data.totalRecords == undefined || data.totalRecords == 0) {
                            self.loadStatus('no results');
                            self.imagesList([]);
                        } else if (data.totalRecords > 0) {
                            self.totalRecords(data.totalRecords);
                            self.loadStatus('done');
                            // load images
                            self.imagesList($.map(data.occurrences, function (item) {
                                return new Image(item);
                            }));
                            // load facets
                            self.facets($.grep($.map(data.facetResults, function (item) {
                                return new Facet(item, self);
                            }), function (item) {
                                return $.inArray(item.fieldName, facetsToShow) > -1;
                            }));
                            // load taxonomy
                            self.taxonomy().load(data.facetResults);
                        }
                    });
                }
            }

            var viewModel = new ViewModel();
            ko.applyBindings(viewModel);

            // set initial state based on location hashes
            //  - note that these do not trigger searches as auto-query is initially disabled
            var states = $.bbq.getState();
            $.each(states, function (key, value) {
                viewModel.taxonomy().setState(key, value); // only sets state for known ranks
                // only set state for known general facets
                if ($.inArray(key, facetsToShow) !== -1) {
                    viewModel.query.addFilter(key, value);
                }
            });

            // turn auto-query on so that any filter changes trigger a new search
            viewModel.query.autoOn();

            // do initial search
            viewModel.loadImages();

        });
    </r:script>
</body>
</html>