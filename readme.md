# Immune Traveler

A work in progress to scrape CDC data and make it easy to identify needed vaccinations for multiple target countries (rather than having to do so by hand.)  This is a side project built as a means of playing with angular and working w/ newer, official elasticsearch-ruby gem, rather than old tire gem.


## Notes

###travel notices
HTML: http://wwwnc.cdc.gov/travel/notices
RSS: http://wwwnc.cdc.gov/travel/rss/notices.xml

###page list of urls
http://wwwnc.cdc.gov/travel/destinations/list
select id="traveler_destination"

###example page
http://wwwnc.cdc.gov/travel/destinations/traveler/children.chronic.cruise_ship.extended_student.immune_compromised.pregnant.mission_disaster.vfr/thailand
each page has: <li class="last-updated">Page last updated: <span>August 16, 2013</span></li>
List of latest updates: http://wwwnc.cdc.gov/travel/yellowbook/2014/updates/rss

Cool map: http://jvectormap.com/documentation/javascript-api/