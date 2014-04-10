<%@ page contentType="text/html;charset=UTF-8" %>
<html>
<head>
    <meta name="layout" content="main"/>
    <title>Specimen image viewer prototype</title>
    <r:require module="leaflet"/>
    <r:script disposition="head">
        var imageInfoUrl = "${grailsApplication.config.ala.image.infoURL}",
            biocacheServicesUrl = "${grailsApplication.config.biocacheServicesUrl}",
            biocacheWebappUrl = "${grailsApplication.config.biocache.baseURL}",
            entityUid = "${uid}";
    </r:script>
</head>

<body>
    <div id="content">
        <section class="clearfix">
            <h2 class="pull-left">
                <g:if test="${title}">
                    <span style="font-style: italic;margin-right: 10px;">${title}</span>
                </g:if>
                <g:if test="${common}">
                    - <span style="margin-left: 10px;">${common}</span>
                </g:if>
            </h2>
            <g:if test="${recordId}">
                <a class="pull-right btn btn-small btn-info" style="margin-top: 15px;" href="${grailsApplication.config.biocache.baseURL + 'occurrences/' + recordId}">Show record</a>
            </g:if>
        </section>
        <div id="imageViewer"></div>
    </div>
    <r:script>
        var imageMetadataLookup = new AjaxLauncher(imageInfoUrl + "${id}");

        $(document).ready(function () {

            var maxZoom, imageHeight, imageWidth, imageScaleFactor, centerx, centery, viewer, urlMask, zoomLevels;
            // make a call to get the image metadata
	        imageMetadataLookup.subscribe(function (request) {
                request.done(function (imageMetadata) {
                    zoomLevels = imageMetadata.tileZoomLevels;
                    maxZoom = zoomLevels - 1;
                    imageHeight = imageMetadata.height;
                    imageWidth = imageMetadata.width;
                    imageScaleFactor =  Math.pow(2, zoomLevels - 1);
                    centerx = (imageWidth / 2) / imageScaleFactor;
                    centery = (imageHeight / 2) / imageScaleFactor;
                    //console.log("zoomLevels=" + zoomLevels + " width=" + imageWidth + " height=" + imageHeight);
                    //console.log("maxZoom=" + maxZoom + " centerx=" + centerx + " centery=" + centery);
                    //console.log("urlPattern=imageMetadata.tileUrlPattern");

                    viewer = L.map('imageViewer', {
                        fullscreenControl: true,
                        minZoom: 2,
                        maxZoom: maxZoom,
                        zoom: imageWidth < 2000 ? 3 : 2,
                        center:new L.LatLng(centery, centerx),
                        crs: L.CRS.Simple
                    });

                    urlMask = imageMetadata.tileUrlPattern;
                    L.tileLayer(urlMask, {
                        attribution: '',
                        maxNativeZoom: zoomLevels,
                        continuousWorld: true,
                        tms: true,
                        noWrap: true
                    }).addTo(viewer);
                })
            });
            imageMetadataLookup.launch();
        });

    </r:script>
</body>
</html>