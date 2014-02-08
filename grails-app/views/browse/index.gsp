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
                <div data-bind="with:taxonomy">
                    <h3>Taxonomy</h3>
                    <ul data-bind="foreach:hierarchy" style="margin-left:0; margin-bottom:0;">
                        <li><span style="font-weight:bold;" data-bind="text:rank"></span>: <span data-bind="text:name"></span></li>
                    </ul>
                    <span style="font-weight:bold;" data-bind="text:rankLabel"></span>:
                    <ul>
                        <!-- ko foreach:values -->
                        <li><span class="clickable" data-bind="click:$parent.filterSearch,attr:{id:label}"><span data-bind="text:label"></span> (<span data-bind="text:count"></span>)</span></li>
                        <!-- /ko -->
                        <li data-bind="visible:!atTop()"><span class="clickable" data-bind="click:filterSearch"><i class="icon-arrow-up"></i></span></li>
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
                    %{--<div data-bind="text:ko.toJSON(taxonomy().hierarchy,null,2)"></div>--}%
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
            facetsToShow = ["type_status","raw_sex"];

        $(window).load(function () {

            function Facet (data, parent) {
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

            function Image (data) {
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

            function Query () {
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

            function Taxonomy (parent) {
                var self = this,
                    ranks = ['kingdom','phylum','class','order','family','genus','species']; // support division later
                this.highestRankWithMultipleValues = ko.observable('');
                this.originalRank = ko.observable('');
                this.selectedASingleValueAtLowestRank = ko.observable(false);
                this.rankLabel = ko.computed(function () { return facetNames[self.highestRankWithMultipleValues()] || self.highestRankWithMultipleValues() });
                this.values = ko.observableArray();
                this.hierarchy = ko.observableArray();
                this.getRank = function (facets, rank) {
                    var field = $.grep(facets, function (facet, idx) {
                        return facet.fieldName === rank;
                    });
                    return field.length === 0 ? undefined : field[0].fieldResult;
                };
                this.load = function (facets) {
                    var done = false,
                        numberOfRanks = ranks.length;
                    self.hierarchy.removeAll();
                    $.each(ranks, function (idx, rank) {
                        var result = self.getRank(facets, rank);
                        if (result !== undefined && !done && result.length > 0) {
                            if (result.length === 1 && idx !== numberOfRanks-1) {
                                self.hierarchy.push({
                                    rank: facetNames[rank] || rank,
                                    name: result[0].label,
                                    count: result[0].count});
                            } else {
                                self.highestRankWithMultipleValues(rank);
                                self.values(result);
                                self.originalRank(self.originalRank() || self.highestRankWithMultipleValues());
                                done = true;
                            }
                        }
                    });
                    console.log('highest rank with multiple is ' + self.highestRankWithMultipleValues());
                    console.log('parent rank is ' + self.parentRank(self.highestRankWithMultipleValues()));

                };
                this.parentRank = function (rank) {
                    if (rank === '') return 'species';
                    var idx = $.inArray(rank, ranks);
                    return idx > 0 ? ranks[idx - 1] : '';
                };
                this.atTop = ko.computed(function () {
                    return self.highestRankWithMultipleValues() === self.originalRank();
                });  // true if there is a parent rank that has more than 1 value
                this.filterSearch = function () {
                    var rank = self.highestRankWithMultipleValues();
                    if (this === self) {
                        // the all link has been clicked
                        // this gets tricky when we are at the lowest rank level
                        if (self.selectedASingleValueAtLowestRank()) {
                            console.log('remove filter ' + rank);
                            self.selectedASingleValueAtLowestRank(false);
                            parent.removeFilter(rank);
                        } else {
                            console.log('remove filter ' + self.parentRank(rank));
                            parent.removeFilter(self.parentRank(rank));
                        }
                    } else {
                        if (rank === ranks[ranks.length - 1]) { // is the lowest rank
                            self.selectedASingleValueAtLowestRank(true);
                        } else {
                            self.selectedASingleValueAtLowestRank(false);
                        }
                        console.log('selected single ' + self.selectedASingleValueAtLowestRank());
                        console.log('add filter ' + rank);
                        parent.addFilter(rank, this.label);
                    }
                };
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