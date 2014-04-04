package au.org.ala.specimenbrowser

class BrowseController {

    def index(String id) {
        render view:'index', model: [uid: id, maxRowHeight: params.maxRowHeight ?: 200]
    }
}
