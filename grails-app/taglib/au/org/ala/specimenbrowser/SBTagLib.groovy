package au.org.ala.specimenbrowser

import groovy.xml.MarkupBuilder

class SBTagLib {

    static namespace = 'sb'

    /**
     * @attr active
     * @attr title
     * @attr href
     */
    def breadcrumbItem = { attrs, body ->
        def active = attrs.active
        if (!active) {
            active = attrs.title
        }
        def current = pageProperty(name:'page.pageTitle')?.toString()

        def mb = new MarkupBuilder(out)
        mb.li(class: active == current ? 'active' : '') {
            a(href:attrs.href) {
                i(class:'icon-chevron-right') { mkp.yieldUnescaped('&nbsp;')}
                mkp.yield(attrs.title)
            }
        }
    }

    def navSeparator = { attrs, body ->
        out << "&nbsp;&#187;&nbsp;"
    }
}
