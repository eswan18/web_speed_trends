library(tidyverse)
library(lubridate)
library(RSQLite)

###############################################################################
# Read in the file.
###############################################################################
setwd('~/Data Science/Syntact/web_speed_trends/')
con <- dbConnect(SQLite(), dbname="data.db")
query <- dbSendQuery(con, "SELECT * FROM data")
speeds <- dbFetch(query, n = -1)
# And the columns appear to be mixed up - sloppy work by me. Luckily
# it's easy to figure out which should be which.
colnames(speeds) <- c('download', 'timestamp', 'upload', 'ping')
# Convert 'download' and 'upload' columns to numbers
speeds$download <- as.numeric(speeds$download)
speeds$upload <- as.numeric(speeds$upload)

###############################################################################
# Convert the timestamp field into a Date in R
###############################################################################
# Start by trimming the milliseconds, which don't parse well.
speeds$timestamp <- sapply(speeds$timestamp, FUN = substr, 0, 19)
# Convert the lingering 'T' to a space
speeds$timestamp <- gsub(pattern = "T", replacement = " ", speeds$timestamp)
# Then parse using as.POSIXct
speeds$timestamp <- as.POSIXct(speeds$timestamp)
# Subtract 5 hours to localize the time
# (these are in GMT)
speeds$timestamp <- speeds$timestamp - hours(5)

###############################################################################
# Now let's adjust everything to be aligned Monday-Sunday with time,
# ignoring the actual date.
###############################################################################
# TODO This will be hard
speeds$weekday <- weekdays(speeds$timestamp)
speeds$hour <- 
speeds$minute <-
speeds$second <- 

# Viz work: Plot upload and download speeds throughout the week.
# Keep only upload & download speeds for this step
up_down_speeds <- speeds %>% select(timestamp, upload, download)
# First off, we need to melt the data and reshape it the way ggplot likes it.
# The new DF will have columns 'timestamp', 'channel', and 'speed'
up_down_speeds <- gather(data = up_down_speeds, -timestamp, key='channel', value='speed')
up_down_plot <- ggplot(data = up_down_speeds, aes(x=timestamp, y=speed, group=channel)) +
  geom_line(aes(color = channel)) + expand_limits(y = 0)
up_down_plot

# Now let's show one-std deviation to see how much less variance is in upload.
down_std <- sd(speeds$download)
down_mn <- mean(speeds$download)
up_std <- sd(speeds$upload)
up_mn <- mean(speeds$upload)
# Calculate the lines that define one std-dev above and below each of download
# and upload.
plot_line <- function(y_intercept, color="black") {
  cutoff <- data.frame(y_intercept=y_intercept, cutoff=factor(y_intercept))
  return(geom_hline(aes(yintercept = y_intercept),
                    data = cutoff, show_guide = TRUE, color = color))
}
up_down_plot + plot_line(down_mn + down_std, "red") + plot_line(down_mn - down_std, "red") +
  plot_line(up_mn + up_std, "cyan") + plot_line(up_mn - up_std, "cyan")
