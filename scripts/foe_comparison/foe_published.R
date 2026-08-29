# The figures Friends of the Earth actually published, November 2023.
#
# Transcribed from the report page's Flourish tables and from the local
# authority workbook linked beside them:
#   https://policy.friendsoftheearth.uk/insight/how-britains-bus-services-have-drastically-declined
#   https://policy.friendsoftheearth.uk/sites/default/files/documents/2023-11/bustrip-trends-by-authority_0.xlsx
#
# Held here so the comparison report has something fixed to check against and
# does not need the network to knit.

# Table 1: percentage change by region, 2006-08 average to 2023.
# "Weekday 16 hr average" is the report's name for tph_daytime_avg.
foe_table1 <- data.frame(
  region     = c("East Midlands", "Wales", "North East", "Yorkshire and The Humber",
                 "West Midlands", "South West", "North West", "East of England",
                 "South East", "London"),
  daytime    = c(-60, -57, -52, -47, -47, -46, -45, -44, -43,  2),
  morning    = c(-59, -55, -53, -47, -48, -47, -47, -43, -47,  1),
  evening    = c(-59, -53, -48, -49, -39, -35, -33, -44, -37, 16),
  sat_midday = c(-65, -62, -56, -49, -51, -48, -50, -47, -50, -13),
  sun_night  = c(-56, -66, -46, -53, -25,  -1, -38, -43, -23, -2))

# Table 2: the same, 2010 to 2023.
foe_table2 <- data.frame(
  region     = c("Wales", "East Midlands", "North East", "West Midlands",
                 "South West", "Yorkshire and The Humber", "South East",
                 "North West", "East of England", "London"),
  daytime    = c(-56, -55, -50, -47, -47, -44, -42, -39, -33,  3),
  morning    = c(-55, -54, -52, -48, -48, -44, -43, -41, -33,  3),
  evening    = c(-53, -52, -47, -42, -37, -45, -34, -28, -35, 16),
  sat_midday = c(-60, -60, -54, -51, -48, -45, -49, -43, -38, -15),
  sun_night  = c(-67, -48, -43, -22,  -2, -52, -21, -19, -39, -3))

# The region sheet of the local authority workbook, which is what Tables 1 and
# 2 are rounded from. Trips per hour is counted over whole local authority
# areas and then averaged across the authorities in each region weighted by
# population, so the levels are much larger than any per-neighbourhood figure.
foe_region_workbook <- data.frame(
  region = c("North East", "North West", "Yorkshire and The Humber",
             "East Midlands", "West Midlands", "East of England", "London",
             "South East", "South West", "Scotland", "Wales"),
  tph_2006_08 = c(275.91, 194.24, 254.35, 189.90, 170.59, 108.15, 508.79,
                  104.54, 138.42, 242.54, 122.57),
  tph_2010    = c(268.22, 175.44, 240.07, 167.02, 171.65,  91.49, 505.73,
                  101.30, 141.05, 189.54, 120.31),
  tph_2023    = c(133.15, 106.27, 133.87,  75.48,  90.12,  60.94, 519.51,
                   59.08,  75.03,  84.75,  53.21),
  pct_0823 = c(-0.5174, -0.4529, -0.4737, -0.6026, -0.4717, -0.4365, 0.0210,
               -0.4348, -0.4579, -0.6506, -0.5659),
  pct_1023 = c(-0.5036, -0.3943, -0.4423, -0.5481, -0.4750, -0.3339, 0.0272,
               -0.4168, -0.4680, -0.5529, -0.5577))

# Table 3: London, urban and rural levels and change. Trips per hour is the
# population-weighted mean of the zone-level daytime average.
foe_table3 <- data.frame(
  location  = c("London: not near Underground stations",
                "London: near Underground stations",
                "Outside London: rural",
                "Outside London: urban"),
  tph_2006_08 = c(68.8, 127.8,  7.7, 29.5),
  tph_2023    = c(78.5, 120.4,  3.7, 15.5),
  change      = c( 9.7,  -7.4, -4.0, -14.0),
  pct_change  = c(  14,    -6,  -52,  -48))

# Table 4: the twenty local authorities with the largest proportional fall,
# 2006-08 to 2023. Trips per hour here is counted over the whole local
# authority, not per neighbourhood, so the levels are much larger than the
# Table 3 figures and are not directly comparable with them.
foe_table4 <- data.frame(
  la_name = c("Hart", "Fenland", "Broxtowe", "Blaenau Gwent", "West Berkshire",
              "Erewash", "Waverley", "Staffordshire Moorlands", "Ashfield",
              "East Riding of Yorkshire", "Rushmoor", "Rutland", "Melton",
              "Peterborough", "Bolsover", "Stoke-on-Trent", "Monmouthshire",
              "Newcastle-under-Lyme", "Somerset", "Bridgend"),
  tph_2006_08 = c(64, 109, 413, 88, 146, 302, 108, 87, 191, 227,
                  170, 36, 53, 235, 168, 303, 109, 171, 187, 120),
  tph_2023    = c(10, 18, 76, 18, 32, 70, 25, 20, 46, 55,
                  41, 9, 13, 58, 43, 78, 29, 46, 52, 34),
  pct_change  = c(-84.4, -83.8, -81.6, -79.2, -78.3, -76.9, -76.6, -76.5,
                  -76.1, -76.0, -75.8, -75.6, -75.3, -75.3, -74.4, -74.1,
                  -73.2, -73.2, -72.2, -71.8))

# The headline sentences, for checking against directly.
foe_headlines <- list(
  urban_outside_london_pct = -48,
  rural_pct = -52,
  london_pct = 2,
  east_midlands_range = c(sun_night = -56, sat_midday = -65),
  las_outside_london = 317,
  las_beating_london_sunday_night = 59)
