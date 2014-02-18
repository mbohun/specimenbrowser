class UrlMappings {

	static mappings = {

        "/browse/$id?"{
            controller = 'browse'
            action = 'index'
            constraints {
                id(validator: {it == null ||
                        it.startsWith('co') ||
                        it.startsWith('dp') ||
                        it.startsWith('dr') ||
                        it.startsWith('in') ||
                        it.startsWith('drt')})
            }
        }

		"/$controller/$action?/$id?"{
			constraints {
				// apply constraints here
			}
		}

		"/"(controller: 'browse')
		"500"(view:'/error')
	}
}
