# Timetables the zone check could not get

`pdf_validation.md` checks the 60 zones of `lsoa_disagreement.md` against
operators' published timetables. This is the list of documents it needed and
could not collect automatically, with links, so they can be fetched by hand
and dropped into `data/example_timetables/`. Each entry is a route that
carries 1,000 trip-runs or more of a zone's TNDS-versus-BODS GTFS difference
and has no checked document yet. Routes already checked in another zone of the
same area are left out.

**What to fetch.** The edition in force for the counting window, **27 July –
23 August 2026**, if the operator still has it; otherwise the current one
(say which in the file name). A whole week — Monday–Friday (or Monday–Thursday
and Friday), Saturday and Sunday — and, where the operator prints schooldays and
school holidays separately, the **school-holiday** version, since the window
falls in the summer holidays. For TfL routes, the running schedules in the
same form as the `Schedule_<route>-<day>.pdf` files already in the folder.

Service pages are on bustimes.org, which names the operator and links to its
site; the operator links are the ones bustimes gives. Where a route could not
be matched to a service at the zone's stops, the link is a bustimes search.

## 1. TfL running schedules (24 routes)

TfL's website and its open-data bucket refuse requests from the environment
the collection ran in. The schedules for 20, 167, 215, 216, 235, 275, 406
and 462 were already in the folder and are checked; these are the rest. They
cover Wandsworth (Mapleton Road), Southall, Harrow, the City (Barbican),
Hackney (Moulins Road), Kingston, Epsom, Sunbury and Loughton.

TfL publishes them as bus route schedules
(<https://tfl.gov.uk/corporate/publications-and-reports/bus-schedules>, from a
web search; not opened from here). Needed day types: `MF` (or `MFHo` where
there is a schools/holidays split), `Sa`, `Su`, plus `Fr` where it exists.

