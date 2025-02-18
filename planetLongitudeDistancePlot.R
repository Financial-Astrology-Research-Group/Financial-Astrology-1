# Title     : Planets longitude distance based on slow planets plots.
# Objective : Plot all planets longitude distance against one planet to help visualize all planets aspects
#             angles interactions to note when a given angle is strengthen.
# Created by: pablocc
# Created on: 13/01/2021

library(ggplot2)

source("./fileSystemUtilities.R")
source("./planetAspectsDataPrepare.R")
source('./plotUtils.R')

planetLongitudeDistancePlotTheme <- function() {
  list(
    ggplotDarkTheme(),
    theme(
      plot.margin = unit(rep(0, 4), "null"),
      panel.grid = element_blank(),
      axis.text.x = element_text(angle = 90, size = 10)
    ),
    guides(colour = guide_legend(override.aes = list(size=3, stroke=0.5)))
  )
}

#' Provides ggplot horizontal reference lines for all modern astrology angles.
aspectsReferenceZonesLines <- function() {
  list(
    geom_hline(yintercept = 180, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7),
    geom_hline(yintercept = 150, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7),
    geom_hline(yintercept = 144, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7),
    geom_hline(yintercept = 135, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7),
    geom_hline(yintercept = 120, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7),
    geom_hline(yintercept = 103, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7),
    geom_hline(yintercept = 90, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7),
    geom_hline(yintercept = 72, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7),
    geom_hline(yintercept = 60, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7),
    geom_hline(yintercept = 45, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7),
    geom_hline(yintercept = 36, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7),
    geom_hline(yintercept = 30, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7),
    geom_hline(yintercept = 0, linetype = "longdash", color = "magenta2", size = 1, alpha = 0.7)
  )
}

planetsLongitudesDistanceAxesCustomize <- function(dateBreaks) {
  todayDate <- Sys.Date()
  list(
    geom_vline(xintercept = todayDate, linetype = "dashed", color = "white", size = 0.6, alpha = 0.7),
    labs(x = "Date", y = "Distance Angle"),
    scale_y_continuous(breaks = seq(0, 180, by = 5), expand = c(0, 0)),
    scale_x_date(date_breaks = dateBreaks, date_labels = "%b %Y", expand = c(0, 0))
  )
}

#' Plot all planets longitude distance from Uranus.
#' @param planetPositionsTable Daily planets position data table.
#' @param planetId Planet ID (JU, SA, UR, ...) code to plot longitude distances from.
planetsLongitudeDistanceFromPlanetPlot <- function(planetPositionsTable, planetId) {
  dateBreaks <- "1 month"
  dateRangeLimits <- c(Sys.Date() - (365 * 3), Sys.Date() + 15)
  planetPositionsTableFiltered <- planetPositionsTable[
    Date >= dateRangeLimits[1] & Date <= Sys.Date(),
  ]

  colNames <- colnames(planetPositionsTable)
  longitudeColNames <- colNames[grep("^....LON", colNames)]
  planetPositionsTableLong <- melt(
    planetPositionsTableFiltered,
    id.var = "Date",
    measure.var = longitudeColNames
  )

  variableColors <- c(
    "yellow",
    "white",
    "orange",
    "pink",
    "red",
    "palegreen3",
    "gray",
    "mediumaquamarine",
    "violetred2",
    "tomato2",
    "slateblue2",
    "peachpuff",
    "purple1",
    "olivedrab2",
    "gold1",
    "lavender"
  )

  fromPlanetColNames <- longitudeColNames[grep(planetId, longitudeColNames)]
  fromPlanetPositionsTable <- planetPositionsTableLong[variable %in% fromPlanetColNames]
  setNames(variableColors, fromPlanetColNames)

  distancesPlot <- ggplot(data = fromPlanetPositionsTable) +
    geom_point(aes(x = Date, y = value, size = 1, color = variable), alpha = 0.8, size = 1.1) +
    labs(
      title = paste("Planets longitude distance from", planetId),
      x = "Date",
      y = "Distance Angle",
      color = "Planet Pairs"
    ) +
    scale_color_manual(values = variableColors) +
    aspectsReferenceZonesLines() +
    planetsLongitudesDistanceAxesCustomize(dateBreaks) +
    planetLongitudeDistancePlotTheme()

  targetFileName <- paste0(
    visualizationsDataDestinationPath(),
    "planets_longitude_distance_", planetId, ".png"
  )

  ggsave(
    filename = targetFileName,
    plot = distancesPlot,
    width = 20,
    height = 15,
    units = "cm",
    scale = 1.5,
    dpi = 72
  )

  cat("Plot saved to:", targetFileName, "\n")
}

planetPositionsTable <- loadPlanetsPositionTable("daily")
planetPositionsTable <- planetLongitudesDistanceDataAugment(planetPositionsTable, allPlanetsAndAsteroids())
for (planetId in allPlanetsAndAsteroids()) {
  planetsLongitudeDistanceFromPlanetPlot(planetPositionsTable, planetId)
}
