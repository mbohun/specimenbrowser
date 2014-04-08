<%@ page import="org.apache.commons.lang.StringEscapeUtils" %>
<!doctype html>
<html>
    <head>
        <meta name="layout" content="adminLayout"/>
        <title>Settings - Admin - Specimen image browser - Atlas of Living Australia</title>
        <r:require module="knockout"/>
        <r:script disposition="head">
        var biocacheServicesUrl = "${grailsApplication.config.biocacheServicesUrl}",
            collectoryServicesURL = "${grailsApplication.config.collectory.servicesURL}",
            browseUrl = "${createLink(controller: 'browse')}";
        </r:script>
    </head>

    <body>
        <content tag="pageTitle">Image counts</content>
        <table class="table table-bordered table-striped">
            <thead>
                <tr>
                    <th>Resource UID</th>
                    <th>Resource</th>
                    <th>Number of images</th>
                </tr>
            </thead>
            <tbody data-bind="foreach:resources">
                <tr>
                    <td data-bind="text:uid"></td>
                    <td data-bind="text:name"></td>
                    <td><a data-bind="click:gotoBrowse"><span data-bind="text:count"></span></a></td>
                </tr>
            </tbody>
        </table>
    <script type="text/javascript">

        $(document).ready(function() {

            var Resource = function (uid, count) {
                var self = this;
                this.uid = uid;
                this.count = count;
                this.name = ko.observable('');
                $.ajax(collectoryServicesURL + 'resolveNames/' + this.uid, {
                    dataType: 'jsonp',
                    timeout: 20000
                }).done(function (data) {
                    self.name(data[self.uid]);
                });
                this.gotoBrowse = function () {
                    document.location.href = browseUrl + '/' + self.uid;
                };
            };
            var ViewModel = function () {
                var self = this,
                    url = biocacheServicesUrl +
                            '/occurrences/search.json?q=*:*&fq=multimedia:Image&facets=collection_uid&facets=data_resource_uid&pageSize=0';
                this.resources = ko.observableArray();
                $.ajax(url, {
                    dataType: 'jsonp',
                    timeout: 20000
                }).done(function (data) {
                    $.each(data.facetResults, function (i, facet) {
                        $.each(facet.fieldResult, function (idx, item) {
                            self.resources.push(new Resource(item.label, item.count));
                        });
                    });
                });
            };

            var viewModel = new ViewModel();
            ko.applyBindings(viewModel);
        });

    </script>
    </body>
</html>