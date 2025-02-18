# Title     : Prepare daily planet position CSV data table.
# Objective : Provide planet position data by: zodiac sign, polarity, element, quality,
#             decans, moon mansions, among others.
# Created by: pablocc
# Created on: 26/01/2021

library(data.table)
library(plyr)
library(tidyr)

source("./fileSystemUtilities.R")
source("./planetAspectsDataPrepare.R")

#' Tropical to sideral longitude conversion with 24 degrees (average XXI century) equinox precession.
#' @param lon Tropical longitude.
#' @return Sideral longitude.
tropicalToSideralConversion <- function(lon) {
  diffDegree <- -24
  adjustedLon <- lon + diffDegree
  adjustedLon[adjustedLon < 0] <- adjustedLon[adjustedLon < 0] + 360
  return(adjustedLon)
}

#' Augment planet positions data table with categorical derivatives: polarity, quality, elements and so forth.
#' @param planetLongitudeTableLong Planet longitude positions long data table.
#' @return Daily planets position table augmented with categorical derivatives.
longitudeDerivativesPositionTableAugment <- function(planetLongitudeTableLong) {
  zodSignIdx <- sprintf("Z%02d", seq(1, 12))
  zodiacSignID <- c(
    'ARI',
    'TAU',
    'GEM',
    'CAN',
    'LEO',
    'VIR',
    'LIB',
    'SCO',
    'SAG',
    'CAP',
    'AQU',
    'PIS'
  )

  # Prevent zero division.
  planetLongitudeTableLong[Lon == 0, Lon := 0.1]
  # Categorize longitude in zodiac signs: https://www.astro.com/astrowiki/en/Zodiac_Sign
  planetLongitudeTableLong[, ZodSignN := sprintf("Z%02d", ceiling(Lon / 30))]
  planetLongitudeTableLong[, ZodSignID := mapvalues(ZodSignN, zodSignIdx, zodiacSignID)]

  # Categorize signs in qualities: https://www.astro.com/astrowiki/en/Quality
  elementID <- rep(c('FIR', 'EAR', 'AIR', 'WAT'), 3)
  planetLongitudeTableLong[, ElementID := mapvalues(ZodSignN, zodSignIdx, elementID)]

  # Categorize signs in triplicities: https://www.astro.com/astrowiki/en/QualityID
  qualityID <- rep(c('CAR', 'FIX', 'MUT'), 4)
  planetLongitudeTableLong[, QualityID := mapvalues(ZodSignN, zodSignIdx, qualityID)]

  # Categorize signs in polarities: https://en.wikipedia.org/wiki/Polarity_(astrology)
  polarityID <- rep(c('POS', 'NEG'), 6)
  planetLongitudeTableLong[, PolarityID := mapvalues(ZodSignN, zodSignIdx, polarityID)]

  # Categorize longitude in decans: https://www.astro.com/astrowiki/en/DecanID
  decansLonCut <- seq(0, 360, by = 10)
  zodSignDecanIDGrid <- expand.grid(seq(1, 3), zodiacSignID)
  zodSignDecanID <- paste0(zodSignDecanIDGrid$Var1, zodSignDecanIDGrid$Var2)
  planetLongitudeTableLong[,
    DecanID := cut(Lon, decansLonCut, zodSignDecanID, include.lowest = T)
  ]

  # Categorize longitude in Arab Moon Mansions:
  # https://starsandstones.wordpress.com/mansions-of-the-moon/the-mansions-of-the-moon/
  arabMansionsLonCut <- c(
    0, 12.85, 25.70, 38.56, 51.41, 64.28, 77.28, 90, 102.85, 115.68, 128.56, 141.41, 154.28, 167.13, 180,
    192.85, 205.70, 218.56, 231.41, 244.28, 257.13, 270, 282.85, 295.70, 308.56, 321.41, 334.28, 347.13, 360.99
  )
  arabMansionsID <- paste0('AM', sprintf("%02d", seq(1, 28)))
  planetLongitudeTableLong[,
    ArabMansionID := cut(Lon, arabMansionsLonCut, arabMansionsID, include.lowest = T)
  ]

  # Convert longitude from tropical to sideral zodiac.
  planetLongitudeTableLong[, SidLon := tropicalToSideralConversion(Lon)]
  # Categorize longitude in Vedic Moon Mansions:
  # https://vedicastrology.net.au/blog/vedic-articles/the-lunar-mansions-of-vedic-astrology/
  vedicMansionsLonCut <- seq(0, 360, by = 13.3333333)
  vedicMansionsLonCut[length(vedicMansionsLonCut)] <- 360.99
  vedicMansionsID <- paste0('VM', sprintf("%02d", seq(1, 27)))
  planetLongitudeTableLong[,
    VedicMansionID := cut(SidLon, vedicMansionsLonCut, vedicMansionsID, include.lowest =  T)
  ]
}

