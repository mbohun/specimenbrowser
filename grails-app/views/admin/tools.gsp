<%@ page import="org.apache.commons.lang.StringEscapeUtils" %>
<!doctype html>
<html>
    <head>
        <meta name="layout" content="adminLayout"/>
        <title>Tools - Admin - Specimen image browser - Atlas of Living Australia</title>
    </head>

    <body>
        <script type="text/javascript">

            $(document).ready(function() {

                $("#btnReloadConfig").click(function(e) {
                    e.preventDefault();
                    $.ajax("${createLink(controller: 'admin', action:'reloadConfig')}").done(function(result) {
                        document.location.reload();
                    });
                });

                $("#btnClearMetadataCache").click(function(e) {
                    e.preventDefault();
                    $.ajax("${createLink(controller: 'admin', action:'clearMetadataCache')}").done(function(result) {
                        document.location.reload();
                    }).fail(function (result) {
                        alert(result);
                    });
                });

                $("#btnReloadDB").click(function(e) {
                    e.preventDefault();
                    $.ajax("${createLink(controller: 'admin', action:'load', params: [drop:true])}").done(function(result) {
                        document.location.reload();
                    }).fail(function (result) {
                        alert(result);
                    });
                });

                $("#btnDumpDB").click(function(e) {
                    e.preventDefault();
                    $.ajax("${createLink(controller: 'admin', action:'dump')}").done(function(result) {
                        document.location.reload();
                    }).fail(function (result) {
                        alert(result);
                    });
                });

                $("#btnReIndexAll").click(function(e) {
                    e.preventDefault();
                    $.ajax("${createLink(controller: 'search', action:'indexAll')}").done(function(result) {
                        document.location.reload();
                    }).fail(function (result) {
                        alert(result);
                    });
                });

            });
        </script>
        <content tag="pageTitle">Tools</content>
        <table class="table table-bordered table-striped">
            <thead>
                <tr>
                    <th>Tool</th>
                    <th>Description</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>
                        <button id="btnReloadConfig" class="btn btn-small btn-info" title="Reloads external config">Reload&nbsp;External&nbsp;Config</button>
                    </td>
                    <td>
                        Reads any defined config files and merges new config with old. Usually used after a change is
                        made to external config files. Note that this cannot remove a config item as the result is a
                        union of the old and new config.
                    </td>
                </tr>
            </tbody>
        </table>
    </body>
</html>