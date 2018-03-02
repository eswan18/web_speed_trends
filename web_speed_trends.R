library(tidyverse)
library(lubridate)
library(RSQLite)
library(scales)

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
# The first three rows of the data are superfluous (duplicate readings,
# taken at the same time as the fourth row).
speeds <- speeds[-1:-3,]

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
# Extract the weekday and time
speeds$weekday <- as.factor(weekdays(speeds$timestamp))
speeds$weekday <- ordered(speeds$weekday,
                          levels = c('Monday', 'Tuesday', 'Wednesday', 'Thursday',
                                     'Friday', 'Saturday', 'Sunday'))
speeds$hour <- hour(speeds$timestamp)
speeds$minute <- minute(speeds$timestamp)
speeds$second <- second(speeds$timestamp)
# Drop the old timestamp column
speeds <- speeds %>% select(-timestamp)
# Move everything to a date during the same week
speeds$adj_day <- as.numeric(speeds$weekday) + 3
speeds$adj_month <- 1; speeds$adj_year <- 1970
speeds$adj_tmstmp <- paste0(speeds$adj_year, '-', speeds$adj_month, '-', speeds$adj_day, ' ',
                            speeds$hour, ':', speeds$minute, ':', speeds$second)
speeds$adj_tmstmp <- as.POSIXct(speeds$adj_tmstmp)
speeds <- speeds %>% arrange(adj_tmstmp)

# Viz work: Plot upload and download speeds throughout the week.
# Keep only upload & download speeds for this step
up_down_speeds <- speeds %>% select(adj_tmstmp, upload, download)
# First off, we need to melt the data and reshape it the way ggplot likes it.
# The new DF will have columns 'timestamp', 'channel', and 'speed'
up_down_speeds <- gather(data = up_down_speeds, -adj_tmstmp, key='channel', value='speed')
up_down_plot <- ggplot(data = up_down_speeds, aes(x=adj_tmstmp, y=speed, group=channel)) +
  geom_line(aes(color = channel)) + expand_limits(y = 0) + 
  scale_x_datetime(breaks = date_breaks("1 day"), minor_breaks=date_breaks("1 hour"), labels=date_format("%a"))
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
                    data = cutoff, show.legend = TRUE, color = color))
}
up_down_plot + plot_line(down_mn + down_std, "red") + plot_line(down_mn - down_std, "red") +
  plot_line(up_mn + up_std, "light blue") + plot_line(up_mn - up_std, "light blue")
