package au.org.ala.specimenbrowser

class ViewController {

    def index() {
        render view: 'view', model: [imageId: 'be0947a6-23e5-4c9d-acf3-c2855c9cc3ba']
    }

    def view(String id, String title, String common, String recordId, String typeStatus,
             int tileZoomLevels, int height, int width, String urlPattern) {
        def viewer = [tileZoomLevels: tileZoomLevels, height: height, width: width,
            pattern: urlPattern]
        [imageMetadata: viewer, title: title, common: common, recordId: recordId, typeStatus: typeStatus]
    }
}