|Route|Operator|Where (zones)|Largest zone difference|Service page|TfL timetable|
|:--|:--|:--|--:|:--|:--|
|290|First Bus London|Sunbury Cross (E01030751)|6,528|[bustimes](https://bustimes.org/services/290-staines-ashford-ashford-common-sunbury-hanwo-2)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/290/)|
|207|Transport UK|Southall Broadway (E01001361)|5,956|[bustimes](https://bustimes.org/services/n207-uxbridge-hayes-ealing-shepherds-bush-holbor-3)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/207/)|
|427|Transport UK|Southall Broadway (E01001361)|5,924|[bustimes](https://bustimes.org/services/427-uxbridge-hillingdon-hill-hayes-end-hayes-grape)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/427/)|
|418|First Bus London|Cromwell Road Bus Station; High Street (E01002968, E01034290)|5,840|[bustimes](https://bustimes.org/services/418-kingston-epsom-school-extra)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/418/)|
|K3|TfL|Cromwell Road Bus Station (E01002968)|5,156|[bustimes](https://bustimes.org/search?q=K3)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/K3/)|
|293|First Bus London|High Street (E01034290)|4,440|[bustimes](https://bustimes.org/services/293-morden-hillcross-avenue-lower-morden-north-c-2)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/293/)|
|195|Transport UK|Southall Broadway (E01001361)|4,228|[bustimes](https://bustimes.org/services/195-charville-lane-estate-church-road-hayes-bulls)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/195/)|
|87|TfL|Mapleton Road (SW18) (E01004513)|3,624|[bustimes](https://bustimes.org/search?q=87)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/87/)|
|140|Metroline Travel|Alexandra Avenue (HA2) (E01002218)|3,488|[bustimes](https://bustimes.org/services/140-hayes-harlington-station-yeading-northolt-sout)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/140/)|
|39|TfL|Mapleton Road (SW18) (E01004513)|3,280|[bustimes](https://bustimes.org/search?q=39)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/39/)|
|76|Arriva London|Barbican Underground Station (E01000001)|3,256|[bustimes](https://bustimes.org/services/76-tottenham-hale-stamford-hill-stoke-newington-2)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/76/)|
|E5|Transport UK|Southall Broadway (E01001361)|3,200|[bustimes](https://bustimes.org/services/e5-southall-toplocks-estate-southall-green-station)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/E5/)|
|170|TfL|Mapleton Road (SW18) (E01004513)|3,152|[bustimes](https://bustimes.org/search?q=170)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/170/)|
|37|TfL|Mapleton Road (SW18) (E01004513)|3,036|[bustimes](https://bustimes.org/search?q=37)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/37/)|
|425|Stagecoach London|Moulins Road (E01001843)|2,980|[bustimes](https://bustimes.org/services/425-ilford-manor-park-forest-gate-stratford-bow-mi)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/425/)|
|156|TfL|Mapleton Road (SW18) (E01004513)|2,828|[bustimes](https://bustimes.org/search?q=156)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/156/)|
|277|Stagecoach London|Moulins Road (E01001843)|2,812|[bustimes](https://bustimes.org/services/277-dalston-junction-hacikney-central-victoria-par)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/277/)|
|411|First Bus London|Cromwell Road Bus Station (E01002968)|2,692|[bustimes](https://bustimes.org/services/411-kingston-hampton-court-west-molesey)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/411/)|
|S2|London General|High Street (E01034290)|2,660|[bustimes](https://bustimes.org/services/s2-epsom-clock-tower-st-helier)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/S2/)|
|100|London Central|Barbican Underground Station (E01000001)|2,412|[bustimes](https://bustimes.org/services/100-st-pauls-station-london-wall-aldgate-tower-gat)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/100/)|
|337|TfL|Mapleton Road (SW18) (E01004513)|2,396|[bustimes](https://bustimes.org/search?q=337)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/337/)|
|487|Metroline Travel|Alexandra Avenue (HA2) (E01002218)|2,152|[bustimes](https://bustimes.org/services/487-south-harrow-park-royal-willesden-junction)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/487/)|
|397|Stagecoach London|Loughton Station (E01021782)|1,640|[bustimes](https://bustimes.org/services/397-crooked-billet-sainsburys-endlebury-road-ching)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/397/)|
|395|First Bus London|Alexandra Avenue (HA2) (E01002218)|1,424|[bustimes](https://bustimes.org/services/395-harrow-northolt-greenford)|[tfl.gov.uk](https://tfl.gov.uk/bus/timetable/395/)|

## 2. Operators behind a browser check (11 routes)

Stagecoach, Arriva and Transdev serve their sites through a challenge page
that needs a host this environment's network policy blocks, so nothing could
be fetched from them. These cover Chester, Portsmouth's Stagecoach routes,
Preston and Leven.

|Route|Operator|Where (zones)|Largest zone difference|Service page|Operator site|
|:--|:--|:--|--:|:--|:--|
|23|Stagecoach South|City Shops South; The Hard Interchange (E01017032, E01017034)|3,982|[bustimes](https://bustimes.org/services/23-leigh-park-southsea)|[Stagecoach South](http://www.stagecoachbus.com/regional-help-and-contact/south)|
|1|Arriva Wales|Chester Bus Interchange; Grosvenor Street; Railway Station (E01032930, E01035376, E01035378)|3,008|[bustimes](https://bustimes.org/services/1-wrexham-chester-4)|[Arriva Wales](https://www.arrivabus.co.uk/locations/wales)|
|10|Arriva Wales|Chester Bus Interchange (E01035376)|2,652|[bustimes](https://bustimes.org/services/10-chester-connahs-quay)|[Arriva Wales](https://www.arrivabus.co.uk/locations/wales)|
|21|Stagecoach South|City Shops South; The Hard Interchange (E01017032, E01017034)|1,670|[bustimes](https://bustimes.org/services/21-havant-portsmouth-2)|[Stagecoach South](http://www.stagecoachbus.com/regional-help-and-contact/south)|
|X2|Stagecoach Cumbria and Lancashire|Bus Station (E01033223)|1,612|[bustimes](https://bustimes.org/services/x2-preston-southport-4)|[Stagecoach Cumbria and Lancashire](http://www.stagecoachbus.com/regional-help-and-contact/cumbria-and-north-lancashire)|
|X61|Stagecoach East Scotland|Co-op Supermarket (S01016759)|1,460|[bustimes](https://bustimes.org/search?q=X61)|[Stagecoach East Scotland](https://www.stagecoachbus.com)|
|X58|Stagecoach East Scotland|Co-op Supermarket (S01016759)|1,428|[bustimes](https://bustimes.org/search?q=X58)|[Stagecoach East Scotland](https://www.stagecoachbus.com)|
|11|Arriva Wales|Chester Bus Interchange; Grosvenor Street (E01035376, E01035378)|1,400|[bustimes](https://bustimes.org/services/11-rhyl-chester)|[Arriva Wales](https://www.arrivabus.co.uk/locations/wales)|
|20|Stagecoach South|City Shops South; The Hard Interchange (E01017032, E01017034)|1,256|[bustimes](https://bustimes.org/services/20-havant-portsmouth)|[Stagecoach South](http://www.stagecoachbus.com/regional-help-and-contact/south)|
|152|The Blackburn Bus Company|Bus Station (E01033223)|1,167|[bustimes](https://bustimes.org/services/152-preston-feniscowles-blackburn-clayton-le-moors)|[The Blackburn Bus Company](https://www.transdevbus.co.uk/the-blackburn-bus-company/)|
|2|Stagecoach Cumbria and Lancashire|Bus Station (E01033223)|1,032|[bustimes](https://bustimes.org/services/2-preston-bus-stn-stand-22-lord-st-duke-st-2)|[Stagecoach Cumbria and Lancashire](http://www.stagecoachbus.com/regional-help-and-contact/cumbria-and-north-lancashire)|

## 3. National Express West Midlands routes not collected (16 routes)

These were not collected. The 16 (Birmingham – Hamstead) page has no
timetable widget, and the 530 download failed; the rest were not on the NXWM
service list that was crawled. The PDFs come from each route's page on
<https://nxbus.co.uk/west-midlands/services-timetables>, with the "Download
timetable PDF" button in the embedded timetable. They are the current edition
only. The summer edition (from 19 July 2026), which is what the window needs,
can't be got from the site any more: if you have copies of the summer
editions, those would be better still.

|Route|Operator|Where (zones)|Largest zone difference|Service page|
|:--|:--|:--|--:|:--|
|16|National Express West Midlands|Albert Street; Church Centre; Markets (E01033615, E01033617, E01033620)|5,280|[bustimes](https://bustimes.org/services/16-birmingham-hamstead-via-hockley)|
|29|National Express West Midlands|Walsall Bus Station (E01010368)|4,004|[bustimes](https://bustimes.org/services/29-walsall-bloxwich-via-blakenall)|
|2|National Express West Midlands|Wolverhampton Bus Station (E01034313)|2,680|[bustimes](https://bustimes.org/services/2-bushbury-warstones-via-wolverhampton)|
|4|National Express West Midlands|New Street; West Bromwich Bus Station (E01010102, E01010106)|2,640|[bustimes](https://bustimes.org/services/4-walsall-blackheath-via-west-bromwich)|
|5|National Express West Midlands|New Street; West Bromwich Bus Station (E01010102, E01010106)|2,280|[bustimes](https://bustimes.org/services/5-west-bromwich-sutton-coldfield-via-new-oscott)|
|10|National Express West Midlands|Walsall Bus Station (E01010368)|2,260|[bustimes](https://bustimes.org/services/10-walsall-rushall-shelfield-brownhills)|
|80|National Express West Midlands|Markets; West Bromwich Bus Station (E01010102, E01033615)|2,200|[bustimes](https://bustimes.org/services/80-birmingham-west-bromwich-via-smethwick)|
|6|National Express West Midlands|Wolverhampton Bus Station (E01034313)|1,880|[bustimes](https://bustimes.org/services/6-wolverhampton-wobaston)|
|47|National Express West Midlands|New Street; West Bromwich Bus Station (E01010102, E01010106)|1,876|[bustimes](https://bustimes.org/services/47-west-bromwich-wednesbury-via-hateley-heath-2)|
|530|National Express West Midlands|Wolverhampton Bus Station (E01034313)|1,740|[bustimes](https://bustimes.org/services/530-wolverhampton-rough-hills-bilston-rocket-pool)|
|4M|National Express West Midlands|New Street; West Bromwich Bus Station (E01010102, E01010106)|1,540|[bustimes](https://bustimes.org/services/4m-walsall-merry-hill-via-west-bromwich)|
|X4|National Express West Midlands|Albert Street; Church Centre (E01033617, E01033620)|1,360|[bustimes](https://bustimes.org/services/x4-birmingham-minworth-via-sutton-coldfield)|
|907|National Express West Midlands|Albert Street (E01033617)|1,200|[bustimes](https://bustimes.org/services/907-birmingham-sutton-coldfield-via-perry-barr)|
|X14|National Express West Midlands|Albert Street; Church Centre (E01033617, E01033620)|1,080|[bustimes](https://bustimes.org/services/x14-birmingham-sutton-coldfield-via-walmley)|
|67|National Express West Midlands|Albert Street; Moor St Selfridges (E01033561, E01033617)|1,040|[bustimes](https://bustimes.org/services/67-birmingham-castle-vale-via-tyburn-rd)|
|65|National Express West Midlands|Albert Street; Moor St Selfridges (E01033561, E01033617)|1,020|[bustimes](https://bustimes.org/services/65-birmingham-perry-common-via-short-heath)|

## 4. trentbarton, Derby – Burton (3 routes)

trentbarton's PDFs have no text layer. The Word extracts already in the folder
(`Trentbarton X38.docx` and others) are the format that reads. For
villager, swift and the X38, a Word or text extract of the timetable is what
is needed.

|Route|Operator|Where (zones)|Largest zone difference|Service page|
|:--|:--|:--|--:|:--|
|X38|trentbarton|Battista Road; Boundary Road; Bus Station; New Street (E01013453, E01029428, E01032896, E01034256)|4,092|[bustimes](https://bustimes.org/services/x38-derby-burton)|
|vil|trentbarton (villager)|Battista Road; Boundary Road; Bus Station; New Street (E01013453, E01029428, E01032896, E01034256)|1,648|[bustimes](https://bustimes.org/search?q=vil)|
|SWI|trentbarton (swift)|Bus Station (E01034256)|1,536|[bustimes](https://bustimes.org/search?q=SWI)|

## 5. Other operators (8 routes)

Diamond Bus's site is reachable. The PDFs for its **40, 42 and 9** were
downloaded while this list was compiled and are now in the folder
(`diamond_40-wednesburytimetable-310526.pdf`, `diamond_h42-timetable-310825.pdf`,
`diamond_9-airway_timetable_091125.pdf`), but **they have not been read yet**.
The 31 and 32 pages
(<https://www.diamondbuses.com/bus-services/wm/wm31-walsall/>,
<https://www.diamondbuses.com/bus-services/wm/wm32-walsall/>) offer only a
print view, not a PDF. Vision Bus's 45 has an
on-screen timetable and no PDF that could be found
(<https://www.visionbus.co.uk/route?service=45>). Reading Buses' Thames Valley
Park (TVP) and 15a are not in the operator's PDF archive at all.

|Route|Operator|Where (zones)|Largest zone difference|Service page|
|:--|:--|:--|--:|:--|
|40|Diamond Bus|New Street; West Bromwich Bus Station (E01010102, E01010106)|4,440|[bustimes](https://bustimes.org/services/40-west-bromwich-wednesbury-2)|
|31|Diamond Bus|Walsall Bus Station (E01010368)|2,572|[bustimes](https://bustimes.org/services/31-walsall-mossley)|
|42|Diamond Bus|West Bromwich Bus Station (E01010102)|2,168|[bustimes](https://bustimes.org/services/42-tipton-west-bromwich)|
|9|Diamond Bus East Midlands|New Street (E01032896)|1,504|[bustimes](https://bustimes.org/services/9-east-mids-airport-burton)|
|45|Vision Bus|Bus Station (E01033223)|1,472|[bustimes](https://bustimes.org/services/45-preston-blackburn-2)|
|TVP|Reading Buses (Thames Valley Park)|Friar Street (E01033415)|1,440|[bustimes](https://bustimes.org/search?q=TVP)|
|32|Diamond Bus|Walsall Bus Station (E01010368)|1,264|[bustimes](https://bustimes.org/services/32-walsall-lower-farm)|
|15a|Reading Buses|Friar Street (E01033415)|1,089|[bustimes](https://bustimes.org/search?q=15a)|

## 6. Routes whose operator could not be identified (9 routes)

No service with this number was found at the zone's stops on bustimes. That
usually means a route that has since been renumbered or withdrawn, or a
number the feeds use differently from the operator.

|Route|Operator|Where (zones)|Largest zone difference|Service page|
|:--|:--|:--|--:|:--|
|1|unknown|Evolve Campus; Wolverhampton Bus Station (E01009757, E01034313)|3,324|[bustimes](https://bustimes.org/search?q=1)|
|7|unknown|Church Centre (E01033620)|2,680|[bustimes](https://bustimes.org/search?q=7)|
|702|unknown (Chelmsford)|Cathedral; Parkway (E01033140, E01034092)|2,630|[bustimes](https://bustimes.org/search?q=702)|
|6|unknown|Evolve Campus (E01009757)|2,388|[bustimes](https://bustimes.org/search?q=6)|
|2|unknown (Derby)|Bus Station (E01034256)|1,696|[bustimes](https://bustimes.org/search?q=2)|
|8|unknown (Burton)|New Street (E01032896)|1,276|[bustimes](https://bustimes.org/search?q=8)|
|4|unknown (Chester)|Chester Bus Interchange; Grosvenor Street; Railway Station (E01032930, E01035376, E01035378)|1,152|[bustimes](https://bustimes.org/search?q=4)|
|3|unknown|Wolverhampton Bus Station (E01034313)|1,080|[bustimes](https://bustimes.org/search?q=3)|
|47|unknown (Chelmsford)|Cathedral (E01034092)|1,044|[bustimes](https://bustimes.org/search?q=47)|

## 7. Earlier editions that would firm up existing checks

Not missing, but the checks they support would be stronger with them.
National Express West Midlands and First (Essex, Portsmouth, Wessex) publish
only the current timetable, so most of their checks use editions from 30
August – 27 September 2026, after the window. The summer editions would
replace them:

* NXWM summer timetables "from 19th July 2026" for every route in
  `data/zone_pdf_validation.csv` marked `later edition`;
* First Essex (Chelmsford C1–C10, X10, X30, 170, 333, 336, 351, 700), First
  Portsmouth (1, 2, 3, 7, 8, X3) and First Wessex (Weymouth 1, 2, 4, 8, 10)
  editions valid on 27 July 2026. The current ones say "Valid from 31/08/2026"
  or later.

The Wayback Machine (`web.archive.org`) may hold them, but it is also blocked
from the collection environment.
