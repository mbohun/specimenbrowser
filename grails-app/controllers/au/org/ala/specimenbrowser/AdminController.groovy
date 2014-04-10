package au.org.ala.specimenbrowser

import grails.util.Environment
import org.springframework.core.io.support.PathMatchingResourcePatternResolver

class AdminController {

    def index() {}
    def tools() {}
    def counts() {}

    def settings() {
        def settings = []
        def config = grailsApplication.config.flatten()
        ['ala.baseURL','grails.serverURL','grails.config.locations','collectory.baseURL',
         'headerAndFooter.baseURL','biocacheServicesUrl','collectory.servicesURL','ala.image.infoURL'
        ].each {
            settings << [key: it, value: config[it], comment: '']
        }
        [settings: settings]
    }

    def reloadConfig = {
        // clear any cached external config
        //cacheService.clear()

        // reload system config
        def resolver = new PathMatchingResourcePatternResolver()
        def resource = resolver.getResource(grailsApplication.config.reloadable.cfgs[0])
        def stream = null

        try {
            stream = resource.getInputStream()
            ConfigSlurper configSlurper = new ConfigSlurper(Environment.current.name)
            if(resource.filename.endsWith('.groovy')) {
                def newConfig = configSlurper.parse(stream.text)
                grailsApplication.getConfig().merge(newConfig)
            }
            else if(resource.filename.endsWith('.properties')) {
                def props = new Properties()
                props.load(stream)
                def newConfig = configSlurper.parse(props)
                grailsApplication.getConfig().merge(newConfig)
            }
            flash.message = "Config reloaded from ${grailsApplication.config.reloadable.cfgs[0]}."
            render 'done'
        }
        catch (FileNotFoundException fnf) {
            println "No external config to reload configuration. Looking for ${grailsApplication.config.reloadable.cfgs[0]}"
            render "No external config to reload configuration. Looking for ${grailsApplication.config.reloadable.cfgs[0]}"
        }
        catch (Exception gre) {
            println "Unable to reload configuration. Please correct problem and try again: " + gre.getMessage()
            render "Unable to reload configuration - " + gre.getMessage()
        }
        finally {
            stream?.close()
        }
    }

}
