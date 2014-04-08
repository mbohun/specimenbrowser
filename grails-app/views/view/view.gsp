<%@ page contentType="text/html;charset=UTF-8" %>
<html>
<head>
    <meta name="layout" content="main"/>
    <title>Specimen image viewer prototype</title>
    <r:require modules="leaflet,knockout"/>
    <r:script disposition="head">
        var biocacheServicesUrl = "${grailsApplication.config.biocacheServicesUrl}",
            biocacheWebappUrl = "${grailsApplication.config.biocache.baseURL}",
            entityUid = "${uid}";
    </r:script>
</head>

<body>
    <div id="content">
        <section class="clearfix">
            <h2 class="pull-left">
                <span style="font-style: italic;margin-right: 10px;">${title}</span>
                <g:if test="${common}">
                    - <span style="margin-left: 10px;">${common}</span>
                </g:if>
                <span style="margin-left: 20px;" class="badge badge-info">${typeStatus}</span>
            </h2>
            <a class="pull-right btn btn-small btn-info" style="margin-top: 15px;" href="${grailsApplication.config.biocache.baseURL + 'occurrences/' + recordId}">Show record</a>
        </section>
        <div id="imageViewer"></div>
    </div>
    <r:script>
        $(document).ready(function () {

            var maxZoom, imageHeight, imageWidth, imageScaleFactor, centerx, centery, viewer, urlMask, zoomLevels;
            zoomLevels = ${imageMetadata.tileZoomLevels};
            maxZoom = zoomLevels - 1;
            imageHeight = ${imageMetadata.height};
            imageWidth = ${imageMetadata.width};
            imageScaleFactor =  Math.pow(2, zoomLevels - 1);
            centerx = (imageWidth / 2) / imageScaleFactor;
            centery = (imageHeight / 2) / imageScaleFactor;
            console.log("zoomLevels=" + zoomLevels + " width=" + imageWidth + " height=" + imageHeight);
            console.log("maxZoom=" + maxZoom + " centerx=" + centerx + " centery=" + centery);
            console.log("urlPattern=${imageMetadata.pattern}");

            viewer = L.map('imageViewer', {
                minZoom: 2,
                maxZoom: maxZoom,
                zoom: 2,
                center:new L.LatLng(centery, centerx),
                crs: L.CRS.Simple
            });

            urlMask = "${imageMetadata.pattern}";
            L.tileLayer(urlMask, {
                attribution: '',
                maxNativeZoom: zoomLevels,
                continuousWorld: true,
                tms: true,
                noWrap: true
            }).addTo(viewer);
        });

    </r:script>
</body>
</html>