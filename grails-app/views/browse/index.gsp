<%@ page contentType="text/html;charset=UTF-8" %>
<html>
<head>
    <meta name="layout" content="main"/>
    <title>Specimen image browser prototype</title>
    <r:require module="knockout"/>
    <r:script disposition="head">
        biocacheServicesUrl = "${grailsApplication.config.biocacheServicesUrl}";
        biocacheWebappUrl = "${grailsApplication.config.biocache.baseURL}";
    </r:script>
</head>

<body>
    <div id="content">
        <h2>Specimen images from <span data-bind="text:entityUid"></span> <r:img style="margin-left:100px;" data-bind="visible:isLoading" dir="images" file="ajax-loader.gif"/> </h2>
        <div>
            <input class="input-medium" data-bind="value:entityUid" type="text" value="co56"/>
        </div>
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
                facetNames = {type_status: 'Types', raw_sex: 'Sex', family: 'Family', order: 'Order', 'class': 'Class',
                    kingdom: 'Kingdom', phylum: 'Phylum', genus: 'Genus', species: 'Species'},
                rankFacets = "facets=kingdom&facets=phylum&facets=class&facets=order&facets=family&facets=genus&facets=species",
                mainQuery = "&facets=type_status&facets=raw_sex&fq=multimedia%3AImage&pageSize=100",
                facetsToShow = ["type_status", "raw_sex"];

        $(window).load(function () {

            function Facet(data, parent) {
                var self = this;
                this.fieldName = data.fieldName;
                this.fieldLabel = facetNames[data.fieldName] || data.fieldName;
                this.values = ko.observableArray(data.fieldResult);
                this.filterSearch = function () {
                    // we detect if this is triggered from the 'all values' link by checking whether the
                    // context (this) is the Facet object itself
                    if (this === self) {
                        parent.removeFilter(self.fieldName);
                    } else {
                        parent.addFilter(self.fieldName, this.label);
                    }
                    // adding/removing the filter should automatically invoke a new search because of the dependency chain
                };
            }

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

            function Query() {
                var self = this;
                this.filters = ko.observableArray([]);
                this.addFilter = function (name, value) {
                    // just add to list for now - may need to check for dups later
                    self.filters.push({name: name, value: value});
                };
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
                    viewModel.loadImages();
                });
            }

            function Taxonomy(parent) {
                var self = this,
                    ranks = ['kingdom', 'phylum', 'class', 'order', 'family', 'genus', 'species']; // support division later

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

                // sets the level of indentation for the current rank based on the number of ranks above it
                this.levelClassForCurrentRank = ko.computed(function () {
                    return 'level' + (self.hierarchy().length);
                });

                // loads the taxonomy object's values when a new search has been done
                this.load = function (facets) {
                    var numberOfRanks = ranks.length;
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

                // handles selection of a specific rank value - triggers a new search by adding a filter
                this.filterSearch = function () {
                    var rank = self.currentRank();
                    // increment target rank unless we are already at the bottom
                    if (rank === ranks[ranks.length - 1]) { // is the lowest rank
                        self.selectedASingleValueAtLowestRank(true);
                    } else {
                        self.selectedASingleValueAtLowestRank(false);
                        self.nextRank = self.childRank(self.currentRank());
                    }
                    parent.addFilter(rank, this.label);
                }
            }

            function ViewModel() {
                var self = this;
                this.entityUid = ko.observable('co56');
                this.imagesList = ko.observableArray([]);
                this.totalRecords = ko.observable();
                this.facets = ko.observableArray([]);
                this.query = new Query();
                this.taxonomy = ko.observable(new Taxonomy(this));
                this.addFilter = function (facetName, facetValue) {
                    self.query.addFilter(facetName, facetValue);
                };
                this.removeFilter = function (facetName) {
                    self.query.removeFilter(facetName);
                };
                // redo the search when the collection changes
                this.entityUid.subscribe(function () {
                    viewModel.loadImages();
                });
                this.isLoading = ko.observable(false);
                this.loadStatus = ko.observable('');
                this.loadImages = function () {
                    var imagesQueryUrl = "?" + rankFacets + mainQuery + "&q=" +
                                    buildQueryString(self.entityUid()),
                            url = urlConcat(biocacheServicesUrl, wsBase + imagesQueryUrl + self.query.queryString()),
                            request;
                    console.log('Query is ' + url);
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

            viewModel.loadImages();

        });
    </r:script>
</body>
</html>