#' Augment planets speed data table with categorical derivatives: retrograde, stationary, direct.
#' @param planetSpeedTableLong Planet longitude positions long data table.
#' @return Daily planets speed table augmented with categorical derivatives.
speedDerivativesPositionTableAugment <- function(planetSpeedTableLong) {
  # Determine min speed when planet should be considered stationary based
  # on average boundary inspired by the formula found at
  # https://www.astro.com/astrowiki/en/Stationary_Phase
  planetSpeedBoundary <- planetSpeedTableLong[,
    list(
      Stationary = round(mean(Speed) * 0.2, 2)
    ),
    by = "pID"
  ]

  stationaryBoundary <- matrix(
    planetSpeedBoundary$Stationary,
    nrow = 1,
    ncol = length(planetSpeedBoundary$Stationary),
    byrow = TRUE,
    dimnames = list('speed', planetSpeedBoundary$pID)
  )

  planetSpeedTableLong$SpeedPhaseID <- "DIR"
  planetSpeedTableLong[Speed < 0, SpeedPhaseID := "RET"]
  planetSpeedTableLong[
    Speed >= 0 & Speed <= stationaryBoundary['speed', pID],
    SpeedPhaseID := "STA"
  ]
}

#' Augment planet positions data table with position motion speed.
#' @return Daily planets speed table.
dailyPlanetsSpeedTablePrepare <- function() {
  cat("Preparing daily planets speed table.\n")
  planetPositionsTable <- loadPlanetsPositionTable("daily")
  colNames <- colnames(planetPositionsTable)
  speedColNames <- colNames[grep("^..SP", colNames)]
  planetSpeedTableLong <- melt(
    planetPositionsTable,
    id.var = "Date",
    measure.var = speedColNames
  )

  # Moon Nodes are imaginary points so we assume constant speed.
  planetSpeedTableLong[variable %in% c('NNSP', 'SNSP'), value := 1]
  # Extract planet ID from variable name.
  planetSpeedTableLong[, variable := substr(variable, 1, 2)]
  setnames(planetSpeedTableLong, c('Date', 'pID', 'Speed'))
  speedDerivativesPositionTableAugment(planetSpeedTableLong)
}

#' Prepare daily planets longitude position and categorical derivatives: polarity, quality, element, sign, etc.
dailyPlanetsPositionTablePrepare <- function() {
  cat("Preparing daily planets position table.\n")
  planetPositionsTable <- loadPlanetsPositionTable("daily")
  colNames <- colnames(planetPositionsTable)
  longitudeColNames <- colNames[grep("^..LON", colNames)]
  planetLongitudeTableLong <- melt(
    planetPositionsTable,
    id.var = "Date",
    measure.var = longitudeColNames
  )

  # Extract planet ID from variable name.
  planetLongitudeTableLong[, pID := substr(variable, 1, 2)]
  planetLongitudeTableLong[, variable := NULL]
  # Customize columns names.
  setnames(planetLongitudeTableLong, c('Date', 'Lon', 'pID'))
  setcolorder(planetLongitudeTableLong, c('Date', 'pID', 'Lon'))
  longitudeDerivativesPositionTableAugment(planetLongitudeTableLong)

  # Merge the planets speed columns.
  planetSpeedTableLong <- dailyPlanetsSpeedTablePrepare()
  planetPositionsTableLong <- merge(
    planetLongitudeTableLong,
    planetSpeedTableLong,
    by = c('Date', 'pID')
  )

  fwrite(
    planetPositionsTableLong,
    expandPath("./data/daily_planets_positions_long.csv"), append = F
  )
}